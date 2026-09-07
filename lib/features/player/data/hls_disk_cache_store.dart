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
  int _generation = 0;
  Future<void> _writeTail = Future<void>.value();

  /// Only media payloads count; the empty index is bookkeeping, not cache.
  Future<int> sizeBytes() async {
    await _writeTail;
    final index = await _index();
    var total = 0;
    await for (final entity in index.directory.list(followLinks: false)) {
      if (entity is File && entity.path != index.indexFile.path) {
        try {
          total += await entity.length();
        } on FileSystemException {
          if (await entity.exists()) rethrow;
        }
      }
    }
    return total;
  }

  Future<void> clear() {
    _generation++;
    final operation = _writeTail.then((_) async {
      final index = await _index();
      index.entries.clear();
      await for (final entity in index.directory.list(followLinks: false)) {
        if (entity is File && entity.path != index.indexFile.path) {
          try {
            await entity.delete();
          } on FileSystemException {
            if (await entity.exists()) rethrow;
          }
        }
      }
      await _save(index);
    });
    _writeTail = operation.catchError((_) {});
    return operation;
  }

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

  /// Streams a resource directly to a temporary file.  The completed file is
  /// published atomically, so incomplete downloads are never cache hits.
  Future<HlsDiskCacheStreamWriter> openStreamWriter(
    String key, {
    String? contentType,
  }) async {
    final index = await _index();
    final digest = sha256.convert(utf8.encode(key)).toString();
    final file = File('${index.directory.path}/$digest.bin');
    final temp = File(
      '${index.directory.path}/$digest.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    return HlsDiskCacheStreamWriter._(
      store: this,
      generation: _generation,
      key: key,
      file: file,
      temp: temp,
      contentType: contentType,
    );
  }

  Future<void> _commitStreamWriter(HlsDiskCacheStreamWriter writer) {
    final operation = _writeTail.then((_) async {
      try {
        if (writer.generation != _generation) {
          await writer._deleteTemp();
          return;
        }
        final index = await _index();
        if (await writer.file.exists()) await writer.file.delete();
        await writer.temp.rename(writer.file.path);
        index.entries[writer.key] = _HlsDiskIndexEntry(
          fileName: writer.file.uri.pathSegments.last,
          bytes: writer.length,
          contentType: writer.contentType,
          lastAccessMs: DateTime.now().millisecondsSinceEpoch,
        );
        await _trim(index);
        await _save(index);
      } catch (_) {
        try {
          if (await writer.temp.exists()) await writer.temp.delete();
        } catch (_) {}
      }
    });
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

class HlsDiskCacheStreamWriter {
  HlsDiskCacheStreamWriter._({
    required HlsDiskCacheStore store,
    required this.generation,
    required this.key,
    required this.file,
    required this.temp,
    this.contentType,
  }) : _store = store,
       _sink = temp.openWrite();

  final HlsDiskCacheStore _store;
  final int generation;
  final String key;
  final File file;
  final File temp;
  final String? contentType;
  final IOSink _sink;
  var _length = 0;
  var _closed = false;

  int get length => _length;

  void add(List<int> chunk) {
    if (_closed) return;
    _sink.add(chunk);
    _length += chunk.length;
  }

  Future<void> commit() async {
    if (_closed) return;
    _closed = true;
    await _sink.close();
    if (_length == 0 || _length > _store.maxBytes) {
      await _deleteTemp();
      return;
    }
    await _store._commitStreamWriter(this);
  }

  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      await _sink.close();
    }
    await _deleteTemp();
  }

  Future<void> _deleteTemp() async {
    try {
      if (await temp.exists()) await temp.delete();
    } catch (_) {}
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
