import 'package:drama_client/core/runtime/cellular_download_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults off and restores both choices across containers', () async {
    SharedPreferences.setMockInitialValues({});
    var container = ProviderContainer();
    expect(
      await container.read(cellularDownloadPreferenceProvider.future),
      false,
    );
    await container
        .read(cellularDownloadPreferenceProvider.notifier)
        .setEnabled(true);
    container.dispose();

    container = ProviderContainer();
    expect(
      await container.read(cellularDownloadPreferenceProvider.future),
      true,
    );
    await container
        .read(cellularDownloadPreferenceProvider.notifier)
        .setEnabled(false);
    container.dispose();

    container = ProviderContainer();
    expect(
      await container.read(cellularDownloadPreferenceProvider.future),
      false,
    );
    container.dispose();
  });
}
