import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_cleanup_coordinator.dart';
import '../features/entitlement/application/entitlement_controller.dart';
import '../features/membership/application/membership_controller.dart';
import '../features/my_list/application/my_list_controller.dart';
import '../features/player/application/player_session_cleanup.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/store/application/store_controller.dart';
import '../features/wallet/application/wallet_controller.dart';

/// 在应用启动时注册各 feature 的 session cleanup hook。
///
/// 放在 bootstrap 层，避免 feature application 直接依赖 [SessionCleanupCoordinator]。
final featureSessionCleanupRegistrationProvider = Provider<void>((ref) {
  final coordinator = ref.read(sessionCleanupCoordinatorProvider);
  coordinator.registerFeatureHooks([
    (reason) async {
      ref
          .read(entitlementControllerProvider.notifier)
          .resetForSessionCleanup(reason);
    },
    (reason) async {
      ref
          .read(walletControllerProvider.notifier)
          .resetForSessionCleanup(reason);
    },
    (reason) async {
      ref
          .read(profileControllerProvider.notifier)
          .resetForSessionCleanup(reason);
    },
    (reason) async {
      ref
          .read(myListControllerProvider.notifier)
          .resetForSessionCleanup(reason);
    },
    (reason) async {
      await runPlayerSessionCleanup(ref);
    },
    (reason) async {
      ref.read(storeControllerProvider.notifier).resetForSessionCleanup(reason);
    },
    (reason) async {
      ref
          .read(membershipControllerProvider.notifier)
          .resetForSessionCleanup(reason);
    },
  ]);
});
