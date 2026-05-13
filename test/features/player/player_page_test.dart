import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/presentation/pages/player_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('feed empty shows empty state', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.empty()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('No episodes available yet.'), findsOneWidget);
  });

  testWidgets('feed error shows retry and recovers', (tester) async {
    final repository = _FakePlayerFeedRepository.errorThenData();

    await tester.pumpWidget(_buildPlayerApp(repository: repository));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Player failed to load.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('A Life That Shines Again >'), findsOneWidget);
    expect(find.text('Player failed to load.'), findsNothing);
  });

  testWidgets('unavailable episode shows unavailable state', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '3',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('EP.03'), findsOneWidget);
    expect(find.text('This episode is unavailable.'), findsOneWidget);
    expect(find.text('Unlock Now'), findsNothing);
  });

  testWidgets('episodes sheet can select locked episode and show paywall', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.normal()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets('back closes paywall before leaving player', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.normal()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Now'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Unlock Now'), findsNothing);
    expect(find.text('EP.02'), findsOneWidget);
    expect(find.text('A Life That Shines Again >'), findsOneWidget);
  });

  testWidgets('share and more sheets do not change current feed index', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('EP.02'), findsOneWidget);

    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    expect(find.text('Facebook'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('EP.02'), findsOneWidget);

    await tester.tap(find.text('More').first);
    await tester.pumpAndSettle();
    expect(find.text('Synopsis'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
  });
}

Widget _buildPlayerApp({
  required PlayerFeedRepository repository,
  String initialLocation = '/player/drama-a/1',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: RoutePaths.player,
        builder: (context, state) {
          return PlayerPage(
            dramaId: state.pathParameters['dramaId']!,
            episodeId: state.pathParameters['episodeId']!,
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [playerFeedRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _FakePlayerFeedRepository implements PlayerFeedRepository {
  _FakePlayerFeedRepository._({
    required this.items,
    this.shouldReturnEmpty = false,
    this.shouldThrowOnce = false,
  });

  factory _FakePlayerFeedRepository.normal() {
    return _FakePlayerFeedRepository._(items: _items(lockedEpisode2: true));
  }

  factory _FakePlayerFeedRepository.unlocked() {
    return _FakePlayerFeedRepository._(items: _items());
  }

  factory _FakePlayerFeedRepository.empty() {
    return _FakePlayerFeedRepository._(
      items: const [],
      shouldReturnEmpty: true,
    );
  }

  factory _FakePlayerFeedRepository.errorThenData() {
    return _FakePlayerFeedRepository._(items: _items(), shouldThrowOnce: true);
  }

  final List<PlayerFeedItem> items;
  final bool shouldReturnEmpty;
  bool shouldThrowOnce;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    if (shouldThrowOnce) {
      shouldThrowOnce = false;
      throw StateError('failed');
    }
    if (shouldReturnEmpty) {
      return const [];
    }

    final requestedNumber = int.tryParse(episodeId);
    final index = items.indexWhere((item) {
      return item.episode.id == episodeId ||
          item.episode.number == requestedNumber;
    });
    if (index <= 0) {
      return items;
    }
    return [...items.sublist(index), ...items.sublist(0, index)];
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    return items
        .map(
          (item) => PlayerFeedItem(
            id: 'for-you-${item.id}',
            mode: PlayerFeedMode.forYou,
            content: item.content,
            episode: item.episode,
          ),
        )
        .toList(growable: false);
  }
}

List<PlayerFeedItem> _items({bool lockedEpisode2 = false}) {
  final content = _content([
    const PlayerEpisode(id: 'ep-1', number: 1, isLocked: false),
    PlayerEpisode(id: 'ep-2', number: 2, isLocked: lockedEpisode2),
    const PlayerEpisode(
      id: 'ep-3',
      number: 3,
      isLocked: false,
      isAvailable: false,
    ),
  ]);

  return content.episodes
      .map(
        (episode) => PlayerFeedItem(
          id: '${content.id}-${episode.id}',
          mode: PlayerFeedMode.singleDrama,
          content: content,
          episode: episode,
        ),
      )
      .toList(growable: false);
}

PlayerContent _content(List<PlayerEpisode> episodes) {
  return PlayerContent(
    id: 'drama-a',
    title: 'Reborn: The Cure',
    playTitle: 'A Life That Shines Again',
    synopsis:
        'Emily Carter is a renowned surgeon and the heir to the immensely wealthy Carter family.',
    viewCountLabel: '16.6M Views',
    likeCountLabel: '43.2K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: episodes,
    recommendations: const [],
  );
}
