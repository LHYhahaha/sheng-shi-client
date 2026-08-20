import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_cleanup_coordinator.dart';
import '../core/auth/user_info_store.dart';
import '../core/modal/app_modal_business_cleanup.dart';
import '../core/modal/app_modal_provider.dart';
import '../core/user_library/user_library_sync_controller.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/entitlement/application/entitlement_controller.dart';
import '../features/membership/application/membership_controller.dart';
import '../features/my_list/application/my_list_controller.dart';
import '../features/player/application/player_session_cleanup.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/store/application/store_controller.dart';
import '../features/wallet/application/wallet_controller.dart';

/// 主动退出由 [AuthController.logout] 在 cleanup 后自行完成一次设备登录；不能由
/// cleanup hook 再次触发，否则会产生并发的 device login。
bool shouldRestoreGuestSessionAfterCleanup(SessionCleanupReason reason) {
  return reason != SessionCleanupReason.logout &&
      reason != SessionCleanupReason.deleteAccount &&
      reason != SessionCleanupReason.guestSessionExpiredExit;
}

/// 在应用启动时注册各 feature 的 session cleanup hook（A7）。
///
/// 放在 bootstrap 层，避免 feature application 直接依赖 [SessionCleanupCoordinator]。
/// Hook 注册时捕获 notifier / service，避免 async cleanup 后再读已 dispose 的 [Ref]。
final featureSessionCleanupRegistrationProvider = Provider<void>((ref) {
  final coordinator = ref.read(sessionCleanupCoordinatorProvider);
  final modalService = ref.read(appModalServiceProvider);
  final authController = ref.read(authControllerProvider.notifier);
  final userInfoStore = ref.read(userInfoStoreProvider.notifier);
  final entitlementController = ref.read(
    entitlementControllerProvider.notifier,
  );
  final walletController = ref.read(walletControllerProvider.notifier);
  final profileController = ref.read(profileControllerProvider.notifier);
  final myListController = ref.read(myListControllerProvider.notifier);
  final storeController = ref.read(storeControllerProvider.notifier);
  final membershipController = ref.read(membershipControllerProvider.notifier);
  final userLibrarySyncController = ref.read(
    userLibrarySyncControllerProvider.notifier,
  );
  coordinator.registerFeatureHooks([
    (_) async {
      dismissAllBlockingBusinessModals(modalService);
    },
    (reason) async {
      authController.resetForSessionCleanup(reason);
    },
    (_) async {
      await userInfoStore.clear();
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
    (reason) async {
      userLibrarySyncController.resetForSessionCleanup(reason);
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
    // 非主动退出的 session cleanup 完成后，自动恢复游客登录。
    // AuthController.logout 本身会在 cleanup 返回后登录一次 device；若这里也
    // 调用 load，会产生两条并发的 /api/user/device/login，并相互覆盖 token。
    (reason) async {
      if (!shouldRestoreGuestSessionAfterCleanup(reason)) {
        return;
      }
      debugPrint(
        '[FeatureSessionCleanup] Triggering re-login after cleanup for reason: $reason',
      );
      try {
        await authController.load();
        debugPrint('[FeatureSessionCleanup] Re-login completed successfully');
      } catch (e) {
        debugPrint('[FeatureSessionCleanup] Re-login failed: $e');
      }
    },
  ]);
});
