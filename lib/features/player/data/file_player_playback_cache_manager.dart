import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';

abstract interface class PlaybackFileDownloader {
  Future<void> download({required Uri remoteUri, required File destination});
}

class HttpPlaybackFileDownloader implements PlaybackFileDownloader {
  const HttpPlaybackFileDownloader({
    this.timeout = const Duration(seconds: 20),
  });

  final Duration timeout;

  @override
  Future<void> download({
    required Uri remoteUri,
    required File destination,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(remoteUri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Playback cache download failed with HTTP ${response.statusCode}.',
          uri: remoteUri,
        );
      }
      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      await response.pipe(sink).timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

class FilePlayerPlaybackCacheManager implements PlayerPlaybackCacheManager {
  FilePlayerPlaybackCacheManager({
    required Directory cacheDirectory,
    PlaybackFileDownloader downloader = const HttpPlaybackFileDownloader(),
  }) : _cacheDirectory = cacheDirectory,
       _downloader = downloader;

  final Directory _cacheDirectory;
  final PlaybackFileDownloader _downloader;
  final _pendingTempFilePaths = <String>{};
  int _generation = 0;

  @override
  Future<PlaybackSource?> lookup({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  }) async {
    if (!policy.allowCache || !_isDownloadableRemote(remoteUrl)) {
      return null;
    }
    final entry = await _readEntry(policy.cacheKey);
    if (entry == null || entry.remoteUrl != remoteUrl) {
      return null;
    }
    if (entry.expiresAt.isBefore(DateTime.now())) {
      return null;
    }
    final file = _mediaFile(policy.cacheKey, policy.format);
    if (!await file.exists()) {
      return null;
    }
    final length = await file.length();
    if (length <= 0) {
      return null;
    }
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: file.path,
      cachePolicy: policy,
      cacheStatus: PlaybackCacheStatus.hit,
    );
  }

  @override
  Future<PlaybackSource> download({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  }) async {
    if (!policy.allowCache || !_isDownloadableRemote(remoteUrl)) {
      return _remoteSource(item: item, policy: policy, remoteUrl: remoteUrl);
    }
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null || !uri.hasScheme) {
      return _remoteSource(item: item, policy: policy, remoteUrl: remoteUrl);
    }

    final generation = _generation;
    final key = policy.cacheKey;
    final mediaFile = _mediaFile(key, policy.format);
    final tempFile = File('${mediaFile.path}.download');
    final tempFilePath = tempFile.path;
    _pendingTempFilePaths.add(tempFilePath);
    try {
      await _downloader.download(remoteUri: uri, destination: tempFile);
      if (generation != _generation ||
          !_pendingTempFilePaths.contains(tempFilePath)) {
        await _deleteIfExists(tempFile);
        return _remoteSource(item: item, policy: policy, remoteUrl: remoteUrl);
      }
      await tempFile.rename(mediaFile.path);
      await _writeEntry(
        _FileCacheEntry(remoteUrl: remoteUrl, expiresAt: policy.expiresAt),
        policy.cacheKey,
      );
      return PlaybackSource(
        itemId: item.id,
        remoteUrl: remoteUrl,
        playableSource: mediaFile.path,
        cachePolicy: policy,
        cacheStatus: PlaybackCacheStatus.miss,
      );
    } catch (_) {
      await _deleteIfExists(tempFile);
      rethrow;
    } finally {
      _pendingTempFilePaths.remove(tempFilePath);
    }
  }

  @override
  Future<void> releasePending() async {
    _generation += 1;
    final pendingTempFilePaths = List<String>.from(_pendingTempFilePaths);
    _pendingTempFilePaths.clear();
    await Future.wait(
      pendingTempFilePaths.map((path) => _deleteIfExists(File(path))),
    );
  }

  PlaybackSource _remoteSource({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  }) {
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: remoteUrl,
      cachePolicy: policy,
      cacheStatus: PlaybackCacheStatus.miss,
    );
  }

  bool _isDownloadableRemote(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<_FileCacheEntry?> _readEntry(String cacheKey) async {
    final file = _metadataFile(cacheKey);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final remoteUrl = decoded['remoteUrl'];
      final expiresAt = decoded['expiresAt'];
      if (remoteUrl is! String || expiresAt is! String) {
        return null;
      }
      return _FileCacheEntry(
        remoteUrl: remoteUrl,
        expiresAt: DateTime.parse(expiresAt),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeEntry(_FileCacheEntry entry, String cacheKey) async {
    final file = _metadataFile(cacheKey);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'remoteUrl': entry.remoteUrl,
        'expiresAt': entry.expiresAt.toIso8601String(),
      }),
    );
  }

  File _mediaFile(String cacheKey, String format) {
    return File('${_mediaPath(cacheKey)}.$format');
  }

  String _mediaPath(String cacheKey) {
    return '${_cacheDirectory.path}/${_cacheFileName(cacheKey)}';
  }

  File _metadataFile(String cacheKey) {
    return File('${_mediaPath(cacheKey)}.json');
  }

  String _cacheFileName(String cacheKey) {
    return base64Url.encode(utf8.encode(cacheKey)).replaceAll('=', '');
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _FileCacheEntry {
  const _FileCacheEntry({required this.remoteUrl, required this.expiresAt});

  final String remoteUrl;
  final DateTime expiresAt;
}
