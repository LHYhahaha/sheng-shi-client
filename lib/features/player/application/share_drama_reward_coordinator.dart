import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/user_info_store.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../rewards/application/reward_coins_controller.dart';
import '../../rewards/data/reward_coins_repository_provider.dart';
import '../data/dto/share_drama_status_dto.dart';
import '../data/player_remote_data_source_provider.dart';

enum ShareDramaRewardChannel { facebook, copyLink }

/// 跨播放器页面存活的短剧分享奖励领取协调器。
class ShareDramaRewardCoordinator {
  ShareDramaRewardCoordinator({
    required Future<bool> Function(String taskKey) claimReward,
    Future<void> Function()? reportShareAction,
    Future<ShareDramaStatusDto> Function()? fetchStatus,
    Future<void> Function()? onRewardClaimed,
    ShareDramaClaimedTodayStore? claimedTodayStore,
    DateTime Function()? clock,
    this.validity = const Duration(minutes: 5),
  }) : _claimReward = claimReward,
       _reportShareAction = reportShareAction,
       _fetchStatus = fetchStatus,
       _onRewardClaimed = onRewardClaimed,
       _claimedTodayStore = claimedTodayStore,
       _clock = clock ?? DateTime.now;

  final Future<bool> Function(String taskKey) _claimReward;
  final Future<void> Function()? _reportShareAction;
  final Future<ShareDramaStatusDto> Function()? _fetchStatus;
  final Future<void> Function()? _onRewardClaimed;
  final ShareDramaClaimedTodayStore? _claimedTodayStore;
  final DateTime Function() _clock;
  final Duration validity;
  _PendingShareDramaReward? _pending;
  String? _claimInFlightTaskKey;
  ShareDramaStatusDto? _status;
  Future<ShareDramaStatusDto?>? _statusRequest;

  bool get hasPending => _pending != null;

  Future<ShareDramaStatusDto?> loadStatus() async {
    final cached = _status;
    if (cached != null) return cached;
    if (await _claimedTodayStore?.hasClaimedToday() == true) {
      return _status = const ShareDramaStatusDto(
        claimed: true,
        completed: true,
        info: ShareDramaTaskInfoDto(configKey: 'coin.share_drama', minValue: 0),
      );
    }
    return _refreshStatus();
  }

  Future<ShareDramaStatusDto?> refreshStatus() {
    _status = null;
    return _refreshStatus();
  }

  Future<ShareDramaStatusDto?> _refreshStatus() {
    final pending = _statusRequest;
    if (pending != null) return pending;
    final fetchStatus = _fetchStatus;
    if (fetchStatus == null) return Future<ShareDramaStatusDto?>.value(null);
    late final Future<ShareDramaStatusDto?> request;
    request = _fetchAndCacheStatus(fetchStatus).whenComplete(() {
      if (identical(_statusRequest, request)) {
        _statusRequest = null;
      }
    });
    _statusRequest = request;
    return request;
  }

  Future<ShareDramaStatusDto?> _fetchAndCacheStatus(
    Future<ShareDramaStatusDto> Function() fetchStatus,
  ) async {
    try {
      final status = await fetchStatus();
      _status = status;
      if (status.claimed) {
        await _claimedTodayStore?.markClaimedToday();
      }
      return status;
    } catch (_) {
      return null;
    }
  }

  void register({
    required String? taskKey,
    required bool claimed,
    required ShareDramaRewardChannel channel,
  }) {
    _pending = _PendingShareDramaReward(
      taskKey: taskKey?.trim(),
      claimed: claimed,
      channel: channel,
      createdAt: _clock(),
    );
  }

  /// Facebook 回前台时返回提示事件；领取成功或失败均不提示。
  ShareDramaRewardChannel? onLifecycleChanged(AppLifecycleState state) {
    final pending = _pending;
    if (pending == null) return null;
    if (_clock().difference(pending.createdAt) >= validity) {
      _pending = null;
      return null;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      pending.didEnterBackground = true;
      return null;
    }
    if (state != AppLifecycleState.resumed || !pending.didEnterBackground) {
      return null;
    }

    _pending = null;
    _reportAndClaimIfEligible(
      taskKey: pending.taskKey,
      claimed: pending.claimed,
    );
    return pending.channel;
  }

  /// A reported share is independent of whether task status was available.
  /// A task key and an unclaimed reward are only required for the subsequent
  /// reward claim.
  void _reportAndClaimIfEligible({
    required String? taskKey,
    required bool claimed,
  }) {
    unawaited(
      _reportThenClaimIfEligible(
        taskKey: taskKey,
        claimed: claimed,
      ).whenComplete(refreshStatus),
    );
  }

  Future<void> _reportThenClaimIfEligible({
    required String? taskKey,
    required bool claimed,
  }) async {
    try {
      await _reportShareAction?.call();
    } catch (_) {}
    if (claimed || taskKey == null || taskKey.isEmpty) return;
    if (_claimInFlightTaskKey == taskKey) return;
    _claimInFlightTaskKey = taskKey;
    try {
      final claimedSuccessfully = await _claimReward(taskKey);
      if (claimedSuccessfully) {
        await _onRewardClaimed?.call();
      }
    } catch (_) {}
    if (_claimInFlightTaskKey == taskKey) {
      _claimInFlightTaskKey = null;
    }
  }

  void clear() {
    _pending = null;
    _status = null;
    _statusRequest = null;
    _claimInFlightTaskKey = null;
  }
}

final shareDramaRewardCoordinatorProvider =
    Provider<ShareDramaRewardCoordinator>((ref) {
      final repository = ref.watch(rewardCoinsRepositoryProvider);
      return ShareDramaRewardCoordinator(
        claimReward: (taskKey) async {
          final result = await repository.claimTask(taskKey: taskKey);
          return result.isSuccess;
        },
        reportShareAction: () =>
            repository.reportTaskAction(actionKey: 'share_drama'),
        fetchStatus: ref
            .watch(playerRemoteDataSourceProvider)
            .fetchShareDramaStatus,
        claimedTodayStore: ShareDramaClaimedTodayStore(
          userId: () => ref.read(userInfoStoreProvider).userId,
        ),
        onRewardClaimed: () async {
          await Future.wait([
            ref
                .read(entitlementControllerProvider.notifier)
                .refreshFromServer(),
            ref
                .read(rewardCoinsControllerProvider.notifier)
                .loadRemainingCoin(),
          ]);
        },
      );
    });

class ShareDramaClaimedTodayStore {
  ShareDramaClaimedTodayStore({required String? Function() userId})
    : _userId = userId;

  final String? Function() _userId;

  Future<bool> hasClaimedToday() async {
    final key = _key();
    if (key == null) return false;
    return (await SharedPreferences.getInstance()).getBool(key) ?? false;
  }

  Future<void> markClaimedToday() async {
    final key = _key();
    if (key == null) return;
    await (await SharedPreferences.getInstance()).setBool(key, true);
  }

  String? _key() {
    final userId = _userId()?.trim();
    if (userId == null || userId.isEmpty) return null;
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'share_drama_claimed:$userId:$day';
  }
}

class _PendingShareDramaReward {
  _PendingShareDramaReward({
    required this.taskKey,
    required this.claimed,
    required this.channel,
    required this.createdAt,
  });

  final String? taskKey;
  final bool claimed;
  final ShareDramaRewardChannel channel;
  final DateTime createdAt;
  bool didEnterBackground = false;
}
