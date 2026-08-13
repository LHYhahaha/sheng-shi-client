import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// App 私有目录中的 HLS 二级缓存。
///
/// key 由 proxy 传入；当前会忽略 URL 的 expires/verify 签名参数。后端提供
/// cache_version 后，调用方应把版本加入 key，以便内容替换时精确失效。
class HlsDiskCacheStore {
  HlsDiskCacheStore({this.maxBytes = 350 * 1024 * 1024});

  final int maxBytes;
  Future<_HlsDiskIndex>? _indexFuture;
  Future<void> _writeTail = Future<void>.value();

  /// 由播放地址生成与签名无关的缓存 key。
  ///
  /// `expires` / `verify` 只控制本次回源授权；同一 HLS 内容重新签名后，已下载的
  /// playlist 与分片仍可复用。视频内容替换后的精确失效将在接口提供
  /// resource_version 后加入此 key。
  static String keyForUri(Uri uri) {
    final stableQuery = Map<String, String>.from(uri.queryParameters)
      ..remove('expires')
      ..remove('verify');
    // Uri.replace(queryParameters: null) 的语义是“保留原 query”，不是清空。
    // 传入空 Map 才会正确移除只有签名参数的 query。
    return uri.replace(queryParameters: stableQuery).toString();
  }

  Future<HlsDiskCacheEntry?> read(String key) async {
    try {
      final index = await _index();
      final entry = index.entries[key];
      if (entry == null) return null;
      final file = File('${index.directory.path}/${entry.fileName}');
      if (!await file.exists()) {
        index.entries.remove(key);
        await _save(index);
        return null;
      }
      final bytes = await file.readAsBytes();
      entry.lastAccessMs = DateTime.now().millisecondsSinceEpoch;
      await _save(index);
      return HlsDiskCacheEntry(bytes: bytes, contentType: entry.contentType);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, List<int> bytes, {String? contentType}) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      return Future<void>.value();
    }
    // 预热和真实播放可能同时写同一分片。串行化磁盘写，避免共用 .tmp/index 文件时
    // 互相覆盖；缓存失败不会影响回源播放。
    final operation = _writeTail.then(
      (_) => _write(key, bytes, contentType: contentType),
    );
    _writeTail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _write(
    String key,
    List<int> bytes, {
    String? contentType,
  }) async {
    try {
      final index = await _index();
      final digest = sha256.convert(utf8.encode(key)).toString();
      final name = '$digest.bin';
      final file = File('${index.directory.path}/$name');
      final temp = File('${index.directory.path}/$name.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      index.entries[key] = _HlsDiskIndexEntry(
        fileName: name,
        bytes: bytes.length,
        contentType: contentType,
        lastAccessMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _trim(index);
      await _save(index);
    } catch (_) {
      // 磁盘缓存不可用时不影响代理回源和正常播放。
    }
  }

  Future<_HlsDiskIndex> _index() {
    return _indexFuture ??= _load();
  }

  Future<_HlsDiskIndex> _load() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/player_hls_cache_v1');
    await directory.create(recursive: true);
    final indexFile = File('${directory.path}/index.json');
    try {
      final decoded =
          jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
      final rawEntries =
          (decoded['entries'] as Map<String, dynamic>? ?? const {});
      return _HlsDiskIndex(
        directory: directory,
        indexFile: indexFile,
        entries: rawEntries.map(
          (key, value) => MapEntry(
            key,
            _HlsDiskIndexEntry.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );
    } catch (_) {
      return _HlsDiskIndex(
        directory: directory,
        indexFile: indexFile,
        entries: {},
      );
    }
  }

  Future<void> _trim(_HlsDiskIndex index) async {
    var total = index.entries.values.fold<int>(
      0,
      (sum, entry) => sum + entry.bytes,
    );
    final oldest = index.entries.entries.toList()
      ..sort((a, b) => a.value.lastAccessMs.compareTo(b.value.lastAccessMs));
    for (final entry in oldest) {
      if (total <= maxBytes) break;
      final file = File('${index.directory.path}/${entry.value.fileName}');
      if (await file.exists()) await file.delete();
      index.entries.remove(entry.key);
      total -= entry.value.bytes;
    }
  }

  Future<void> _save(_HlsDiskIndex index) {
    return index.indexFile.writeAsString(
      jsonEncode({
        'entries': index.entries.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      }),
      flush: true,
    );
  }
}

class HlsDiskCacheEntry {
  const HlsDiskCacheEntry({required this.bytes, this.contentType});
  final List<int> bytes;
  final String? contentType;
}

class _HlsDiskIndex {
  const _HlsDiskIndex({
    required this.directory,
    required this.indexFile,
    required this.entries,
  });
  final Directory directory;
  final File indexFile;
  final Map<String, _HlsDiskIndexEntry> entries;
}

class _HlsDiskIndexEntry {
  _HlsDiskIndexEntry({
    required this.fileName,
    required this.bytes,
    required this.lastAccessMs,
    this.contentType,
  });
  factory _HlsDiskIndexEntry.fromJson(Map<String, dynamic> json) =>
      _HlsDiskIndexEntry(
        fileName: json['fileName'] as String,
        bytes: json['bytes'] as int,
        lastAccessMs: json['lastAccessMs'] as int,
        contentType: json['contentType'] as String?,
      );
  final String fileName;
  final int bytes;
  final String? contentType;
  int lastAccessMs;
  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'bytes': bytes,
    'lastAccessMs': lastAccessMs,
    'contentType': contentType,
  };
}
