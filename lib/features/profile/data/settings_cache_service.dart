import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../player/data/hls_disk_cache_store.dart';
import '../../player/data/player_playback_source_repository_provider.dart';

final settingsCacheServiceProvider = Provider<SettingsCacheService>((ref) {
  return SettingsCacheService(
    playbackCache: ref.watch(hlsDiskCacheStoreProvider),
    clearPlaybackMemory: () => ref.read(hlsLocalCacheStoreProvider).clear(),
  );
});

/// Deliberately uses an allowlist, never the whole temporary/documents folder.
/// User downloads, authentication and watch history are outside this scope.
class SettingsCacheService {
  SettingsCacheService({
    required this.playbackCache,
    required this.clearPlaybackMemory,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function()? clearImages,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clearImages = clearImages ?? (() => DefaultCacheManager().emptyCache());

  final HlsDiskCacheStore playbackCache;
  final void Function() clearPlaybackMemory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function() _clearImages;

  Future<List<File>> _temporaryFiles() async {
    final root = await _temporaryDirectory();
    final files = <File>[];
    for (final name in [DefaultCacheManager.key, 'ad_unlock_materials']) {
      final directory = Directory('${root.path}/$name');
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        continue;
      }
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) files.add(entity);
      }
    }
    return files;
  }

  Future<int> sizeBytes() async {
    var bytes = await playbackCache.sizeBytes();
    for (final file in await _temporaryFiles()) {
      try {
        bytes += await file.length();
      } on FileSystemException {
        if (await file.exists()) rethrow;
      }
    }
    return bytes;
  }

  Future<void> clear() async {
    // Snapshot before clearing the image manager so orphaned files are included.
    final files = await _temporaryFiles();
    await playbackCache.clear();
    clearPlaybackMemory();
    await _clearImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        if (await file.exists()) rethrow;
      }
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0MB';
    final mb = bytes / (1024 * 1024);
    return '${(mb < 0.1 ? 0.1 : mb).toStringAsFixed(1)}MB';
  }
}
