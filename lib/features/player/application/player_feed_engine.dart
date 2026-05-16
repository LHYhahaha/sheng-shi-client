import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entitlement/domain/episode_access_decision.dart';
import '../domain/player_access_presentation.dart';
import '../domain/player_feed.dart';
import '../domain/player_performance_policy.dart';
import 'player_feed_controller.dart';
import 'player_overlay_orchestrator.dart';
import 'player_performance_policy_provider.dart';
import 'player_runtime_coordinator.dart';
import 'player_viewport_controller.dart';

final playerFeedEngineProvider =
    NotifierProvider.family<PlayerFeedEngine, PlayerFeedEngineState, String>(
      PlayerFeedEngine.new,
    );

/// Feed 播放器引擎门面：聚合 viewport / access / playback / overlay / policy。
///
/// 业务规则：
/// - drag 阶段只允许轻量 shell 滑动，不触发 runtime。
/// - 仅 settled 后执行权益评估、播放、预加载与弹窗调度。
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
    return _runtime.handleAccessDecision(
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
}
