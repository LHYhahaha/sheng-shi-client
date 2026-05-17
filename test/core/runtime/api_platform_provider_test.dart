import 'package:drama_client/core/runtime/api_platform_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveApiPlatform returns non-empty value', () {
    expect(resolveApiPlatform(), isNotEmpty);
  });

  test('apiPlatformProvider can be overridden in tests', () {
    final container = ProviderContainer(
      overrides: [apiPlatformProvider.overrideWithValue('web')],
    );
    addTearDown(container.dispose);

    expect(container.read(apiPlatformProvider), 'web');
  });
}
