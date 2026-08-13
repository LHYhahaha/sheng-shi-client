import 'dart:async';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/features/player/data/dto/watch_progress_dto.dart';
import 'package:drama_client/features/player/data/player_remote_watch_progress_cache.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent readers share one watch-progress request', () async {
    final source = _FakePlayerRemoteDataSource();
    final cache = PlayerRemoteWatchProgressCache(remoteDataSource: source);

    final first = cache.get(1507);
    final second = cache.get(1507);

    expect(source.requestCount, 1);
    source.completer.complete(_progress);
    expect(await first, _progress);
    expect(await second, _progress);
  });
}

class _FakePlayerRemoteDataSource extends PlayerRemoteDataSource {
  _FakePlayerRemoteDataSource() : super(apiClient: ApiClient());

  final completer = Completer<WatchProgressDto?>();
  var requestCount = 0;

  @override
  Future<WatchProgressDto?> fetchWatchProgress({required int dramaId}) {
    requestCount += 1;
    return completer.future;
  }
}

const _progress = WatchProgressDto(
  dramaId: 1507,
  episodeId: 8510,
  episodeNo: 1,
  watchSecond: 20,
  durationSecond: 190,
  progressPercent: 10,
);
