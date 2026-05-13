import 'package:drama_client/features/store/application/store_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads store packages from repository', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(storeControllerProvider.notifier).load();

    final state = container.read(storeControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.coinPackages, hasLength(3));
    expect(state.vipPackages, hasLength(2));
    expect(state.selectedPackage?.id, 'coins_2000');
  });

  test('selects package and opens mock confirmation state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.selectPackage('coins_3000_bonus');
    controller.showConfirmation();

    final state = container.read(storeControllerProvider);
    expect(state.selectedPackage?.id, 'coins_3000_bonus');
    expect(state.confirmationPackage?.title, '3000');

    controller.hideConfirmation();
    expect(container.read(storeControllerProvider).confirmationPackage, isNull);
  });
}
