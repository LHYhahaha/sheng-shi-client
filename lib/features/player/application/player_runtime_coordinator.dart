import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entitlement/application/entitlement_controller.dart';
import '../../entitlement/domain/episode_access_decision.dart';
import '../domain/player_access_presentation.dart';
import '../domain/player_feed.dart';
import 'player_access_presenter.dart';
import 'player_feed_controller.dart';
import 'player_playback_controller.dart';
import 'player_rebuild_diagnostics.dart';
import 'player_overlay_orchestrator.dart';
import 'player_performance_policy_provider.dart';
import 'player_recharge_unlock_controller.dart';
import 'player_ui_controller.dart';
import 'player_viewport_controller.dart';

final playerRuntimeCoordinatorProvider =
    NotifierProvider.family<
      PlayerRuntimeCoordinator,
      PlayerRuntimeCoordinatorState,
      String
    >(PlayerRuntimeCoordinator.new);

class PlayerRuntimeCoordinatorState {
  const PlayerRuntimeCoordinatorState({
    this.accessPresenter = const PlayerAccessPresenter(),
    this.preloadRequestGeneration = 0,
    this.handledEndedItemId,
  });

  final PlayerAccessPresenter accessPresenter;
  final int preloadRequestGeneration;
  final String? handledEndedItemId;

  PlayerRuntimeCoordinatorState copyWith({
    PlayerAccessPresenter? accessPresenter,
    int? preloadRequestGeneration,
    String? handledEndedItemId,
    bool clearHandledEndedItemId = false,
  }) {
    return PlayerRuntimeCoordinatorState(
      accessPresenter: accessPresenter ?? this.accessPresenter,
      preloadRequestGeneration:
          preloadRequestGeneration ?? this.preloadRequestGeneration,
      handledEndedItemId: clearHandledEndedItemId
          ? null
          : handledEndedItemId ?? this.handledEndedItemId,
    );
  }
}

/// Settled-only 播放运行时：权益评估、play/quiesce/preload。
///
/// 原则：
/// - [PlayerViewportScrollPhase.dragging] 时拒绝一切入口（与 engine 双重 guard）。
/// - 不展示 sheet、不读写 UI；sheet 由 [PlayerFeedEngine] + Page 负责。
/// - 真实 media 状态仅在 [PlayerPlaybackController]。
///
/// UI 层请使用 [PlayerFeedEngine]，勿直接调用本类。
class PlayerRuntimeCoordinator extends Notifier<PlayerRuntimeCoordinatorState> {
  PlayerRuntimeCoordinator(this.sessionKey);

  final String sessionKey;

  @override
  PlayerRuntimeCoordinatorState build() =>
      const PlayerRuntimeCoordinatorState();

  PlayerFeedController get _feedController =>
      ref.read(playerFeedControllerProvider(sessionKey).notifier);

  PlayerPlaybackController get _playbackController =>
      ref.read(playerPlaybackControllerProvider(sessionKey).notifier);

  PlayerUiController get _uiController =>
      ref.read(playerUiControllerProvider(sessionKey).notifier);

  bool isCurrentFeedItem(PlayerFeedItem item) {
    return ref.read(playerFeedControllerProvider(sessionKey)).currentItem?.id ==
        item.id;
  }

  Future<void> onViewportSettled({
    required PlayerFeedItem item,
    required int index,
    String? previousItemId,
    int? previousIndex,
    required String playbackTrigger,
  }) async {
    final viewport = ref.read(playerViewportControllerProvider(sessionKey));
    if (viewport.scrollPhase != PlayerViewportScrollPhase.idle) {
      return;
    }
    final feedProvider = playerFeedControllerProvider(sessionKey);
    final latestFeedState = ref.read(feedProvider);
    if (latestFeedState.currentIndex != index) {
      _feedController.setCurrentIndex(index);
    }
    _uiController.selectEpisode(item.episode);

    if (previousItemId != null && previousIndex != null) {
      final direction = index > previousIndex ? 'next' : 'previous';
      _playbackController.recordPlaybackUserAction(
        'PageView settled',
        trigger: playbackTrigger,
        fromItemId: previousItemId,
        toItemId: item.id,
        direction: direction,
        fromIndex: previousIndex,
        toIndex: index,
      );
      // 上报切集事件
      if (playbackTrigger == 'swipe_next' || playbackTrigger == 'swipe_previous' || playbackTrigger == 'auto_next') {
        unawaited(_playbackController.reportWatchProgress(eventType: 5)); // 5: switchEpisode
      }
    }

    final accessStopwatch = Stopwatch()..start();
    PlayerRebuildDiagnostics.recordTiming(
      'settledAccessEvaluateStart',
      itemId: item.id,
    );
    await handleEntitlementForItem(item, autoPresentSheet: false);
    accessStopwatch.stop();
    final accessPresentation = state.accessPresenter.presentationFor(
      item,
      ref.read(entitlementControllerProvider),
    );
    PlayerRebuildDiagnostics.recordTiming(
      'settledAccessEvaluateEnd',
      itemId: item.id,
      elapsed: accessStopwatch.elapsed,
      details: 'mode=${accessPresentation.name}',
    );
    PlayerRebuildDiagnostics.recordTiming(
      'currentItemAccessMode',
      itemId: item.id,
      details: 'mode=${accessPresentation.name}',
    );
    PlayerRebuildDiagnostics.recordTiming(
      'postSettledPlaybackCommand',
      itemId: item.id,
      elapsed: accessStopwatch.elapsed,
      details: 'mode=${accessPresentation.name}',
    );
    if (state.accessPresenter.isLockedAutoSheetCandidate(item)) {
      PlayerRebuildDiagnostics.recordTiming(
        'currentItemChangeToUnlockNow',
        itemId: item.id,
        elapsed: accessStopwatch.elapsed,
      );
      _playbackController.recordPlaybackTiming(
        'current item to unlock now',
        itemId: item.id,
        elapsed: accessStopwatch.elapsed,
      );
    }
    PlayerRebuildDiagnostics.recordTiming(
      'postSettledSheetSchedule',
      itemId: item.id,
    );
  }

  Future<void> handleEntitlementForItem(
    PlayerFeedItem item, {
    required bool autoPresentSheet,
  }) async {
    final viewport = ref.read(playerViewportControllerProvider(sessionKey));
    if (viewport.scrollPhase == PlayerViewportScrollPhase.dragging) {
      return;
    }
    _uiController.selectEpisode(item.episode);
    final decision = ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          unlockType: item.episode.unlockType,
          price: item.episode.requiredCoins,
          isUnavailable: item.episode.isUnavailable,
        );
    await _handleAccessDecision(
      item,
      decision,
      autoPresentSheet: autoPresentSheet,
    );
  }

  /// 仅供 [PlayerFeedEngine]：unlock/recharge 后应用已算好的 decision（不重复 evaluate）。
  Future<void> applyAccessDecisionForEngine(
    PlayerFeedItem item,
    EpisodeAccessDecision decision, {
    required bool autoPresentSheet,
  }) {
    return _handleAccessDecision(
      item,
      decision,
      autoPresentSheet: autoPresentSheet,
    );
  }

  Future<void> _handleAccessDecision(
    PlayerFeedItem item,
    EpisodeAccessDecision decision, {
    required bool autoPresentSheet,
  }) async {
    final presenter = state.accessPresenter;
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        if (!isCurrentFeedItem(item)) {
          return;
        }
        state = state.copyWith(
          accessPresenter: presenter.withPlayableItem(item.id),
        );
        ref
            .read(playerOverlayOrchestratorProvider(sessionKey).notifier)
            .clearDismissed(item.id);
        _uiController.unlockPaywallAndPlay();
        _schedulePreloadAroundItem(item);
        await _playbackController.playItem(
          state.accessPresenter.playableCopy(item),
          resumeIfCurrentSource: true,
        );
        // 上报观看开始事件
        unawaited(_playbackController.reportWatchProgress(eventType: 1)); // 1: start
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
        final unlocked = await _unlockCurrentItemWithCoinApi(
          item,
          autoUnlockNext: true,
        );
        if (unlocked) {
          return;
        }
        if (!isCurrentFeedItem(item)) {
          return;
        }
        ref
            .read(playerOverlayOrchestratorProvider(sessionKey).notifier)
            .markDismissed(item.id);
        await _quiesceItemForAccessOverlay(
          item,
          reason: decision.reason ?? 'auto unlock pending',
        );
        _schedulePreloadAroundItem(item);
        _uiController.showUnlockPaywall();
        if (autoPresentSheet) {
          state = state.copyWith(accessPresenter: presenter);
        }
      case EpisodeAccessDecisionType.goMembership:
        await _quiesceItemForAccessOverlay(
          item,
          reason: decision.reason ?? 'membership required',
        );
        _schedulePreloadAroundItem(item);
        _uiController.showMemberPaywall();
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await _quiesceItemForAccessOverlay(
          item,
          reason: decision.reason ?? 'coin unlock required',
        );
        _schedulePreloadAroundItem(item);
        _uiController.showUnlockPaywall();
      case EpisodeAccessDecisionType.showRechargeDialog:
        await _quiesceItemForAccessOverlay(
          item,
          reason: decision.reason ?? 'recharge required',
        );
        _schedulePreloadAroundItem(item);
        _uiController.showUnlockPaywall();
      case EpisodeAccessDecisionType.waitUnlock:
        if (item.episode.isUnavailable) {
          await _blockItemForAccess(
            item,
            status: PlayerPlaybackStatus.unavailable,
            reason: decision.reason ?? 'wait unlock',
          );
        } else {
          await _quiesceItemForAccessOverlay(
            item,
            reason: decision.reason ?? 'wait unlock',
          );
        }
        _schedulePreloadAroundItem(item);
        if (item.episode.isUnavailable) {
          _uiController.hidePaywall();
        } else {
          _uiController.showUnlockPaywall();
        }
    }
  }

  void markEndedHandled(String itemId) {
    state = state.copyWith(handledEndedItemId: itemId);
  }

  bool shouldHandlePlaybackEnded({
    required String? currentItemId,
    required bool hasEnded,
    required bool isSeekDragging,
    required bool isModalOpen,
    required bool showsPaywall,
  }) {
    if (!hasEnded ||
        currentItemId == null ||
        state.handledEndedItemId == currentItemId ||
        isSeekDragging ||
        isModalOpen ||
        showsPaywall) {
      return false;
    }
    final feedItem = ref
        .read(playerFeedControllerProvider(sessionKey))
        .currentItem;
    return feedItem?.id == currentItemId;
  }

  void _schedulePreloadAroundItem(PlayerFeedItem item) {
    final policy = ref.read(playerPerformancePolicyProvider);
    if (policy.skipPreloadWhenCurrentItemLocked && item.episode.isLocked) {
      return;
    }
    final requestGeneration = state.preloadRequestGeneration + 1;
    state = state.copyWith(preloadRequestGeneration: requestGeneration);
    unawaited(() async {
      await Future<void>.delayed(Duration.zero);
      if (state.preloadRequestGeneration != requestGeneration) {
        return;
      }
      final feedState = ref.read(playerFeedControllerProvider(sessionKey));
      if (feedState.currentItem?.id != item.id || feedState.items.isEmpty) {
        return;
      }
      await _playbackController.preloadAround(
        feedState.items,
        feedState.currentIndex,
      );
    }());
  }

  Future<void> _blockItemForAccess(
    PlayerFeedItem item, {
    required PlayerPlaybackStatus status,
    required String reason,
  }) async {
    final stopwatch = Stopwatch()..start();
    await _playbackController.blockItem(item, status: status, reason: reason);
    stopwatch.stop();
    PlayerRebuildDiagnostics.recordTiming(
      'blockItem',
      itemId: item.id,
      elapsed: stopwatch.elapsed,
      details: 'status=${status.name} reason=$reason',
    );
    _playbackController.recordPlaybackTiming(
      'block item elapsed',
      itemId: item.id,
      elapsed: stopwatch.elapsed,
      details: 'status=${status.name} reason=$reason',
    );
  }

  Future<void> _quiesceItemForAccessOverlay(
    PlayerFeedItem item, {
    required String reason,
  }) async {
    final stopwatch = Stopwatch()..start();
    await _playbackController.quiesceForAccessOverlay(item, reason: reason);
    stopwatch.stop();
    PlayerRebuildDiagnostics.recordTiming(
      'quiesceForAccessOverlay',
      itemId: item.id,
      elapsed: stopwatch.elapsed,
      details: 'reason=$reason',
    );
    _playbackController.recordPlaybackTiming(
      'access overlay quiesce elapsed',
      itemId: item.id,
      elapsed: stopwatch.elapsed,
      details: 'reason=$reason',
    );
  }

  Future<void> quiesceAfterRecharge(
    PlayerFeedItem item, {
    required String reason,
  }) async {
    await _quiesceItemForAccessOverlay(item, reason: reason);
  }

  Future<bool> _unlockCurrentItemWithCoinApi(
    PlayerFeedItem item, {
    required bool autoUnlockNext,
  }) async {
    if (!isCurrentFeedItem(item)) {
      return false;
    }

    await ref
        .read(playerRechargeUnlockControllerProvider(sessionKey).notifier)
        .unlockWithCoin(
          autoUnlockNext: autoUnlockNext,
          coin: item.episode.requiredCoins,
          dramaId: int.tryParse(item.content.id) ?? 0,
          episodeNo: item.episode.number,
          shortTitle: item.content.playTitle.isNotEmpty
              ? item.content.playTitle
              : item.content.title,
          cover: item.content.coverUrl ?? '',
          episodeId: int.tryParse(item.episode.id) ?? 0,
        );

    final unlockState = ref.read(
      playerRechargeUnlockControllerProvider(sessionKey),
    );
    if (unlockState.status != PlayerRechargeUnlockStatus.success) {
      return false;
    }

    final currentItem =
        ref.read(playerFeedControllerProvider(sessionKey)).currentItem;
    final unlockedItem = currentItem?.id == item.id ? currentItem! : item;
    final decision = ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: unlockedItem.content.id,
          episodeId: unlockedItem.episode.id,
          itemId: unlockedItem.id,
          unlockType: unlockedItem.episode.unlockType,
          price: unlockedItem.episode.requiredCoins,
          isUnavailable: unlockedItem.episode.isUnavailable,
        );
    if (decision.type != EpisodeAccessDecisionType.allowPlay) {
      return false;
    }
    await _handleAccessDecision(
      unlockedItem,
      decision,
      autoPresentSheet: false,
    );
    return true;
  }

  PlayerAccessPresentationState accessPresentationFor(PlayerFeedItem item) {
    return state.accessPresenter.presentationFor(
      item,
      ref.read(entitlementControllerProvider),
    );
  }
}
