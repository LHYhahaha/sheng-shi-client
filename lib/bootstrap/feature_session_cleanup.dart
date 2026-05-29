import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_cleanup_coordinator.dart';
import '../core/modal/app_modal_business_cleanup.dart';
import '../core/modal/app_modal_provider.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/entitlement/application/entitlement_controller.dart';
import '../features/membership/application/membership_controller.dart';
import '../features/my_list/application/my_list_controller.dart';
import '../features/player/application/player_session_cleanup.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/store/application/store_controller.dart';
import '../features/wallet/application/wallet_controller.dart';

/// 在应用启动时注册各 feature 的 session cleanup hook（A7）。
///
/// 放在 bootstrap 层，避免 feature application 直接依赖 [SessionCleanupCoordinator]。
/// Hook 注册时捕获 notifier / service，避免 async cleanup 后再读已 dispose 的 [Ref]。
final featureSessionCleanupRegistrationProvider = Provider<void>((ref) {
  final coordinator = ref.read(sessionCleanupCoordinatorProvider);
  final modalService = ref.read(appModalServiceProvider);
  final authController = ref.read(authControllerProvider.notifier);
  final entitlementController = ref.read(
    entitlementControllerProvider.notifier,
  );
  final walletController = ref.read(walletControllerProvider.notifier);
  final profileController = ref.read(profileControllerProvider.notifier);
  final myListController = ref.read(myListControllerProvider.notifier);
  final storeController = ref.read(storeControllerProvider.notifier);
  final membershipController = ref.read(membershipControllerProvider.notifier);
  coordinator.registerFeatureHooks([
    (_) async {
      dismissAllBlockingBusinessModals(modalService);
    },
    (reason) async {
      authController.resetForSessionCleanup(reason);
    },
    (reason) async {
      entitlementController.resetForSessionCleanup(reason);
    },
    (reason) async {
      walletController.resetForSessionCleanup(reason);
    },
    (reason) async {
      profileController.resetForSessionCleanup(reason);
    },
    (reason) async {
      myListController.resetForSessionCleanup(reason);
    },
    (_) async {
      await runPlayerSessionCleanupWith(
        read: <T>(dynamic provider) => ref.read(provider),
        invalidate: (dynamic provider) => ref.invalidate(provider),
      );
    },
    (reason) async {
      storeController.resetForSessionCleanup(reason);
    },
    (reason) async {
      membershipController.resetForSessionCleanup(reason);
    },
    // Session cleanup 完成后，自动触发重新登录流程
    // 这确保 token 失效后能自动恢复到游客登录状态，并获取用户信息
    (reason) async {
      print('[FeatureSessionCleanup] Triggering re-login after cleanup for reason: $reason');
      try {
        await authController.load();
        print('[FeatureSessionCleanup] Re-login completed successfully');
      } catch (e) {
        print('[FeatureSessionCleanup] Re-login failed: $e');
      }
    },
  ]);
});
