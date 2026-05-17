import 'package:drama_client/bootstrap/feature_session_cleanup.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/membership/application/membership_controller.dart';
import 'package:drama_client/features/my_list/application/my_list_controller.dart';
import 'package:drama_client/features/profile/application/profile_controller.dart';
import 'package:drama_client/features/store/application/store_controller.dart';
import 'package:drama_client/features/wallet/application/wallet_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature hooks reset guest-facing state after refresh failed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(featureSessionCleanupRegistrationProvider);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(
          const AuthTokenSnapshot(
            accessToken: 'access',
            refreshToken: 'refresh',
          ),
        );

    await container
        .read(entitlementControllerProvider.notifier)
        .grantMockMembership(source: 'test');
    await container
        .read(entitlementControllerProvider.notifier)
        .grantMockCoins(amount: 500, source: 'test');
    container
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: 'd1',
          episodeId: 'e1',
          itemId: 'i1',
          unlockType: EpisodeUnlockType.coins,
          price: 10,
        );

    container.read(storeControllerProvider.notifier).state = container
        .read(storeControllerProvider)
        .copyWith(purchaseStatus: StorePurchaseStatus.processing);
    container.read(membershipControllerProvider.notifier).state = container
        .read(membershipControllerProvider)
        .copyWith(purchaseStatus: MembershipPurchaseStatus.processing);

    await container
        .read(sessionCleanupCoordinatorProvider)
        .cleanup(SessionCleanupReason.refreshFailed);

    final entitlement = container.read(entitlementControllerProvider);
    expect(entitlement.isGuest, isTrue);
    expect(entitlement.isMember, isFalse);
    expect(entitlement.coinBalance, 0);
    expect(entitlement.unlockedEpisodeIds, isEmpty);
    expect(entitlement.pendingUnlock, isNull);

    final wallet = container.read(walletControllerProvider);
    expect(wallet.coins, 0);
    expect(wallet.isLoading, isTrue);

    final profile = container.read(profileControllerProvider);
    expect(profile.needsSessionReload, isTrue);

    final myList = container.read(myListControllerProvider);
    expect(myList.items, isEmpty);
    expect(myList.isLoading, isTrue);

    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.idle,
    );
    expect(
      container.read(membershipControllerProvider).purchaseStatus,
      MembershipPurchaseStatus.idle,
    );
    expect(container.read(authTokenStoreProvider).hasAccessToken, isFalse);
  });

  test('logout via auth repository triggers cleanup hooks', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(featureSessionCleanupRegistrationProvider);

    await container.read(authControllerProvider.notifier).load();
    await container
        .read(entitlementControllerProvider.notifier)
        .grantMockMembership(source: 'test');

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(entitlementControllerProvider).isMember, isFalse);
  });
}
