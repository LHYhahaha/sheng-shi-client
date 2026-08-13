import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drama_client/features/player/data/hls_local_proxy_server.dart';
import 'package:drama_client/features/player/data/hls_network_request_coordinator.dart';
import 'package:drama_client/features/player/data/hls_traffic_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playlist rewrite resolves relative segment and playlist urls', () {
    final rewritten = rewritePlaylist(
      Uri.parse('https://cdn.example.com/hls/master.m3u8'),
      [
        '#EXTM3U',
        '#EXT-X-STREAM-INF:BANDWIDTH=800000',
        'low/prog_index.m3u8',
        '#EXTINF:4.0,',
        'seg-1.ts',
      ].join('\n'),
      localBaseUri: Uri.parse('http://127.0.0.1:1234/'),
    );

    expect(
      rewritten,
      contains(
        'http://127.0.0.1:1234/playlist.m3u8?url=https%3A%2F%2Fcdn.example.com%2Fhls%2Flow%2Fprog_index.m3u8',
      ),
    );
    expect(
      rewritten,
      contains(
        'http://127.0.0.1:1234/segment?url=https%3A%2F%2Fcdn.example.com%2Fhls%2Fseg-1.ts',
      ),
    );
  });

  test(
    'proxy serves rewritten playlist and caches segment after first miss',
    () async {
      final segmentUri = Uri.parse('https://cdn.example.com/hls/seg-1.ts');
      final client = _FakeProxyHttpClient({
        Uri.parse('https://cdn.example.com/hls/media.m3u8').toString():
            _textResponse('#EXTM3U\n#EXTINF:4.0,\nseg-1.ts\n'),
        segmentUri.toString(): _bytesResponse([1, 2, 3, 4]),
      });
      final cacheStore = HlsLocalCacheStore();
      final server = HlsLocalProxyServer(
        client: client,
        cacheStore: cacheStore,
      );
      addTearDown(server.stop);

      final proxyUrl = await server.proxyUrlFor(
        'https://cdn.example.com/hls/media.m3u8',
      );
      final playlist = await _readString(Uri.parse(proxyUrl));

      expect(playlist, contains('/segment?url='));

      final segmentUrl = RegExp(
        r'http://[^\n]+/segment\?url=[^\n]+',
      ).firstMatch(playlist)!.group(0)!;
      expect(await _readBytes(Uri.parse(segmentUrl)), [1, 2, 3, 4]);
      expect(await _readBytes(Uri.parse(segmentUrl)), [1, 2, 3, 4]);

      expect(client.getCount(segmentUri), 1);
      expect(cacheStore.contains(segmentUri.toString()), isTrue);
    },
  );

  test(
    'proxy serves playlist and segment prefilled by preloader cache',
    () async {
      final cacheStore = HlsLocalCacheStore()
        ..write(
          'https://cdn.example.com/hls/media.m3u8',
          utf8.encode('#EXTM3U\n#EXTINF:4.0,\nseg-1.ts\n'),
        )
        ..write('https://cdn.example.com/hls/seg-1.ts', [7, 8, 9]);
      final client = _FakeProxyHttpClient(const {});
      final server = HlsLocalProxyServer(
        client: client,
        cacheStore: cacheStore,
      );
      addTearDown(server.stop);

      final proxyUrl = await server.proxyUrlFor(
        'https://cdn.example.com/hls/media.m3u8',
      );
      final playlist = await _readString(Uri.parse(proxyUrl));
      final segmentUrl = RegExp(
        r'http://[^\n]+/segment\?url=[^\n]+',
      ).firstMatch(playlist)!.group(0)!;

      expect(await _readBytes(Uri.parse(segmentUrl)), [7, 8, 9]);
      expect(client.totalGetCount, 0);
    },
  );

  test('playlist proxy uses the streaming singleflight pathway', () async {
    final playlistUri = Uri.parse('https://cdn.example.com/hls/media.m3u8');
    final client = _StreamingFakeProxyHttpClient(
      Stream<List<int>>.fromIterable([
        utf8.encode('#EXTM3U\n#EXTINF:4.0,\nseg-1.ts\n'),
      ]),
    );
    final coordinator = HlsNetworkRequestCoordinator();
    final server = HlsLocalProxyServer(
      client: client,
      networkCoordinator: coordinator,
    );
    addTearDown(server.stop);

    final proxyUrl = await server.proxyUrlFor(playlistUri.toString());
    expect(await _readString(Uri.parse(proxyUrl)), contains('/segment?url='));
    expect(client.openCount, 1);
    expect(client.totalGetCount, 0);
  });

  test('For You suspension blocks only new remote fetches', () async {
    final playlistUri = Uri.parse('https://cdn.example.com/hls/media.m3u8');
    final gate = HlsTrafficGate()..suspendForYou();
    final client = _FakeProxyHttpClient({
      playlistUri.toString(): _textResponse('#EXTM3U\n'),
    });
    final server = HlsLocalProxyServer(client: client, trafficGate: gate);
    addTearDown(server.stop);

    final proxyUrl = await server.proxyUrlFor(
      playlistUri.toString(),
      owner: HlsTrafficOwner.forYou,
    );
    await _readBytes(Uri.parse(proxyUrl));

    expect(client.totalGetCount, 0);
  });

  test(
    'resolver falls back to remote source when proxy generation fails',
    () async {
      const remoteUrl = 'https://cdn.example.com/hls/media.m3u8';
      final resolver = HlsProxyPlaybackSourceResolver(
        config: const HlsLocalProxyConfig(enabled: true),
        proxyServer: _ThrowingProxyServer(),
      );

      expect(await resolver.resolvePlayableSource(remoteUrl), remoteUrl);
    },
  );

  test('stop releases pending fetch and prevents late cache write', () async {
    final segmentUri = Uri.parse('https://cdn.example.com/hls/seg-1.ts');
    final segmentCompleter = Completer<HlsLocalProxyResponse>();
    final client = _FakeProxyHttpClient({
      Uri.parse('https://cdn.example.com/hls/media.m3u8').toString():
          _textResponse('#EXTM3U\n#EXTINF:4.0,\nseg-1.ts\n'),
      segmentUri.toString(): segmentCompleter.future,
    });
    final cacheStore = HlsLocalCacheStore();
    final server = HlsLocalProxyServer(client: client, cacheStore: cacheStore);

    final proxyUrl = await server.proxyUrlFor(
      'https://cdn.example.com/hls/media.m3u8',
    );
    final playlist = await _readString(Uri.parse(proxyUrl));
    final segmentUrl = RegExp(
      r'http://[^\n]+/segment\?url=[^\n]+',
    ).firstMatch(playlist)!.group(0)!;

    unawaited(_readBytes(Uri.parse(segmentUrl)).catchError((_) => <int>[]));
    await Future<void>.delayed(Duration.zero);
    await server.stop();
    segmentCompleter.complete(_bytesResponse([9, 9, 9]));
    await Future<void>.delayed(Duration.zero);

    expect(client.releasePendingCount, 1);
    expect(cacheStore.contains(segmentUri.toString()), isFalse);
  });
}

HlsLocalProxyResponse _textResponse(String body) {
  return HlsLocalProxyResponse(
    statusCode: HttpStatus.ok,
    bytes: utf8.encode(body),
    contentType: 'application/vnd.apple.mpegurl',
  );
}

HlsLocalProxyResponse _bytesResponse(List<int> bytes) {
  return HlsLocalProxyResponse(
    statusCode: HttpStatus.ok,
    bytes: bytes,
    contentType: 'video/mp2t',
  );
}

Future<String> _readString(Uri uri) async {
  return utf8.decode(await _readBytes(uri));
}

Future<List<int>> _readBytes(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    return response.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
  } finally {
    client.close(force: true);
  }
}

class _FakeProxyHttpClient implements HlsLocalProxyHttpClient {
  _FakeProxyHttpClient(this.responses);

  final Map<String, FutureOr<HlsLocalProxyResponse>> responses;
  final _counts = <String, int>{};
  var releasePendingCount = 0;

  int getCount(Uri uri) => _counts[uri.toString()] ?? 0;
  int get totalGetCount => _counts.values.fold(0, (sum, count) => sum + count);

  @override
  Future<HlsLocalProxyResponse> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    final key = uri.toString();
    _counts[key] = (_counts[key] ?? 0) + 1;
    final response = responses[key];
    if (response == null) {
      return const HlsLocalProxyResponse(
        statusCode: HttpStatus.notFound,
        bytes: [],
      );
    }
    return response;
  }

  @override
  void releasePending() {
    releasePendingCount += 1;
  }
}

class _StreamingFakeProxyHttpClient extends _FakeProxyHttpClient
    implements HlsNetworkStreamingHttpClient {
  _StreamingFakeProxyHttpClient(this._stream) : super(const {});

  final Stream<List<int>> _stream;
  var openCount = 0;

  @override
  Future<HlsNetworkStreamResponse> open(
    Uri uri, {
    required Duration timeout,
  }) async {
    openCount += 1;
    return HlsNetworkStreamResponse(
      statusCode: HttpStatus.ok,
      contentType: 'application/vnd.apple.mpegurl',
      chunks: _stream,
    );
  }
}

class _ThrowingProxyServer extends HlsLocalProxyServer {
  @override
  Future<String> proxyUrlFor(
    String remoteUrl, {
    HlsTrafficOwner owner = HlsTrafficOwner.playback,
  }) {
    throw StateError('proxy unavailable');
  }
}
