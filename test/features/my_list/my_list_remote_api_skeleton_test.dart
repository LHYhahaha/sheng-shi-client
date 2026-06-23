import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/features/my_list/data/dto/favorite_item_dto.dart';
import 'package:drama_client/features/my_list/data/dto/play_history_item_dto.dart';
import 'package:drama_client/features/my_list/data/mapper/my_list_mapper.dart';
import 'package:drama_client/features/my_list/data/mock_my_list_repository.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:drama_client/shared/media/media_resource.dart';

void main() {
  const mapper = MyListMapper();

  test('favorite dto maps to MyListItem with dramaId', () {
    final item = mapper.mapFavorite(_favoriteDto);

    expect(item.dramaId, 1);
    expect(item.title, 'Remote Favorite');
    expect(item.introduction, 'Favorite intro');
    expect(item.currentEpisode, 6);
    expect(item.episodeCount, 52);
    expect(item.coverAssetPath, MyListItem.fallbackCoverAssetPath);
    expect(item.coverResource.type, MediaResourceType.network);
    expect(item.coverResource.value, 'https://cdn.example.com/fav.jpg');
    expect(item.coverResource.aspectRatio, 0.72);
  });

  test('play history dto maps to MyListItem with dramaId', () {
    final item = mapper.mapPlayHistory(_historyDto);

    expect(item.dramaId, 1);
    expect(item.title, 'EP. 2');
    expect(item.introduction, '');
    expect(item.currentEpisode, 2);
    expect(item.episodeCount, 0);
    expect(item.coverAssetPath, MyListItem.fallbackCoverAssetPath);
    expect(item.coverResource.type, MediaResourceType.network);
  });

  test('missing cover url falls back to asset resource', () {
    final item = mapper.mapFavorite(
      const FavoriteItemDto(
        dramaId: 1,
        title: 'No Cover',
        description: null,
        coverUrl: null,
        coverAspectRatio: null,
        episodeTotal: 10,
        latestEpisodeNumber: null,
        tags: [],
        badges: [],
        createdAt: null,
        followSource: 0,
        lastEpisodeId: 0,
        lastEpisodeNo: 0,
        lastWatchAt: null,
        status: 0,
        updatedAt: null,
      ),
    );

    expect(item.coverResource.type, MediaResourceType.asset);
    expect(item.coverResource.value, MyListItem.fallbackCoverAssetPath);
  });

  test('provider defaults to mock repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(myListRepositoryProvider),
      isA<MockMyListRepository>(),
    );
  });
}

const _favoriteDto = FavoriteItemDto(
  dramaId: 1,
  title: 'Remote Favorite',
  description: 'Favorite intro',
  coverUrl: 'https://cdn.example.com/fav.jpg',
  coverAspectRatio: 0.72,
  episodeTotal: 52,
  latestEpisodeNumber: 6,
  tags: ['Rebirth'],
  badges: ['Hot'],
  createdAt: null,
  followSource: 0,
  lastEpisodeId: 0,
  lastEpisodeNo: 0,
  lastWatchAt: null,
  status: 0,
  updatedAt: null,
);

const _historyDto = PlayHistoryItemDto(
  dramaId: 1,
  episodeId: 2,
  episodeNo: 2,
  watchSecond: 12,
  durationSecond: 60,
  watchCount: 1,
  progressPercent: 20,
  lastWatchAt: null,
);
