import 'package:drama_client/features/player/application/player_recharge_unlock_controller.dart';
import 'package:drama_client/features/player/domain/player_recharge_unlock_offer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bonus badge percent uses bonus over total coins', () {
    const package = PlayerRechargeCoinPackage(
      id: 'coins_300',
      baseCoins: 300,
      bonusCoins: 30,
      googleProductId: 'coins_300_bonus',
      googlePriceLabel: r'$2.99',
    );

    expect(package.bonusPercent, 9);
  });

  test('loads offer without embedding coin balance', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    await container
        .read(provider.notifier)
        .open(itemId: 'drama-a-ep-2', requiredCoins: 60);

    final state = container.read(provider);
    expect(state.status, PlayerRechargeUnlockStatus.idle);
    expect(state.offer?.requiredCoins, 60);
    expect(state.offer?.coinPackages, hasLength(4));
    expect(state.offer?.membershipPackages, hasLength(2));
  });

  test('selecting coin package enters processing then success', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: 'drama-a-ep-2', requiredCoins: 60);

    final purchase = controller.selectCoinPackage('coins_300');
    expect(container.read(provider).selectedCoinPackageId, 'coins_300');
    expect(
      container.read(provider).status,
      PlayerRechargeUnlockStatus.processing,
    );

    await purchase;
    expect(container.read(provider).status, PlayerRechargeUnlockStatus.success);
  });

  test('selecting membership package enters processing then success', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: 'drama-a-ep-2', requiredCoins: 60);

    final purchase = controller.selectMembershipPackage('weekly_vip_promo');
    expect(
      container.read(provider).selectedMembershipPackageId,
      'weekly_vip_promo',
    );
    expect(
      container.read(provider).status,
      PlayerRechargeUnlockStatus.processing,
    );

    await purchase;
    expect(container.read(provider).status, PlayerRechargeUnlockStatus.success);
  });

  test('closing sheet cancels pending mock purchase completion', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: 'drama-a-ep-2', requiredCoins: 60);

    final purchase = controller.selectCoinPackage('coins_300');
    controller.close();
    await purchase;

    expect(
      container.read(provider).status,
      PlayerRechargeUnlockStatus.cancelled,
    );
  });
}
