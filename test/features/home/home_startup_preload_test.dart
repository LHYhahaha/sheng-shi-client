import 'dart:async';
import 'dart:io';

import 'package:drama_client/features/drama/data/drama_repository_provider.dart';
import 'package:drama_client/features/drama/domain/drama.dart';
import 'package:drama_client/features/drama/domain/drama_repository.dart';
import 'package:drama_client/features/home/presentation/pages/home_page.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

void main() {
  testWidgets('home feed load triggers first card startup preload', (
    tester,
  ) async {
    final sourceRepository = _FakePlaybackSourceRepository();
    await tester.pumpWidget(_buildHomeApp(sourceRepository: sourceRepository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(sourceRepository.preloadedItemIds, ['drama-a-ep-1']);
  });

  testWidgets('home category switch cancels pending startup preload', (
    tester,
  ) async {
    final preloadCompleter = Completer<PlaybackPreloadState>();
    final preloadManager = _FakePreloadManager();
    final sourceRepository = _FakePlaybackSourceRepository(
      preloadCompleter: preloadCompleter,
    );
    await tester.pumpWidget(
      _buildHomeApp(
        sourceRepository: sourceRepository,
        preloadManager: preloadManager,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('New'));
    await tester.pump();

    expect(preloadManager.releasePendingCount, greaterThanOrEqualTo(1));
    preloadCompleter.complete(_successPreloadState());
  });

  testWidgets('home dispose cancels pending startup preload', (tester) async {
    final preloadCompleter = Completer<PlaybackPreloadState>();
    final preloadManager = _FakePreloadManager();
    final sourceRepository = _FakePlaybackSourceRepository(
      preloadCompleter: preloadCompleter,
    );
    await tester.pumpWidget(
      _buildHomeApp(
        sourceRepository: sourceRepository,
        preloadManager: preloadManager,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(preloadManager.releasePendingCount, greaterThanOrEqualTo(1));
    preloadCompleter.complete(_successPreloadState());
  });

  test('home page does not depend on media sessions or media_kit', () {
    final source = File(
      'lib/features/home/presentation/pages/home_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('media_kit')));
    expect(source, isNot(contains('PlayerPlaybackSession')));
    expect(source, isNot(contains('VideoController')));
  });
}

Widget _buildHomeApp({
  _FakePlaybackSourceRepository? sourceRepository,
  _FakePreloadManager? preloadManager,
}) {
  final manager = preloadManager ?? _FakePreloadManager();
  return ProviderScope(
    overrides: [
      dramaRepositoryProvider.overrideWithValue(_FakeDramaRepository()),
      playerFeedRepositoryProvider.overrideWithValue(
        _FakePlayerFeedRepository(),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(manager),
      playerPlaybackSourceRepositoryProvider.overrideWithValue(
        sourceRepository ?? _FakePlaybackSourceRepository(),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(),
    ),
  );
}

final _dramas = [
  const Drama(
    id: 'drama-a',
    title: 'Drama A',
    coverAssetPath: 'assets/images/home/drama_cover_figma.png',
    viewCountLabel: '1M',
    episodeCount: 10,
    categoryId: 'popular',
    tags: ['Rebirth'],
    coverAspectRatio: 171 / 226,
  ),
];

final _content = PlayerContent(
  id: 'drama-a',
  title: 'Drama A',
  playTitle: 'Drama A',
  synopsis: 'Synopsis',
  viewCountLabel: '1M',
  likeCountLabel: '1K',
  backgroundAssetPath: 'assets/images/player/player_background.png',
  posterAssetPath: 'assets/images/player/recommend_1.png',
  episodes: const [
    PlayerEpisode(id: 'ep-1', number: 1, isLocked: false, videoUrl: _videoUrl),
  ],
  recommendations: const [],
);

final _item = PlayerFeedItem(
  id: 'drama-a-ep-1',
  mode: PlayerFeedMode.singleDrama,
  content: _content,
  episode: _content.episodes.first,
);

PlaybackPreloadState _successPreloadState() {
  return PlaybackPreloadState(
    itemId: _item.id,
    sourceUrl: _videoUrl,
    status: PlaybackPreloadStatus.success,
    startedAt: DateTime.now(),
    completedAt: DateTime.now(),
  );
}

class _FakeDramaRepository implements DramaRepository {
  @override
  Future<List<DramaCategory>> listHomeCategories() async {
    return const [
      DramaCategory(id: 'popular', title: 'Popular'),
      DramaCategory(id: 'new', title: 'New'),
    ];
  }

  @override
  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) async {
    return DramaFeedPage(items: _dramas, nextPageToken: null);
  }
}

class _FakePlayerFeedRepository implements PlayerFeedRepository {
  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async => [_item];

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    return [_item];
  }
}

class _FakePlaybackSourceRepository implements PlayerPlaybackSourceRepository {
  _FakePlaybackSourceRepository({this.preloadCompleter});

  final Completer<PlaybackPreloadState>? preloadCompleter;
  final preloadedItemIds = <String>[];

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: item.episode.videoSource!,
      playableSource: item.episode.videoSource!,
      cacheKey: item.id,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      codecHint: 'hls',
      status: PlaybackSourceStatus.resolved,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(PlayerFeedItem item) async {
    if (preloadCompleter != null) {
      return preloadCompleter!.future;
    }
    preloadedItemIds.add(item.id);
    return _successPreloadState();
  }
}

class _FakePreloadManager implements PlayerPlaybackPreloadManager {
  var releasePendingCount = 0;

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  }) async {
    return _successPreloadState();
  }

  @override
  Future<void> releasePending() async {
    releasePendingCount += 1;
  }
}
