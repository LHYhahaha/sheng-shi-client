import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entitlement/application/entitlement_controller.dart';
import '../../entitlement/domain/episode_access_decision.dart';
import '../domain/player_access_presentation.dart';
import '../domain/player_feed.dart';
import '../domain/player_performance_policy.dart';
import 'player_feed_controller.dart';
import 'player_feed_engine_access_flow.dart';
import 'player_overlay_orchestrator.dart';
import 'player_performance_policy_provider.dart';
import 'player_recharge_unlock_controller.dart';
import 'player_runtime_coordinator.dart';
import 'player_ui_controller.dart';
import 'player_viewport_controller.dart';

final playerFeedEngineProvider =
    NotifierProvider.family<PlayerFeedEngine, PlayerFeedEngineState, String>(
      PlayerFeedEngine.new,
    );

/// Feed 播放器引擎门面（应用层统一入口）。
///
/// 聚合：viewport、[PlayerRuntimeCoordinator]、[PlayerOverlayOrchestrator]、
/// [PlayerPerformancePolicy]、权益/sheet 意图解析。
///
/// 入口约定：
/// - 手势：`onScrollStart` / `onPageChanged` / `onScrollEnd` / `settleViewport` / `onViewportSettled`
/// - 用户操作：`retryPlayback`、`prepareManualUnlock`、`completeCoinUnlock`、`continueAfterRechargeSuccess`
/// - 只读：`accessPresentationFor`、`isCurrentFeedItem`
///
/// drag 阶段不 evaluate/play/preload/弹窗；仅 settled 且 viewport idle 时执行 runtime。
class PlayerFeedEngineState {
  const PlayerFeedEngineState({
    required this.policy,
    required this.viewport,
    required this.runtime,
    required this.overlay,
    this.settledItem,
    this.settledIndex = -1,
  });

  final PlayerPerformancePolicy policy;
  final PlayerViewportState viewport;
  final PlayerRuntimeCoordinatorState runtime;
  final PlayerOverlayOrchestratorState overlay;
  final PlayerFeedItem? settledItem;
  final int settledIndex;

  bool get isViewportDragging =>
      viewport.scrollPhase == PlayerViewportScrollPhase.dragging;

  bool get isViewportSettling =>
      viewport.scrollPhase == PlayerViewportScrollPhase.settling;

  /// 是否允许执行 playback/access/preload/sheet 等 runtime 工作。
  bool get canExecuteRuntime =>
      viewport.scrollPhase == PlayerViewportScrollPhase.idle &&
      settledItem != null &&
      settledIndex >= 0;

  PlayerFeedEngineState copyWith({
    PlayerPerformancePolicy? policy,
    PlayerViewportState? viewport,
    PlayerRuntimeCoordinatorState? runtime,
    PlayerOverlayOrchestratorState? overlay,
    PlayerFeedItem? settledItem,
    int? settledIndex,
    bool clearSettledItem = false,
  }) {
    return PlayerFeedEngineState(
      policy: policy ?? this.policy,
      viewport: viewport ?? this.viewport,
      runtime: runtime ?? this.runtime,
      overlay: overlay ?? this.overlay,
      settledItem: clearSettledItem ? null : settledItem ?? this.settledItem,
      settledIndex: settledIndex ?? this.settledIndex,
    );
  }
}

class PlayerFeedEngine extends Notifier<PlayerFeedEngineState> {
  PlayerFeedEngine(this.sessionKey);

  final String sessionKey;

  @override
  PlayerFeedEngineState build() {
    final policy = ref.watch(playerPerformancePolicyProvider);
    final viewport = ref.watch(playerViewportControllerProvider(sessionKey));
    final runtime = ref.watch(playerRuntimeCoordinatorProvider(sessionKey));
    final overlay = ref.watch(playerOverlayOrchestratorProvider(sessionKey));
    final feed = ref.watch(playerFeedControllerProvider(sessionKey));
    final settledIndex = viewport.settledIndex;
    final settledItem = settledIndex >= 0 && settledIndex < feed.items.length
        ? feed.items[settledIndex]
        : null;

    return PlayerFeedEngineState(
      policy: policy,
      viewport: viewport,
      runtime: runtime,
      overlay: overlay,
      settledItem: settledItem,
      settledIndex: settledItem == null ? -1 : settledIndex,
    );
  }

  PlayerRuntimeCoordinator get _runtime =>
      ref.read(playerRuntimeCoordinatorProvider(sessionKey).notifier);

  PlayerOverlayOrchestrator get _overlay =>
      ref.read(playerOverlayOrchestratorProvider(sessionKey).notifier);

  PlayerViewportController get _viewport =>
      ref.read(playerViewportControllerProvider(sessionKey).notifier);

  PlayerAccessPresentationState accessPresentationFor(PlayerFeedItem item) {
    return _runtime.accessPresentationFor(item);
  }

  void onScrollStart() {
    _overlay.onScrollStart();
    _viewport.markScrollStart();
  }

  void onScrollEnd() {
    _viewport.markScrollEnd();
  }

  void onPageChanged(int index) {
    _viewport.markPageChanged(index);
  }

  void settleViewport({required int index, required String? itemId}) {
    _viewport.settle(index: index, itemId: itemId);
  }

  void initializeViewport({required int index, required String? itemId}) {
    _viewport.initialize(index: index, itemId: itemId);
  }

  /// 仅在 viewport settled 后调用；drag 阶段调用将被忽略。
  Future<void> onViewportSettled({
    required PlayerFeedItem item,
    required int index,
    String? previousItemId,
    int? previousIndex,
    required String playbackTrigger,
    required bool isModalOpen,
    required bool hasActiveCoinSheet,
    required bool hasActiveRechargeSheet,
    required bool isPageScrolling,
    required bool Function(PlayerFeedItem item) isCurrentFeedItem,
    required bool Function(PlayerFeedItem item) isPageActivelyMoving,
  }) async {
    final viewport = ref.read(playerViewportControllerProvider(sessionKey));
    if (viewport.scrollPhase != PlayerViewportScrollPhase.idle) {
      return;
    }
    if (viewport.settledItemId != item.id || viewport.settledIndex != index) {
      return;
    }

    await _runtime.onViewportSettled(
      item: item,
      index: index,
      previousItemId: previousItemId,
      previousIndex: previousIndex,
      playbackTrigger: playbackTrigger,
    );

    _overlay.scheduleForSettledItem(
      item: item,
      accessPresenter: ref
          .read(playerRuntimeCoordinatorProvider(sessionKey))
          .accessPresenter,
      isModalOpen: isModalOpen,
      hasActiveCoinSheet: hasActiveCoinSheet,
      hasActiveRechargeSheet: hasActiveRechargeSheet,
      isPageScrolling: isPageScrolling,
      isCurrentFeedItem: isCurrentFeedItem,
      isPageActivelyMoving: isPageActivelyMoving,
    );
  }

  Future<void> handleEntitlementForItem(
    PlayerFeedItem item, {
    required bool autoPresentSheet,
  }) {
    return _runtime.handleEntitlementForItem(
      item,
      autoPresentSheet: autoPresentSheet,
    );
  }

  Future<void> handleAccessDecision(
    PlayerFeedItem item,
    EpisodeAccessDecision decision, {
    required bool autoPresentSheet,
  }) {
    return _runtime.applyAccessDecisionForEngine(
      item,
      decision,
      autoPresentSheet: autoPresentSheet,
    );
  }

  bool isCurrentFeedItem(PlayerFeedItem item) =>
      _runtime.isCurrentFeedItem(item);

  bool shouldHandlePlaybackEnded({
    required String? currentItemId,
    required bool hasEnded,
    required bool isSeekDragging,
    required bool isModalOpen,
    required bool showsPaywall,
  }) {
    return _runtime.shouldHandlePlaybackEnded(
      currentItemId: currentItemId,
      hasEnded: hasEnded,
      isSeekDragging: isSeekDragging,
      isModalOpen: isModalOpen,
      showsPaywall: showsPaywall,
    );
  }

  void markEndedHandled(String itemId) {
    _runtime.markEndedHandled(itemId);
  }

  Future<void> quiesceAfterRecharge(
    PlayerFeedItem item, {
    required String reason,
  }) {
    return _runtime.quiesceAfterRecharge(item, reason: reason);
  }

  PlayerUiController get _ui =>
      ref.read(playerUiControllerProvider(sessionKey).notifier);

  EpisodeAccessDecision evaluateAccess(PlayerFeedItem item) {
    return ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          unlockType: item.episode.unlockType,
          price: item.episode.requiredCoins,
          isUnavailable: item.episode.isUnavailable,
        );
  }

  bool isLockedAutoSheetCandidate(PlayerFeedItem item) {
    return ref
        .read(playerRuntimeCoordinatorProvider(sessionKey))
        .accessPresenter
        .isLockedAutoSheetCandidate(item);
  }

  void cancelOverlayPending() => _overlay.cancelPending();

  void markAutoSheetDismissed(String itemId) => _overlay.markDismissed(itemId);

  void clearOverlayDismissed(String itemId) => _overlay.clearDismissed(itemId);

  /// 重试播放：评估权益并执行 runtime；返回需 Page 展示的 sheet。
  Future<PlayerOverlaySheetIntent> retryPlayback(PlayerFeedItem item) async {
    if (!_canExecuteUserInitiatedRuntime(item)) {
      return PlayerOverlaySheetIntent.none;
    }
    final decision = evaluateAccess(item);
    await handleAccessDecision(item, decision, autoPresentSheet: false);
    return _sheetIntentForDecision(decision, item);
  }

  /// 手动 Unlock Now：取消 dwell，评估并返回 sheet 意图。
  Future<PlayerOverlaySheetIntent> prepareManualUnlock(
    PlayerFeedItem item,
  ) async {
    if (!_canExecuteUserInitiatedRuntime(item)) {
      return PlayerOverlaySheetIntent.none;
    }
    cancelOverlayPending();
    if (!isLockedAutoSheetCandidate(item)) {
      return PlayerOverlaySheetIntent.none;
    }
    final decision = evaluateAccess(item);
    if (decision.type == EpisodeAccessDecisionType.allowPlay) {
      await handleAccessDecision(item, decision, autoPresentSheet: false);
      return PlayerOverlaySheetIntent.none;
    }
    return _sheetIntentForDecision(decision, item);
  }

  /// 自动 dwell 弹窗：评估 settled locked 项并返回 sheet 意图。
  Future<PlayerOverlaySheetIntent> prepareAutoUnlockSheet({
    required PlayerFeedItem item,
    required bool isModalOpen,
    required bool hasActiveCoinSheet,
    required bool hasActiveRechargeSheet,
  }) async {
    if (!_canExecuteUserInitiatedRuntime(item) ||
        isModalOpen ||
        hasActiveCoinSheet ||
        hasActiveRechargeSheet ||
        !isLockedAutoSheetCandidate(item)) {
      return PlayerOverlaySheetIntent.none;
    }
    final decision = evaluateAccess(item);
    if (decision.type == EpisodeAccessDecisionType.allowPlay) {
      await handleAccessDecision(item, decision, autoPresentSheet: false);
      return PlayerOverlaySheetIntent.none;
    }
    return _autoSheetIntentForDecision(decision);
  }

  /// Coin 确认后：扣币并走 runtime（不自动弹 sheet）。
  Future<void> completeCoinUnlock(PlayerFeedItem item) async {
    if (!_canExecuteUserInitiatedRuntime(item)) {
      return;
    }
    final decision = await ref
        .read(entitlementControllerProvider.notifier)
        .unlockWithCoins(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          price: item.episode.requiredCoins,
          operationId: 'coin-unlock:${item.content.id}:${item.episode.id}',
        );
    await handleAccessDecision(item, decision, autoPresentSheet: false);
  }

  /// Recharge sheet 成功：发放 mock 权益并决定下一步 sheet。
  Future<PlayerOverlaySheetIntent> continueAfterRechargeSuccess({
    required PlayerFeedItem item,
    required bool grantedCoinPackage,
    required bool grantedMembershipPackage,
  }) async {
    if (!_canExecuteUserInitiatedRuntime(item)) {
      return PlayerOverlaySheetIntent.none;
    }
    ref
        .read(playerRechargeUnlockControllerProvider(sessionKey).notifier)
        .close();
    await quiesceAfterRecharge(
      item,
      reason: grantedMembershipPackage
          ? 'membership purchase success awaiting user action'
          : 'recharge success awaiting coin confirmation',
    );
    _ui.showUnlockPaywall();
    if (grantedCoinPackage) {
      return PlayerOverlaySheetIntent.coinUnlock;
    }
    return PlayerOverlaySheetIntent.none;
  }

  Future<void> grantRechargeSelection({
    required bool selectedCoinPackage,
    required bool selectedMembershipPackage,
    required int? coinPackageTotalCoins,
  }) async {
    final entitlement = ref.read(entitlementControllerProvider.notifier);
    if (selectedCoinPackage && coinPackageTotalCoins != null) {
      await entitlement.grantMockCoins(
        amount: coinPackageTotalCoins,
        source: 'player_recharge_unlock_sheet',
      );
    } else if (selectedMembershipPackage) {
      await entitlement.grantMockMembership(
        source: 'player_recharge_unlock_sheet',
      );
    }
  }

  PlayerOverlaySheetIntent _sheetIntentForDecision(
    EpisodeAccessDecision decision,
    PlayerFeedItem item,
  ) {
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        return PlayerOverlaySheetIntent.none;
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        return PlayerOverlaySheetIntent.coinUnlock;
      case EpisodeAccessDecisionType.showRechargeDialog:
        return PlayerOverlaySheetIntent.rechargeUnlock;
      case EpisodeAccessDecisionType.goMembership:
        return PlayerOverlaySheetIntent.membership;
      case EpisodeAccessDecisionType.waitUnlock:
        if (item.episode.isUnavailable) {
          return PlayerOverlaySheetIntent.none;
        }
        return PlayerOverlaySheetIntent.rechargeUnlock;
    }
  }

  /// 自动 dwell 弹窗：仅 coin/recharge；会员/等待类保持 inline Unlock 由用户手动点。
  PlayerOverlaySheetIntent _autoSheetIntentForDecision(
    EpisodeAccessDecision decision,
  ) {
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
      case EpisodeAccessDecisionType.goMembership:
      case EpisodeAccessDecisionType.waitUnlock:
        return PlayerOverlaySheetIntent.none;
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        return PlayerOverlaySheetIntent.coinUnlock;
      case EpisodeAccessDecisionType.showRechargeDialog:
        return PlayerOverlaySheetIntent.rechargeUnlock;
    }
  }

  bool _canExecuteUserInitiatedRuntime(PlayerFeedItem item) {
    if (!isCurrentFeedItem(item)) {
      return false;
    }
    final viewport = ref.read(playerViewportControllerProvider(sessionKey));
    return viewport.scrollPhase != PlayerViewportScrollPhase.dragging;
  }
}
