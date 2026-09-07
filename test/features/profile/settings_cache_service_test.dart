import 'dart:io';

import 'package:drama_client/features/player/data/hls_disk_cache_store.dart';
import 'package:drama_client/features/profile/data/settings_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HlsDiskCacheStore playback;
  late SettingsCacheService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('settings-cache-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    playback = HlsDiskCacheStore();
    service = SettingsCacheService(
      playbackCache: playback,
      clearPlaybackMemory: () {},
      temporaryDirectory: () async => root,
      clearImages: () async {},
    );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });

  Future<File> file(String path, int size) async {
    final target = File('${root.path}/$path');
    await target.parent.create(recursive: true);
    return target.writeAsBytes(List.filled(size, 1));
  }

  test(
    'counts cache payloads and preserves downloads and unrelated files',
    () async {
      await playback.write('episode', List.filled(100, 1));
      await file('libCachedImageData/image', 200);
      await file('ad_unlock_materials/ad.material', 300);
      final download = await file('downloads/episode.mp4', 400);
      final other = await file('unrelated.tmp', 500);
      expect(await service.sizeBytes(), 600);
      await service.clear();
      expect(await service.sizeBytes(), 0);
      expect(await download.length(), 400);
      expect(await other.length(), 500);
      expect(await playback.read('episode'), isNull);
      await playback.write('episode', [1, 2]);
      expect((await playback.read('episode'))?.bytes, [1, 2]);
    },
  );

  test('stream opened before clear cannot restore old cache', () async {
    final writer = await playback.openStreamWriter('old');
    writer.add([1, 2, 3]);
    await playback.clear();
    await writer.commit();
    expect(await playback.read('old'), isNull);
    expect(await playback.sizeBytes(), 0);
  });

  test('does not follow links into downloads', () async {
    final download = await file('downloads/episode.mp4', 400);
    await Directory('${root.path}/ad_unlock_materials').create();
    await Link(
      '${root.path}/ad_unlock_materials/downloads',
    ).create(download.parent.path);
    expect(await service.sizeBytes(), 0);
    await service.clear();
    expect(await download.length(), 400);
  });

  test('formats empty and small caches distinctly', () {
    expect(SettingsCacheService.formatBytes(0), '0MB');
    expect(SettingsCacheService.formatBytes(1), '0.1MB');
    expect(SettingsCacheService.formatBytes(1048576), '1.0MB');
  });
}
