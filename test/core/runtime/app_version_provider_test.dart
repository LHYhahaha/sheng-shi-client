import 'package:drama_client/core/runtime/app_version_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('apiAppVersionProvider uses package info version', () async {
    final container = ProviderContainer(
      overrides: [
        packageInfoProvider.overrideWith(
          (ref) => Future.value(
            PackageInfo(
              appName: 'Drama',
              packageName: 'com.example.drama',
              version: '2.3.4',
              buildNumber: '99',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(packageInfoProvider.future);
    expect(container.read(apiAppVersionProvider), '2.3.4');
  });

  test('apiAppVersionProvider can be overridden directly', () {
    final container = ProviderContainer(
      overrides: [apiAppVersionProvider.overrideWithValue('9.9.9')],
    );
    addTearDown(container.dispose);

    expect(container.read(apiAppVersionProvider), '9.9.9');
  });
}
