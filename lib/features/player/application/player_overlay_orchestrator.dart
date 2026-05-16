import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_feed.dart';
import 'player_access_presenter.dart';
import 'player_rebuild_diagnostics.dart';

final playerOverlayOrchestratorProvider =
    NotifierProvider.family<
      PlayerOverlayOrchestrator,
      PlayerOverlayOrchestratorState,
      String
    >(PlayerOverlayOrchestrator.new);

/// Auto unlock / recharge sheet scheduling after dwell on a locked settled item.
class PlayerOverlayOrchestratorState {
  const PlayerOverlayOrchestratorState({
    this.pendingAutoSheetItemId,
    this.dismissedAutoSheetItemIds = const {},
    this.generation = 0,
  });

  final String? pendingAutoSheetItemId;
  final Set<String> dismissedAutoSheetItemIds;
  final int generation;

  PlayerOverlayOrchestratorState copyWith({
    String? pendingAutoSheetItemId,
    Set<String>? dismissedAutoSheetItemIds,
    int? generation,
    bool clearPendingAutoSheetItemId = false,
  }) {
    return PlayerOverlayOrchestratorState(
      pendingAutoSheetItemId: clearPendingAutoSheetItemId
          ? null
          : pendingAutoSheetItemId ?? this.pendingAutoSheetItemId,
      dismissedAutoSheetItemIds:
          dismissedAutoSheetItemIds ?? this.dismissedAutoSheetItemIds,
      generation: generation ?? this.generation,
    );
  }
}

class PlayerOverlayOrchestrator extends Notifier<PlayerOverlayOrchestratorState> {
  PlayerOverlayOrchestrator(this.sessionKey);

  static const dwellDelay = Duration(milliseconds: 900);

  final String sessionKey;
  int _scheduleGeneration = 0;
  String? _pendingItemId;
  DateTime? _pendingScheduledAt;
  Duration? _pendingFrameStartedAt;

  @override
  PlayerOverlayOrchestratorState build() =>
      const PlayerOverlayOrchestratorState();

  void clearDismissed(String itemId) {
    if (!state.dismissedAutoSheetItemIds.contains(itemId)) {
      return;
    }
    final next = Set<String>.from(state.dismissedAutoSheetItemIds)
      ..remove(itemId);
    state = state.copyWith(dismissedAutoSheetItemIds: next);
  }

  void cancelPending() {
    final itemId = _pendingItemId;
    final scheduledAt = _pendingScheduledAt;
    _pendingItemId = null;
    _pendingScheduledAt = null;
    _pendingFrameStartedAt = null;
    _scheduleGeneration += 1;
    if (itemId != null) {
      PlayerRebuildDiagnostics.recordTiming(
        'dwellAutoSheetCancel',
        itemId: itemId,
        elapsed: scheduledAt == null
            ? null
            : DateTime.now().difference(scheduledAt),
      );
    }
    if (state.pendingAutoSheetItemId != null) {
      state = state.copyWith(clearPendingAutoSheetItemId: true);
    }
  }

  void markDismissed(String itemId) {
    cancelPending();
    if (state.dismissedAutoSheetItemIds.contains(itemId)) {
      return;
    }
    state = state.copyWith(
      dismissedAutoSheetItemIds: {...state.dismissedAutoSheetItemIds, itemId},
    );
    PlayerRebuildDiagnostics.recordTiming(
      'autoUnlockSheetDismissed',
      itemId: itemId,
    );
  }

  void onScrollStart() {
    cancelPending();
  }

  void scheduleForSettledItem({
    required PlayerFeedItem item,
    required PlayerAccessPresenter accessPresenter,
    required bool isModalOpen,
    required bool hasActiveCoinSheet,
    required bool hasActiveRechargeSheet,
    required bool isPageScrolling,
    required bool Function(PlayerFeedItem item) isCurrentFeedItem,
    required bool Function(PlayerFeedItem item) isPageActivelyMoving,
  }) {
    if (_pendingItemId == item.id) {
      return;
    }
    cancelPending();

    if (isModalOpen ||
        hasActiveCoinSheet ||
        hasActiveRechargeSheet ||
        isPageScrolling ||
        state.dismissedAutoSheetItemIds.contains(item.id) ||
        !accessPresenter.isLockedAutoSheetCandidate(item)) {
      return;
    }

    _pendingItemId = item.id;
    _pendingScheduledAt = DateTime.now();
    _pendingFrameStartedAt = null;
    final generation = ++_scheduleGeneration;
    PlayerRebuildDiagnostics.recordTiming(
      'dwellAutoSheetSchedule',
      itemId: item.id,
      details: 'delayMs=${dwellDelay.inMilliseconds}',
    );
    _queueDwellFrame(
      item: item,
      generation: generation,
      isCurrentFeedItem: isCurrentFeedItem,
      isPageActivelyMoving: isPageActivelyMoving,
    );
  }

  void _queueDwellFrame({
    required PlayerFeedItem item,
    required int generation,
    required bool Function(PlayerFeedItem item) isCurrentFeedItem,
    required bool Function(PlayerFeedItem item) isPageActivelyMoving,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _scheduleGeneration || _pendingItemId != item.id) {
        return;
      }
      final frameTime = SchedulerBinding.instance.currentFrameTimeStamp;
      final startedAt = _pendingFrameStartedAt;
      if (startedAt == null) {
        _pendingFrameStartedAt = frameTime;
        SchedulerBinding.instance.scheduleFrame();
        _queueDwellFrame(
          item: item,
          generation: generation,
          isCurrentFeedItem: isCurrentFeedItem,
          isPageActivelyMoving: isPageActivelyMoving,
        );
        return;
      }
      final elapsed = frameTime - startedAt;
      if (elapsed < dwellDelay) {
        SchedulerBinding.instance.scheduleFrame();
        _queueDwellFrame(
          item: item,
          generation: generation,
          isCurrentFeedItem: isCurrentFeedItem,
          isPageActivelyMoving: isPageActivelyMoving,
        );
        return;
      }
      _fireAutoSheet(
        item: item,
        generation: generation,
        isCurrentFeedItem: isCurrentFeedItem,
        isPageActivelyMoving: isPageActivelyMoving,
      );
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _fireAutoSheet({
    required PlayerFeedItem item,
    required int generation,
    required bool Function(PlayerFeedItem item) isCurrentFeedItem,
    required bool Function(PlayerFeedItem item) isPageActivelyMoving,
  }) {
    if (generation != _scheduleGeneration ||
        !isCurrentFeedItem(item) ||
        state.dismissedAutoSheetItemIds.contains(item.id)) {
      return;
    }
    if (isPageActivelyMoving(item)) {
      PlayerRebuildDiagnostics.recordTiming(
        'dwellAutoSheetWaitForSettle',
        itemId: item.id,
      );
      _queueDwellFrame(
        item: item,
        generation: generation,
        isCurrentFeedItem: isCurrentFeedItem,
        isPageActivelyMoving: isPageActivelyMoving,
      );
      return;
    }

    final scheduledAt = _pendingScheduledAt;
    _pendingItemId = null;
    _pendingScheduledAt = null;
    _pendingFrameStartedAt = null;
    if (scheduledAt != null) {
      final elapsed = DateTime.now().difference(scheduledAt);
      PlayerRebuildDiagnostics.recordTiming(
        'dwellAutoSheetFire',
        itemId: item.id,
        elapsed: elapsed,
      );
    }
    state = state.copyWith(
      pendingAutoSheetItemId: item.id,
      generation: state.generation + 1,
    );
  }

  void clearPendingSheetRequest() {
    state = state.copyWith(clearPendingAutoSheetItemId: true);
  }
}
