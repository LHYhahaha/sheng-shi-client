import 'package:drama_client/shared/url/external_url_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UrlLauncherPlatform previousPlatform;
  late _FakeUrlLauncherPlatform fakePlatform;

  setUp(() {
    previousPlatform = UrlLauncherPlatform.instance;
    fakePlatform = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakePlatform;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousPlatform;
  });

  test('opens trimmed url with external application mode', () async {
    final opened = await const PlatformExternalUrlLauncher().open(
      '  https://example.test/activity  ',
    );

    expect(opened, isTrue);
    expect(fakePlatform.launchedUrl, 'https://example.test/activity');
    expect(
      fakePlatform.launchOptions?.mode,
      PreferredLaunchMode.externalApplication,
    );
  });

  test('does not call platform for blank url', () async {
    final opened = await const PlatformExternalUrlLauncher().open('   ');

    expect(opened, isFalse);
    expect(fakePlatform.launchedUrl, isNull);
  });
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launchedUrl;
  LaunchOptions? launchOptions;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchOptions = options;
    return true;
  }
}
