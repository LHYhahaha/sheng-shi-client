import 'dart:async';

import 'package:drama_client/features/player/data/hls_network_request_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'playback joins an in-flight preload for the same signed HLS resource',
    () async {
      final coordinator = HlsNetworkRequestCoordinator();
      final completer = Completer<HlsNetworkResponse>();
      var requestCount = 0;

      final preload = coordinator.fetch(
        Uri.parse('https://cdn.example.test/a.ts?expires=100&verify=old'),
        priority: HlsRequestPriority.preload,
        request: () {
          requestCount += 1;
          return completer.future;
        },
      );
      final playback = coordinator.fetch(
        Uri.parse('https://cdn.example.test/a.ts?expires=200&verify=new'),
        priority: HlsRequestPriority.playback,
        request: () {
          requestCount += 1;
          return Future.value(
            const HlsNetworkResponse(statusCode: 200, bytes: [2]),
          );
        },
      );

      // coordinator 先登记单飞任务，再在下一微任务真正启动网络。
      expect(requestCount, 0);
      await Future<void>.delayed(Duration.zero);
      expect(requestCount, 1);
      completer.complete(const HlsNetworkResponse(statusCode: 200, bytes: [1]));
      expect((await playback).bytes, [1]);
      expect((await preload).bytes, [1]);
    },
  );

  test(
    'stream playback joins preload and receives replayed plus live chunks',
    () async {
      final coordinator = HlsNetworkRequestCoordinator();
      final upstream = StreamController<List<int>>();
      var openCount = 0;

      Future<HlsNetworkStreamResponse> open() async {
        openCount += 1;
        return HlsNetworkStreamResponse(
          statusCode: 200,
          contentType: 'video/mp2t',
          chunks: upstream.stream,
        );
      }

      final preload = coordinator.streamFetch(
        Uri.parse('https://cdn.example.test/a.ts?expires=100&verify=old'),
        priority: HlsRequestPriority.preload,
        open: open,
      );
      await Future<void>.delayed(Duration.zero);
      upstream.add([1, 2]);
      await Future<void>.delayed(Duration.zero);

      final playback = coordinator.streamFetch(
        Uri.parse('https://cdn.example.test/a.ts?expires=200&verify=new'),
        priority: HlsRequestPriority.playback,
        open: open,
      );
      upstream.add([3, 4]);
      await upstream.close();

      final bytes = <int>[];
      await for (final chunk in playback.chunks) {
        bytes.addAll(chunk);
      }
      expect(openCount, 1);
      expect(bytes, [1, 2, 3, 4]);
      expect((await preload.completed).bytes, [1, 2, 3, 4]);
    },
  );

  test(
    'large stream never gives a late subscriber a truncated replay',
    () async {
      final coordinator = HlsNetworkRequestCoordinator();
      final first = StreamController<List<int>>();
      final second = StreamController<List<int>>();
      var openCount = 0;

      Future<HlsNetworkStreamResponse> open() async {
        openCount += 1;
        return HlsNetworkStreamResponse(
          statusCode: 200,
          chunks: openCount == 1 ? first.stream : second.stream,
        );
      }

      coordinator.streamFetch(
        Uri.parse('https://cdn.example.test/large.ts'),
        priority: HlsRequestPriority.preload,
        open: open,
      );
      await Future<void>.delayed(Duration.zero);
      first.add(List<int>.filled(4 * 1024 * 1024 + 1, 1));
      await Future<void>.delayed(Duration.zero);

      final playback = coordinator.streamFetch(
        Uri.parse('https://cdn.example.test/large.ts'),
        priority: HlsRequestPriority.playback,
        open: open,
      );
      await Future<void>.delayed(Duration.zero);
      second.add([7, 8]);
      await second.close();

      final received = <int>[];
      await for (final chunk in playback.chunks) {
        received.addAll(chunk);
      }
      await first.close();
      expect(openCount, 2);
      expect(received, [7, 8]);
    },
  );
}
