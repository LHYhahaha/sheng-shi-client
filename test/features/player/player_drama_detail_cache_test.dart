import 'dart:async';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/features/player/data/dto/player_content_dto.dart';
import 'package:drama_client/features/player/data/player_drama_detail_cache.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses an in-flight and completed drama detail request', () async {
    final completer = Completer<PlayerContentDto>();
    final dataSource = _FakeRemoteDataSource(completer);
    final cache = PlayerDramaDetailCache(remoteDataSource: dataSource);

    final first = cache.get(7);
    final second = cache.get(7);
    expect(dataSource.fetchCount, 1);

    completer.complete(_contentDto(7));
    expect(await first, same(await second));
    expect((await cache.get(7)).id, 7);
    expect(dataSource.fetchCount, 1);
  });

  test('invalidate makes the next access fetch a fresh detail', () async {
    final dataSource = _FakeRemoteDataSource(
      Completer<PlayerContentDto>()..complete(_contentDto(7)),
    );
    final cache = PlayerDramaDetailCache(remoteDataSource: dataSource);

    await cache.get(7);
    cache.invalidate(7);
    await cache.get(7);

    expect(dataSource.fetchCount, 2);
  });
}

class _FakeRemoteDataSource extends PlayerRemoteDataSource {
  _FakeRemoteDataSource(this.completer) : super(apiClient: ApiClient());

  final Completer<PlayerContentDto> completer;
  int fetchCount = 0;

  @override
  Future<PlayerContentDto> fetchDramaDetail({required int dramaId}) {
    fetchCount += 1;
    if (completer.isCompleted) {
      return Future.value(_contentDto(dramaId));
    }
    return completer.future;
  }
}

PlayerContentDto _contentDto(int id) {
  return PlayerContentDto(
    id: id,
    coverUrl: '',
    title: 'Drama $id',
    summary: '',
    categoryIds: const [],
    tagIds: const [],
    trailerEpisodeNum: 0,
    pricePerEpisode: 0,
    isVipOnly: 0,
    status: 1,
    languageMask: '',
    subtitleLangs: '',
    playCount: 0,
    favoriteCount: 0,
    episodeTotal: 0,
    onlineAt: '',
    episodes: const [],
  );
}
