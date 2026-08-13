import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hls_disk_cache_store.dart';

/// HLS 网络响应的统一字节表示，供预热器和本地代理共享同一下载 Future。
class HlsNetworkResponse {
  const HlsNetworkResponse({
    required this.statusCode,
    required this.bytes,
    this.contentLength,
    this.contentType,
  });

  final int statusCode;
  final List<int> bytes;
  final int? contentLength;
  final String? contentType;
}

/// 可逐块消费的远端 HLS 响应。用于让本地代理在分片尚未完整下载时就开始向
/// media player 转发，同时由同一飞行任务收集完整字节供预热和磁盘缓存复用。
class HlsNetworkStreamResponse {
  const HlsNetworkStreamResponse({
    required this.statusCode,
    required this.chunks,
    this.contentType,
  });

  final int statusCode;
  final Stream<List<int>> chunks;
  final String? contentType;
}

abstract interface class HlsNetworkStreamingHttpClient {
  Future<HlsNetworkStreamResponse> open(Uri uri, {required Duration timeout});
}

class HlsNetworkStreamHandle {
  const HlsNetworkStreamHandle._({
    required this.metadata,
    required this.chunks,
    required this.completed,
  });

  final Future<HlsNetworkStreamMetadata> metadata;
  final Stream<List<int>> chunks;
  final Future<HlsNetworkResponse> completed;
}

class HlsNetworkStreamMetadata {
  const HlsNetworkStreamMetadata({required this.statusCode, this.contentType});

  final int statusCode;
  final String? contentType;
}

enum HlsRequestPriority { preload, playback }

/// 应用级 HLS playlist/segment 单飞协调器。
///
/// 同一稳定资源（忽略 expires/verify）只允许一个远端请求。真实播放器可以加入
/// 正在进行的预热请求，避免取消预热后又从 CDN 重新下载相同分片。
class HlsNetworkRequestCoordinator {
  final Map<String, Future<HlsNetworkResponse>> _inFlight = {};
  final Map<String, _HlsStreamFlight> _streamFlights = {};

  Future<HlsNetworkResponse> fetch(
    Uri uri, {
    required HlsRequestPriority priority,
    required Future<HlsNetworkResponse> Function() request,
  }) {
    final key = HlsDiskCacheStore.keyForUri(uri);
    final existing = _inFlight[key];
    if (existing != null) {
      _log('join', uri, priority: priority);
      return existing;
    }
    _log('start', uri, priority: priority);
    // 先登记，再安排实际网络调用。request() 可能同步开始 HTTP；若先调用它，
    // 紧跟着进来的真实播放请求会在登记前漏过，造成重复回源。
    late final Future<HlsNetworkResponse> future;
    future = Future<HlsNetworkResponse>.microtask(request).whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = future;
    return future;
  }

  /// 与 [fetch] 使用同一稳定 cache key 的共享流请求。
  ///
  /// 后加入的消费者会先收到已经到达的字节，再订阅后续块；因此预热先启动、真实
  /// 播放后加入时，不必等待预热把整段下载完才开始收到数据。
  HlsNetworkStreamHandle streamFetch(
    Uri uri, {
    required HlsRequestPriority priority,
    required Future<HlsNetworkStreamResponse> Function() open,
  }) {
    final key = HlsDiskCacheStore.keyForUri(uri);
    final existing = _streamFlights[key];
    if (existing != null) {
      _log('stream join', uri, priority: priority);
      return existing.subscribe();
    }
    _log('stream start', uri, priority: priority);
    late final _HlsStreamFlight flight;
    flight = _HlsStreamFlight(
      open: open,
      onDone: () {
        if (identical(_streamFlights[key], flight)) {
          _streamFlights.remove(key);
        }
      },
    );
    _streamFlights[key] = flight;
    flight.start();
    return flight.subscribe();
  }

  void _log(String event, Uri uri, {required HlsRequestPriority priority}) {
    const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
    if (!shouldPrint) return;
    debugPrint(
      '${DateTime.now().toIso8601String()} session=hls-network-singleflight '
      '$event priority=${priority.name} key=${HlsDiskCacheStore.keyForUri(uri)}',
    );
  }
}

class _HlsStreamFlight {
  _HlsStreamFlight({required this.open, required this.onDone});

  final Future<HlsNetworkStreamResponse> Function() open;
  final void Function() onDone;
  final _chunks = StreamController<List<int>>.broadcast();
  final _metadata = Completer<HlsNetworkStreamMetadata>();
  final _completed = Completer<HlsNetworkResponse>();
  final _buffer = <int>[];
  var _started = false;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  HlsNetworkStreamHandle subscribe() {
    // 这里的同步快照与紧接着建立的 broadcast 订阅之间没有 async gap；随后到达
    // 的 chunk 不会漏掉，先到的 chunk 则由 snapshot 补齐。
    final snapshot = List<int>.from(_buffer);
    final replay = StreamController<List<int>>();
    late final StreamSubscription<List<int>> subscription;
    subscription = _chunks.stream.listen(
      replay.add,
      onError: replay.addError,
      onDone: () {
        unawaited(replay.close());
        unawaited(subscription.cancel());
      },
    );
    Stream<List<int>> merged() async* {
      if (snapshot.isNotEmpty) yield snapshot;
      yield* replay.stream;
    }

    return HlsNetworkStreamHandle._(
      metadata: _metadata.future,
      chunks: merged(),
      completed: _completed.future,
    );
  }

  Future<void> _run() async {
    try {
      final response = await open();
      _metadata.complete(
        HlsNetworkStreamMetadata(
          statusCode: response.statusCode,
          contentType: response.contentType,
        ),
      );
      await for (final chunk in response.chunks) {
        _buffer.addAll(chunk);
        _chunks.add(chunk);
      }
      await _chunks.close();
      _completed.complete(
        HlsNetworkResponse(
          statusCode: response.statusCode,
          bytes: List<int>.unmodifiable(_buffer),
          contentType: response.contentType,
        ),
      );
    } catch (error, stackTrace) {
      if (!_metadata.isCompleted) {
        _metadata.completeError(error, stackTrace);
      }
      _chunks.addError(error, stackTrace);
      await _chunks.close();
      if (!_completed.isCompleted) {
        _completed.completeError(error, stackTrace);
      }
    } finally {
      onDone();
    }
  }
}
