import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/runtime/in_memory_install_id_storage.dart';
import 'package:drama_client/core/runtime/install_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  test('first launch generates install id and persists', () async {
    final storage = InMemoryInstallIdStorage();
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final first = await container.read(installIdProvider.future);
    expect(first, matches(uuidPattern));
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
    expect(second, matches(uuidPattern));
    expect(second, isNot(first));
  });

  test('legacy non uuid install id is migrated to uuid', () async {
    final storage = InMemoryInstallIdStorage();
    await storage.write('ed486125705f7f18');
    final container = ProviderContainer(
      overrides: [installIdStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final migrated = await container.read(installIdProvider.future);

    expect(migrated, matches(uuidPattern));
    expect(migrated, isNot('ed486125705f7f18'));
    expect(await storage.read(), migrated);
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
