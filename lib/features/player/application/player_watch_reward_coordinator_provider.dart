import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_info_store.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../rewards/application/reward_coins_controller.dart';
import '../../rewards/application/member_points_controller.dart';
import '../data/shared_preferences_watch_reward_attempt_store.dart';
import '../data/watch_reward_repository_provider.dart';
import 'player_watch_reward_coordinator.dart';

final playerWatchRewardCoordinatorProvider =
    Provider<PlayerWatchRewardCoordinator>((ref) {
      final coordinator = PlayerWatchRewardCoordinator(
        repository: ref.watch(watchRewardRepositoryProvider),
        attemptStore: ref.watch(watchRewardAttemptStoreProvider),
        onGranted: (userId, result) {
          if (!ref.mounted ||
              ref.read(userInfoStoreProvider).userId != userId) {
            return;
          }
          unawaited(() async {
            try {
              await Future.wait([
                ref
                    .read(entitlementControllerProvider.notifier)
                    .refreshFromServer(),
                if (result.rewardType ==
                    PlayerWatchRewardCoordinator.coinType) ...[
                  ref.read(rewardCoinsControllerProvider.notifier).loadTasks(),
                  ref
                      .read(rewardCoinsControllerProvider.notifier)
                      .loadRemainingCoin(),
                ],
                if (result.rewardType == PlayerWatchRewardCoordinator.pointType)
                  ref
                      .read(memberPointsControllerProvider.notifier)
                      .loadDailyDetail(),
              ]);
            } catch (_) {}
          }());
        },
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
