import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/runtime/in_memory_install_id_storage.dart';
import 'package:drama_client/core/runtime/install_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first launch generates install id and persists', () async {
    final storage = InMemoryInstallIdStorage();
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final first = await container.read(installIdProvider.future);
    expect(first, isNotEmpty);
    expect(await storage.read(), first);
  });

  test('second read returns same install id', () async {
    final storage = InMemoryInstallIdStorage();
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final first = await container.read(installIdProvider.future);
    final second = await container.read(installIdProvider.future);
    expect(second, first);
  });

  test('clear storage simulates app data clear and regenerates', () async {
    final storage = InMemoryInstallIdStorage();
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final first = await container.read(installIdProvider.future);
    await storage.clear();
    container.invalidate(installIdProvider);
    final second = await container.read(installIdProvider.future);
    expect(second, isNotEmpty);
    expect(second, isNot(first));
  });

  test('logout does not clear install id', () async {
    final storage = InMemoryInstallIdStorage();
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final beforeLogout = await container.read(installIdProvider.future);
    await container.read(authTokenStoreProvider.notifier).clear();
    final afterLogout = await container.read(installIdProvider.future);
    expect(afterLogout, beforeLogout);
    expect(await storage.read(), beforeLogout);
  });
}
