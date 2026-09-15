import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readProjectFile(String path) =>
      File('${Directory.current.path}/$path').readAsStringSync();

  test('iOS Runner exposes the haha channel configuration', () {
    final infoPlist = readProjectFile('ios/Runner/Info.plist');
    final xcodeProject = readProjectFile('ios/Runner.xcodeproj/project.pbxproj');
    final appDelegate = readProjectFile('ios/Runner/AppDelegate.swift');

    expect(infoPlist, contains('<key>CHANNEL_FLAG</key>'));
    expect(infoPlist, contains(r'<string>$(CHANNEL_FLAG)</string>'));
    expect(infoPlist, contains('<key>MERCHANT_ID</key>'));
    expect(infoPlist, contains(r'<string>$(MERCHANT_ID)</string>'));
    expect(infoPlist, contains('<key>VEST_PKG_ID</key>'));
    expect(infoPlist, contains(r'<string>$(VEST_PKG_ID)</string>'));

    for (final setting in const <String, String>{
      'CHANNEL_FLAG': 'app_developer',
      'MERCHANT_ID': '329',
      'VEST_PKG_ID': '1001',
    }.entries) {
      expect(xcodeProject, contains('${setting.key} = ${setting.value};'));
    }

    expect(appDelegate, contains('com.yushi.drama/channel_config'));
    expect(appDelegate, contains('"channel_flag": Self.infoValue("CHANNEL_FLAG")'));
  });

  for (final flavor in const <String, ({String flag, String merchantId, String vestPkgId})>{
    'GF': (flag: 'GF_001', merchantId: '333', vestPkgId: '1001'),
    'haha': (flag: 'app_developer', merchantId: '329', vestPkgId: '1001'),
    'tiktok_dev': (flag: 'tiktok', merchantId: '319', vestPkgId: '1001'),
    'kuaishou_dev': (flag: 'kuaishou', merchantId: '320', vestPkgId: '1002'),
  }.entries) {
    test('iOS flavor ${flavor.key} resolves its Android channel values', () {
      final buildSettings = Process.runSync('xcodebuild', <String>[
        '-project',
        'ios/Runner.xcodeproj',
        '-scheme',
        flavor.key,
        '-configuration',
        'Debug-${flavor.key}',
        '-sdk',
        'iphonesimulator',
        '-showBuildSettings',
      ]);

      expect(buildSettings.exitCode, 0, reason: buildSettings.stderr);
      expect(buildSettings.stdout, contains('CHANNEL_FLAG = ${flavor.value.flag}'));
      expect(buildSettings.stdout, contains('MERCHANT_ID = ${flavor.value.merchantId}'));
      expect(buildSettings.stdout, contains('VEST_PKG_ID = ${flavor.value.vestPkgId}'));
    });
  }
}
