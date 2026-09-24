import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_provider.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/player/application/player_entry_preload_coordinator.dart';
import 'package:drama_client/features/search/data/search_repository_provider.dart';
import 'package:drama_client/features/search/domain/search_rankings.dart';
import 'package:drama_client/features/search/domain/search_repository.dart';
import 'package:drama_client/features/search/domain/search_results.dart';
import 'package:drama_client/features/search/presentation/search_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping a suggested drama opens its player route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoutePaths.search,
      routes: [
        GoRoute(
          path: RoutePaths.search,
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: RoutePaths.player,
          builder: (context, state) =>
              Text('Player ${state.pathParameters['dramaId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_SearchRepository()),
          analyticsServiceProvider.overrideWithValue(_analyticsService()),
          playerEntryPreloadCoordinatorProvider.overrideWith(
            _TestPlayerEntryPreloadCoordinator.new,
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hero');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.text('Hero Drama'));
    await tester.pumpAndSettle();

    expect(find.text('Player drama-hero'), findsOneWidget);
  });
}

AnalyticsService _analyticsService() => AnalyticsService(
  contextReader: () => const AnalyticsContext(
    platform: 'test',
    appVersion: 'test',
    language: 'en',
  ),
  eventSink: AnalyticsInMemoryEventSink(),
);

class _TestPlayerEntryPreloadCoordinator extends PlayerEntryPreloadCoordinator {
  @override
  PlayerEntryPreloadState build() => const PlayerEntryPreloadState();

  @override
  void preparePlayerRoute({
    required String dramaId,
    required String episodeId,
    String? trigger,
    PlayerEntryResumeHint? resumeHint,
  }) {
    state = PlayerEntryPreloadState(
      dramaId: dramaId,
      preferredEpisodeId: episodeId,
      trigger: trigger,
      isUserIntent: true,
      requestedAt: DateTime.now(),
      resumeHint: resumeHint,
    );
  }
}

class _SearchRepository implements SearchRepository {
  @override
  Future<SearchRanking> getHotPlays({bool? isRecommend}) async =>
      const SearchRanking(limit: 0, dramas: []);

  @override
  Future<SearchRanking> getHotSearches() async =>
      const SearchRanking(limit: 0, dramas: []);

  @override
  Future<SearchRanking> getNewOnline() async =>
      const SearchRanking(limit: 0, dramas: []);

  @override
  Future<SearchRankings> getRankings() async => SearchRankings(
    hotSearches: await getHotSearches(),
    hotPlays: await getHotPlays(),
    newOnline: await getNewOnline(),
  );

  @override
  Future<void> reportSearchResultClick({required String dramaId}) async {}

  @override
  Future<SearchResults> search({
    required String keyword,
    String page = '1',
    String pageSize = '20',
    SearchSortType? sortType,
  }) async => SearchResults(
    keyword: keyword,
    page: 1,
    pageSize: 20,
    total: 1,
    dramas: const [
      SearchResultDrama(
        id: 'drama-hero',
        sort: 1,
        coverUrl: '',
        title: 'Hero Drama',
        summary: '',
        tags: [],
        categories: [],
        playCount: 0,
        trailerEpisodeNum: 1,
        isVipOnly: false,
        status: 1,
        episodeTotal: 1,
      ),
    ],
    guessLike: const [],
  );
}
