import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/my_list/data/dto/favorite_item_dto.dart';
import 'package:drama_client/features/my_list/data/dto/favorite_mutation_dto.dart';
import 'package:drama_client/features/my_list/data/dto/my_list_page_dto.dart';
import 'package:drama_client/features/my_list/data/dto/play_history_item_dto.dart';
import 'package:drama_client/features/my_list/data/mapper/my_list_mapper.dart';
import 'package:drama_client/features/my_list/data/mock_my_list_repository.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/my_list/data/remote/my_list_remote_data_source.dart';
import 'package:drama_client/features/my_list/data/remote_my_list_repository.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:drama_client/shared/media/media_resource.dart';

void main() {
  const mapper = MyListMapper();

  test('favorite dto parses full contract fields', () {
    final dto = FavoriteItemDto.fromJson(const {
      'favoriteId': 'favorite-1',
      'dramaId': 'drama-1',
      'title': 'Remote Favorite',
      'introduction': 'Intro from server',
      'coverUrl': 'https://cdn.example.com/fav.jpg',
      'coverAspectRatio': 0.72,
      'totalEpisodes': 52,
      'latestEpisodeNumber': 6,
      'tags': ['Rebirth'],
      'badges': ['Hot'],
      'createdAt': '2026-05-15T01:00:00Z',
    });

    expect(dto.favoriteId, 'favorite-1');
    expect(dto.dramaId, 'drama-1');
    expect(dto.description, 'Intro from server');
    expect(dto.coverAspectRatio, 0.72);
    expect(dto.totalEpisodes, 52);
    expect(dto.latestEpisodeNumber, 6);
    expect(dto.tags, ['Rebirth']);
    expect(dto.badges, ['Hot']);
    expect(dto.createdAt, DateTime.parse('2026-05-15T01:00:00Z'));
  });

  test('play history dto parses full progress contract fields', () {
    final dto = PlayHistoryItemDto.fromJson(const {
      'historyId': 'history-1',
      'dramaId': 'drama-1',
      'episodeId': 'ep-2',
      'title': 'Continue Watching',
      'description': 'History intro',
      'coverUrl': 'https://cdn.example.com/history.jpg',
      'coverAspectRatio': 0.72,
      'episodeNumber': 2,
      'totalEpisodes': 52,
      'progressMs': 12000,
      'durationMs': 60000,
      'progressPercent': 0.2,
      'updatedAt': '2026-05-15T02:00:00Z',
    });

    expect(dto.historyId, 'history-1');
    expect(dto.dramaId, 'drama-1');
    expect(dto.episodeId, 'ep-2');
    expect(dto.description, 'History intro');
    expect(dto.progressMs, 12000);
    expect(dto.durationMs, 60000);
    expect(dto.progressPercent, 0.2);
    expect(dto.updatedAt, DateTime.parse('2026-05-15T02:00:00Z'));
  });

  test('favorite dto maps to MyListItem with network cover resource', () {
    final item = mapper.mapFavorite(_favoriteDto);

    expect(item.id, 'drama-1');
    expect(item.title, 'Remote Favorite');
    expect(item.introduction, 'Favorite intro');
    expect(item.currentEpisode, 6);
    expect(item.episodeCount, 52);
    expect(item.coverAssetPath, MyListItem.fallbackCoverAssetPath);
    expect(item.coverResource.type, MediaResourceType.network);
    expect(item.coverResource.value, 'https://cdn.example.com/fav.jpg');
    expect(item.coverResource.aspectRatio, 0.72);
  });

  test('favorite stable id prefers dramaId for delete semantics', () {
    final item = mapper.mapFavorite(
      const FavoriteItemDto(
        favoriteId: 'favorite-server-row-id',
        dramaId: 'drama-delete-id',
        title: 'Favorite',
        description: null,
        coverUrl: null,
        coverAspectRatio: null,
        totalEpisodes: 12,
        latestEpisodeNumber: null,
        tags: [],
        badges: [],
        createdAt: null,
      ),
    );

    expect(item.id, 'drama-delete-id');
  });

  test('play history dto maps stable id and progress contract', () {
    final dto = PlayHistoryItemDto.fromJson(const {
      'dramaId': 'drama-1',
      'episodeId': 'ep-2',
      'title': 'Continue Watching',
      'introduction': 'History intro',
      'coverUrl': 'https://cdn.example.com/history.jpg',
      'episodeNumber': 2,
      'totalEpisodes': 52,
      'progressMs': 12000,
      'durationMs': 60000,
      'progressPercent': 0.2,
    });
    final item = mapper.mapPlayHistory(dto);

    expect(dto.progressMs, 12000);
    expect(dto.durationMs, 60000);
    expect(dto.progressPercent, 0.2);
    expect(item.id, 'history:drama-1:ep-2');
    expect(item.currentEpisode, 2);
    expect(item.coverResource.isNetwork, isTrue);
  });

  test('play history stable id prefers historyId for delete semantics', () {
    final withHistoryId = mapper.mapPlayHistory(_historyDto);
    final withoutHistoryId = mapper.mapPlayHistory(
      const PlayHistoryItemDto(
        historyId: null,
        dramaId: 'drama-1',
        episodeId: 'ep-2',
        title: 'History',
        description: null,
        coverUrl: null,
        coverAspectRatio: null,
        episodeNumber: 2,
        totalEpisodes: 52,
        progressMs: null,
        durationMs: null,
        progressPercent: null,
        updatedAt: null,
      ),
    );

    expect(withHistoryId.id, 'history-1');
    expect(withoutHistoryId.id, 'history:drama-1:ep-2');
  });

  test('missing cover url falls back to asset resource', () {
    final item = mapper.mapFavorite(
      const FavoriteItemDto(
        favoriteId: null,
        dramaId: 'drama-2',
        title: 'No Cover',
        description: null,
        coverUrl: null,
        coverAspectRatio: null,
        totalEpisodes: 10,
        latestEpisodeNumber: null,
        tags: [],
        badges: [],
        createdAt: null,
      ),
    );

    expect(item.coverResource.type, MediaResourceType.asset);
    expect(item.coverResource.value, MyListItem.fallbackCoverAssetPath);
  });

  test('page dto parses favorites and play history pages', () {
    final favorites = MyListPageDto.favoritesFromJson({
      'items': [
        {
          'favoriteId': 'favorite-1',
          'dramaId': 'drama-1',
          'title': 'Favorite',
          'createdAt': '2026-05-15T01:00:00Z',
        },
      ],
      'nextPageToken': 'next-fav',
    });
    final history = MyListPageDto.playHistoryFromJson({
      'items': [
        {
          'historyId': 'history-1',
          'dramaId': 'drama-1',
          'episodeId': 'ep-1',
          'title': 'History',
          'episodeNumber': 1,
        },
      ],
      'nextPageToken': 'next-history',
    });

    expect(favorites.items.single.favoriteId, 'favorite-1');
    expect(favorites.nextPageToken, 'next-fav');
    expect(history.items.single.historyId, 'history-1');
    expect(history.nextPageToken, 'next-history');
  });

  test('remote repository loads favorites and play history', () async {
    final repository = RemoteMyListRepository(
      remoteDataSource: _FakeMyListRemoteDataSource(
        favorites: [_favoriteDto],
        playHistory: [_historyDto],
      ),
    );

    final favorites = await repository.fetchItems(tab: MyListTab.collection);
    final history = await repository.fetchItems(tab: MyListTab.play);

    expect(favorites.single.id, 'drama-1');
    expect(history.single.id, 'history-1');
  });

  test('remote repository sends delete mutations', () async {
    final remote = _FakeMyListRemoteDataSource();
    final repository = RemoteMyListRepository(remoteDataSource: remote);

    await repository.deleteFavorite(dramaId: 'drama-1');
    await repository.deleteFavorites(dramaIds: ['drama-1', 'drama-2']);
    await repository.deletePlayHistory(historyId: 'history-1');

    expect(remote.deletedFavoriteIds, ['drama-1']);
    expect(remote.batchDeletedFavoriteIds.single, ['drama-1', 'drama-2']);
    expect(remote.deletedHistoryIds, ['history-1']);
  });

  test('remote datasource uses required auth for user list APIs', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {
        'code': 0,
        'message': 'success',
        'data': {'items': [], 'nextPageToken': null},
      },
    );
    final dataSource = MyListRemoteDataSource(
      apiClient: ApiClient(
        dio: Dio()..httpClientAdapter = adapter,
        requestContext: const ApiRequestContext(
          deviceId: 'device-1',
          lang: 'en',
          platform: 'android',
          appVersion: '1.0.0',
          accessToken: 'token-1',
        ),
      ),
    );

    await dataSource.listFavorites();

    expect(adapter.lastOptions!.headers['Authorization'], 'Bearer token-1');
  });

  test(
    'remote datasource uses required auth and correct mutation contract',
    () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: {
          'code': 0,
          'message': 'success',
          'data': {'success': true, 'operationId': 'op-1'},
        },
      );
      final dataSource = MyListRemoteDataSource(
        apiClient: ApiClient(
          dio: Dio()..httpClientAdapter = adapter,
          requestContext: const ApiRequestContext(
            deviceId: 'device-1',
            lang: 'en',
            platform: 'android',
            appVersion: '1.0.0',
            accessToken: 'token-1',
          ),
        ),
      );

      await dataSource.deleteFavorite(dramaId: 'drama-1');
      await dataSource.deleteFavorites(dramaIds: ['drama-1', 'drama-2']);
      await dataSource.deletePlayHistory(historyId: 'history-1');

      expect(adapter.requests[0].path, '/me/favorites/drama-1');
      expect(adapter.requests[0].headers['Authorization'], 'Bearer token-1');
      expect(adapter.requests[1].path, '/me/favorites:batch');
      expect(adapter.requests[1].data, {
        'dramaIds': ['drama-1', 'drama-2'],
      });
      expect(adapter.requests[1].headers['Authorization'], 'Bearer token-1');
      expect(adapter.requests[2].path, '/me/play-history/history-1');
      expect(adapter.requests[2].headers['Authorization'], 'Bearer token-1');
    },
  );

  test('remote datasource keeps business code on envelope failure', () {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 2001, 'message': 'login required', 'data': null},
    );
    final dataSource = MyListRemoteDataSource(
      apiClient: ApiClient(
        dio: Dio()..httpClientAdapter = adapter,
        requestContext: const ApiRequestContext(
          deviceId: 'device-1',
          lang: 'en',
          platform: 'android',
          appVersion: '1.0.0',
          accessToken: 'token-1',
        ),
      ),
    );

    final future = dataSource.listPlayHistory();

    expect(
      future,
      throwsA(
        isA<ApiException>()
            .having((error) => error.businessCode, 'businessCode', 2001)
            .having((error) => error.message, 'message', 'login required'),
      ),
    );
  });

  test('provider defaults to mock repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(myListRepositoryProvider),
      isA<MockMyListRepository>(),
    );
  });

  test('remote switch provider enables remote repository skeleton', () {
    final container = ProviderContainer(
      overrides: [useRemoteMyListApiProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(myListRepositoryProvider),
      isA<RemoteMyListRepository>(),
    );
  });
}

const _favoriteDto = FavoriteItemDto(
  favoriteId: 'favorite-1',
  dramaId: 'drama-1',
  title: 'Remote Favorite',
  description: 'Favorite intro',
  coverUrl: 'https://cdn.example.com/fav.jpg',
  coverAspectRatio: 0.72,
  totalEpisodes: 52,
  latestEpisodeNumber: 6,
  tags: ['Rebirth'],
  badges: ['Hot'],
  createdAt: null,
);

const _historyDto = PlayHistoryItemDto(
  historyId: 'history-1',
  dramaId: 'drama-1',
  episodeId: 'ep-2',
  title: 'Remote History',
  description: 'History intro',
  coverUrl: 'https://cdn.example.com/history.jpg',
  coverAspectRatio: 0.72,
  episodeNumber: 2,
  totalEpisodes: 52,
  progressMs: 12000,
  durationMs: 60000,
  progressPercent: 0.2,
  updatedAt: null,
);

class _FakeMyListRemoteDataSource implements MyListRemoteDataSource {
  _FakeMyListRemoteDataSource({
    this.favorites = const [],
    this.playHistory = const [],
  });

  final List<FavoriteItemDto> favorites;
  final List<PlayHistoryItemDto> playHistory;
  final deletedFavoriteIds = <String>[];
  final batchDeletedFavoriteIds = <List<String>>[];
  final deletedHistoryIds = <String>[];

  @override
  Future<MyListPageDto<FavoriteItemDto>> listFavorites({
    String? pageToken,
  }) async {
    return MyListPageDto(items: favorites, nextPageToken: null);
  }

  @override
  Future<FavoriteMutationDto> addFavorite({required String dramaId}) async {
    return const FavoriteMutationDto(success: true);
  }

  @override
  Future<FavoriteMutationDto> deleteFavorite({required String dramaId}) async {
    deletedFavoriteIds.add(dramaId);
    return const FavoriteMutationDto(success: true);
  }

  @override
  Future<FavoriteMutationDto> deleteFavorites({
    required List<String> dramaIds,
  }) async {
    batchDeletedFavoriteIds.add(List<String>.unmodifiable(dramaIds));
    return const FavoriteMutationDto(success: true);
  }

  @override
  Future<MyListPageDto<PlayHistoryItemDto>> listPlayHistory({
    String? pageToken,
  }) async {
    return MyListPageDto(items: playHistory, nextPageToken: null);
  }

  @override
  Future<FavoriteMutationDto> deletePlayHistory({
    required String historyId,
  }) async {
    deletedHistoryIds.add(historyId);
    return const FavoriteMutationDto(success: true);
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;
  final requests = <RequestOptions>[];
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
