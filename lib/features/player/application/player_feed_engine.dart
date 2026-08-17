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
import 'player_playback_controller.dart';
import 'player_recharge_unlock_controller.dart';
import 'player_runtime_coordinator.dart';
import 'player_ui_controller.dart';
import 'player_viewport_controller.dart';

final playerFeedEngineProvider =
    NotifierProvider.family<PlayerFeedEngine, PlayerFeedEngineState, String>(
      PlayerFeedEngine.new,
    );

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

  /// 鏄惁鍏佽鎵ц playback/access/preload/sheet 绛?runtime 宸ヤ綔銆?
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

  PlayerPlaybackController get _playback =>
      ref.read(playerPlaybackControllerProvider(sessionKey).notifier);

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

  /// 浠呭湪 viewport settled 鍚庤皟鐢紱drag 闃舵璋冪敤灏嗚蹇界暐銆?
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
    final stopwatch = Stopwatch()..start();
    _playback.recordPlaybackTiming(
      'engine viewport settled start',
      itemId: item.id,
      source: item.episode.videoSource,
      details: [
        'index=$index',
        'trigger=$playbackTrigger',
        'isModalOpen=$isModalOpen',
        'hasActiveCoinSheet=$hasActiveCoinSheet',
        'hasActiveRechargeSheet=$hasActiveRechargeSheet',
        'isPageScrolling=$isPageScrolling',
      ].join(' '),
    );
    final viewport = ref.read(playerViewportControllerProvider(sessionKey));

    if (viewport.scrollPhase != PlayerViewportScrollPhase.idle) {
      _playback.recordPlaybackTiming(
        'engine viewport settled skipped',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: stopwatch.elapsed,
        details: 'reason=viewport_not_idle phase=${viewport.scrollPhase.name}',
      );
      return;
    }
    if (viewport.settledItemId != item.id || viewport.settledIndex != index) {
      _playback.recordPlaybackTiming(
        'engine viewport settled skipped',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: stopwatch.elapsed,
        details: [
          'reason=settled_item_mismatch',
          'viewportItemId=${viewport.settledItemId ?? 'null'}',
          'viewportIndex=${viewport.settledIndex}',
        ].join(' '),
      );
      return;
    }

    if (previousItemId != null && previousItemId != item.id) {
      // 鑷姩瑙ｉ攣寮圭獥鐨?dismiss 鍙鈥滃綋鍓嶈繖娆″仠鐣欌€濈敓鏁堛€?
      // 鐢ㄦ埛绂诲紑璇?item 鍚庯紝涓嬫鍐嶆粦鍥炴潵搴旈噸鏂板厑璁歌嚜鍔ㄥ脊鍑恒€?
      _overlay.clearDismissed(previousItemId);
    }

    await _runtime.onViewportSettled(
      item: item,
      index: index,
      previousItemId: previousItemId,
      previousIndex: previousIndex,
      playbackTrigger: playbackTrigger,
    );
    _playback.recordPlaybackTiming(
      'engine runtime settled end',
      itemId: item.id,
      source: item.episode.videoSource,
      elapsed: stopwatch.elapsed,
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
    _playback.recordPlaybackTiming(
      'engine viewport settled end',
      itemId: item.id,
      source: item.episode.videoSource,
      elapsed: stopwatch.elapsed,
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
    if (!_mustUnlockPreviousEpisodeFirst(item, decision)) {
      return decision;
    }
    return EpisodeAccessDecision(
      type: EpisodeAccessDecisionType.showRechargeDialog,
      dramaId: decision.dramaId,
      episodeId: decision.episodeId,
      itemId: decision.itemId,
      unlockType: decision.unlockType,
      price: decision.price,
      balance: decision.balance,
      reason: 'sequential_unlock_required',
    );
  }

  bool isLockedAutoSheetCandidate(PlayerFeedItem item) {
    return ref
        .read(playerRuntimeCoordinatorProvider(sessionKey))
        .accessPresenter
        .isLockedAutoSheetCandidate(item);
  }

  bool isSequentialUnlockEligible(PlayerFeedItem item) =>
      _isSequentialUnlockEligible(item);

  void cancelOverlayPending() => _overlay.cancelPending();

  void markAutoSheetDismissed(String itemId) => _overlay.markDismissed(itemId);

  void clearOverlayDismissed(String itemId) => _overlay.clearDismissed(itemId);

  /// 閲嶈瘯鎾斁锛氬埛鏂版潈鐩婂悗璇勪及鏉冪泭骞舵墽琛?runtime锛涜繑鍥為渶 Page 灞曠ず鐨?sheet銆?
  Future<PlayerOverlaySheetIntent> retryPlayback(PlayerFeedItem item) async {
    final latestItem = _latestCurrentVersionOf(item);
    if (latestItem == null || !_canExecuteUserInitiatedRuntime(latestItem)) {
      return PlayerOverlaySheetIntent.none;
    }
    // 瑙ｉ攣鍓嶅埛鏂版潈鐩婃暟鎹紝纭繚閲戝竵鍜屼細鍛樼姸鎬佹槸鏈€鏂扮殑
    // await ref.read(entitlementControllerProvider.notifier).load();
    final decision = evaluateAccess(latestItem);
    await handleAccessDecision(latestItem, decision, autoPresentSheet: false);
    return _sheetIntentForDecision(decision, latestItem);
  }

  /// 鎵嬪姩 Unlock Now锛氬彇娑?dwell锛屽埛鏂版潈鐩婂悗璇勪及骞惰繑鍥?sheet 鎰忓浘銆?
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
    // 瑙ｉ攣鍓嶅埛鏂版潈鐩婃暟鎹紝纭繚閲戝竵鍜屼細鍛樼姸鎬佹槸鏈€鏂扮殑
    // await ref.read(entitlementControllerProvider.notifier).load();
    final decision = evaluateAccess(item);
    if (decision.type == EpisodeAccessDecisionType.allowPlay) {
      await handleAccessDecision(item, decision, autoPresentSheet: false);
      return PlayerOverlaySheetIntent.none;
    }
    return _sheetIntentForDecision(decision, item);
  }

  /// 鑷姩 dwell 寮圭獥锛氬埛鏂版潈鐩婂悗璇勪及 settled locked 椤癸紱auto unlock 寮€鍚椂鐩存帴鎵ｅ竵鎾斁銆?
  Future<PlayerUnlockFlowResult> prepareAutoUnlockSheet({
    required PlayerFeedItem item,
    required bool isModalOpen,
    required bool hasActiveCoinSheet,
    required bool hasActiveRechargeSheet,
  }) async {
    final stopwatch = Stopwatch()..start();
    final canExecuteRuntime = _canExecuteUserInitiatedRuntime(item);
    final lockedAutoSheetCandidate = isLockedAutoSheetCandidate(item);
    _playback.recordPlaybackTiming(
      'auto unlock sheet prepare start',
      itemId: item.id,
      source: item.episode.videoSource,
      details: [
        'isModalOpen=$isModalOpen',
        'hasActiveCoinSheet=$hasActiveCoinSheet',
        'hasActiveRechargeSheet=$hasActiveRechargeSheet',
        'canExecuteRuntime=$canExecuteRuntime',
        'lockedAutoSheetCandidate=$lockedAutoSheetCandidate',
      ].join(' '),
    );

    if (!canExecuteRuntime ||
        isModalOpen ||
        hasActiveCoinSheet ||
        hasActiveRechargeSheet ||
        !lockedAutoSheetCandidate) {
      _playback.recordPlaybackTiming(
        'auto unlock sheet prepare skipped',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: stopwatch.elapsed,
      );
      return const PlayerUnlockFlowResult();
    }
    // 瑙ｉ攣鍓嶅埛鏂版潈鐩婃暟鎹紝纭繚閲戝竵鍜屼細鍛樼姸鎬佹槸鏈€鏂扮殑
    // await ref.read(entitlementControllerProvider.notifier).load();
    final decision = evaluateAccess(item);
    _playback.recordPlaybackTiming(
      'auto unlock sheet access evaluated',
      itemId: item.id,
      source: item.episode.videoSource,
      elapsed: stopwatch.elapsed,
      details: [
        'decision=${decision.type.name}',
        'reason=${decision.reason ?? 'null'}',
      ].join(' '),
    );

    if (decision.type == EpisodeAccessDecisionType.allowPlay) {
      await handleAccessDecision(item, decision, autoPresentSheet: false);
      _playback.recordPlaybackTiming(
        'auto unlock sheet allowPlay handled',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: stopwatch.elapsed,
      );
      return const PlayerUnlockFlowResult();
    }
    if (decision.type == EpisodeAccessDecisionType.autoUnlockAndPlay) {
      final unlocked = await completeCoinUnlock(item);
      _playback.recordPlaybackTiming(
        'auto unlock sheet coin unlock end',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: stopwatch.elapsed,
        details: 'unlocked=$unlocked',
      );
      return PlayerUnlockFlowResult(didAutoUnlock: unlocked);
    }

    final sheetIntent = _autoSheetIntentForDecision(decision);
    _playback.recordPlaybackTiming(
      'auto unlock sheet prepare end',
      itemId: item.id,
      source: item.episode.videoSource,
      elapsed: stopwatch.elapsed,
      details: [
        'decision=${decision.type.name}',
        'sheetIntent=${sheetIntent.name}',
      ].join(' '),
    );
    return PlayerUnlockFlowResult(sheetIntent: sheetIntent);
  }

  /// Coin 纭鍚庯細鎵ｅ竵骞惰蛋 runtime锛堜笉鑷姩寮?sheet锛夈€?
  Future<bool> completeCoinUnlock(PlayerFeedItem item) async {
    final latestItem = _latestCurrentVersionOf(item);
    if (latestItem == null || !_canExecuteUserInitiatedRuntime(latestItem)) {
      return false;
    }
    if (!_isSequentialUnlockEligible(latestItem)) {
      return false;
    }
    return _unlockCurrentItemWithCoinApi(latestItem, autoUnlockNext: true);
  }

  /// Recharge sheet 鎴愬姛锛氬彂鏀?mock 鏉冪泭骞跺喅瀹氫笅涓€姝?sheet 鎴栫洿鎺ユ挱鏀俱€?
  Future<PlayerUnlockFlowResult> continueAfterRechargeSuccess({
    required PlayerFeedItem item,
    required bool grantedCoinPackage,
    required bool grantedMembershipPackage,
  }) async {
    final latestBeforeRefresh = _latestCurrentVersionOf(item);
    if (latestBeforeRefresh == null ||
        !_canExecuteUserInitiatedRuntime(latestBeforeRefresh)) {
      return const PlayerUnlockFlowResult();
    }
    ref
        .read(playerRechargeUnlockControllerProvider(sessionKey).notifier)
        .close();
    final refreshedItem = await ref
        .read(playerFeedControllerProvider(sessionKey).notifier)
        .refreshCurrentDramaAtEpisode(
          episodeId: latestBeforeRefresh.episode.id,
        );
    final currentItem =
        refreshedItem ?? _latestCurrentVersionOf(latestBeforeRefresh);
    if (currentItem == null || !_canExecuteUserInitiatedRuntime(currentItem)) {
      return const PlayerUnlockFlowResult();
    }
    // 鍏呭€兼垨寮€閫氫細鍛樻垚鍔熷悗锛屽埛鏂版潈鐩婃暟鎹?
    // await ref.read(entitlementControllerProvider.notifier).load();
    if (grantedMembershipPackage) {
      // 详情数据在当前观看会话内可能仍是购买前的快照；会员开通成功后，
      // 立即把当前集标记为 vip，供本次 drama_play_end 使用。
      final membershipItem =
          ref
              .read(playerFeedControllerProvider(sessionKey).notifier)
              .updateEpisodeViewingEntitlementType(
                dramaId: currentItem.content.id,
                episodeId: currentItem.episode.id,
                viewingEntitlementType: 'vip',
              ) ??
          currentItem;
      final decision = evaluateAccess(membershipItem);
      if (decision.type == EpisodeAccessDecisionType.allowPlay) {
        await handleAccessDecision(
          membershipItem,
          decision,
          autoPresentSheet: false,
        );
        return const PlayerUnlockFlowResult(didActivateMembership: true);
      }
      await quiesceAfterRecharge(
        currentItem,
        reason: decision.reason ?? 'membership purchase pending unlock',
      );
      _ui.showUnlockPaywall();
      return PlayerUnlockFlowResult(
        sheetIntent: _sheetIntentForDecision(decision, currentItem),
      );
    }
    if (grantedCoinPackage) {
      if (!_isSequentialUnlockEligible(currentItem)) {
        await quiesceAfterRecharge(
          currentItem,
          reason: 'sequential unlock required after recharge',
        );
        _ui.showUnlockPaywall();
        return const PlayerUnlockFlowResult();
      }
      if (ref.read(entitlementControllerProvider).autoUnlockEnabled) {
        final unlocked = await _unlockCurrentItemWithCoinApi(
          currentItem,
          autoUnlockNext: true,
        );
        return PlayerUnlockFlowResult(didAutoUnlock: unlocked);
      }
      await quiesceAfterRecharge(
        currentItem,
        reason: 'recharge success awaiting coin confirmation',
      );
      _ui.showUnlockPaywall();
      return const PlayerUnlockFlowResult(
        sheetIntent: PlayerOverlaySheetIntent.coinUnlock,
      );
    }
    await quiesceAfterRecharge(
      currentItem,
      reason: 'recharge success awaiting unlock continuation',
    );
    _ui.showUnlockPaywall();
    return const PlayerUnlockFlowResult();
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
        // 绾細鍛樺墽锛氳Е鍙戣烦杞細鍛橀〉
        return PlayerOverlaySheetIntent.membership;
      case EpisodeAccessDecisionType.waitUnlock:
        if (item.episode.isUnavailable) {
          return PlayerOverlaySheetIntent.none;
        }
        return PlayerOverlaySheetIntent.rechargeUnlock;
    }
  }

  /// 鑷姩 dwell 寮圭獥锛歝oin/recharge/浼氬憳閮芥敮鎸佽嚜鍔ㄥ脊绐楋紱waitUnlock 淇濇寔 inline Unlock 鐢辩敤鎴锋墜鍔ㄧ偣銆?
  PlayerOverlaySheetIntent _autoSheetIntentForDecision(
    EpisodeAccessDecision decision,
  ) {
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        return PlayerOverlaySheetIntent.none;
      case EpisodeAccessDecisionType.goMembership:
        // 绾細鍛樺墽锛氳嚜鍔ㄨЕ鍙戣烦杞細鍛橀〉
        return PlayerOverlaySheetIntent.membership;
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

  PlayerFeedItem? _latestCurrentVersionOf(PlayerFeedItem item) {
    final currentItem = ref
        .read(playerFeedControllerProvider(sessionKey))
        .currentItem;
    if (currentItem?.id != item.id) {
      return null;
    }
    return currentItem;
  }

  Future<bool> _unlockCurrentItemWithCoinApi(
    PlayerFeedItem item, {
    required bool autoUnlockNext,
  }) async {
    if (!_isSequentialUnlockEligible(item)) {
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

    final unlockedItem = _latestCurrentVersionOf(item) ?? item;
    final decision = evaluateAccess(unlockedItem);
    await handleAccessDecision(unlockedItem, decision, autoPresentSheet: false);
    return decision.type == EpisodeAccessDecisionType.allowPlay;
  }

  bool _mustUnlockPreviousEpisodeFirst(
    PlayerFeedItem item,
    EpisodeAccessDecision decision,
  ) {
    final requiresCoinUnlock =
        decision.type == EpisodeAccessDecisionType.autoUnlockAndPlay ||
        decision.type == EpisodeAccessDecisionType.showCoinUnlockDialog;
    return requiresCoinUnlock && !_isSequentialUnlockEligible(item);
  }

  bool _isSequentialUnlockEligible(PlayerFeedItem item) {
    final entitlement = ref.read(entitlementControllerProvider);
    return item.content.isSequentialUnlockEligible(
      item.episode,
      isEpisodeUnlocked: entitlement.isEpisodeUnlocked,
    );
  }
}
