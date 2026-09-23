import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/presentation/widgets/player_detail_sheet.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/shared/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'detail sheet opens compact with a unified scrollable for Episodes',
    (tester) async {
      await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('1-2'), findsOneWidget);
    },
  );

  testWidgets('dragging the cover row expands the detail sheet', (
    tester,
  ) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);
    final sheet = find.byKey(const ValueKey('player_detail_sheet_surface'));
    final compactHeight = tester.getSize(sheet).height;

    await _expandDetailSheetFromCover(tester);

    final expandedHeight = tester.getSize(sheet).height;
    expect(expandedHeight, greaterThan(compactHeight));
  });

  testWidgets('close dismisses detail sheet', (tester) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_close')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerDetailSheet), findsNothing);
  });

  testWidgets('More opens Synopsis tab and Episodes opens Episodes tab', (
    tester,
  ) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.synopsis);
    expect(find.text('More Like This'), findsOneWidget);
    expect(find.text('1-30'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_close')));
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);
    expect(find.text('1-2'), findsOneWidget);
    expect(find.text('More Like This'), findsNothing);
  });

  testWidgets('selecting episode closes detail sheet', (tester) async {
    var selectedEpisodeNumber = 0;

    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      currentEpisode: 2,
      onEpisodeSelected: (episode) {
        selectedEpisodeNumber = episode.number;
      },
    );

    await _expandDetailSheetFromCover(tester);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(selectedEpisodeNumber, 1);
    expect(find.byType(PlayerDetailSheet), findsNothing);
  });

  testWidgets('episode ranges navigate the full list and track its scroll', (
    tester,
  ) async {
    final episodes = List.generate(
      60,
      (index) => PlayerEpisode(
        id: 'ep-${index + 1}',
        number: index + 1,
        isLocked: false,
        unlockType: EpisodeUnlockType.free,
        videoUrl: 'https://example.com/${index + 1}.m3u8',
      ),
    );
    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      currentEpisode: 2,
      episodes: episodes,
    );
    await _expandDetailSheetFromCover(tester);

    // The initial range no longer filters the list to its first 30 episodes.
    expect(find.text('31'), findsOneWidget);

    await tester.tap(find.text('31-60'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('31')).dy, greaterThan(0));
    expect(tester.widget<Text>(find.text('31-60')).style?.color, Colors.white);

    await tester.drag(find.byType(GridView), const Offset(0, 1000));
    await tester.pumpAndSettle();

    // Scrolling back to the first section also restores its active range.
    expect(tester.widget<Text>(find.text('1-30')).style?.color, Colors.white);
    await tester.tap(find.text('1-30'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('1')).dy, greaterThan(0));
    expect(tester.widget<Text>(find.text('1-30')).style?.color, Colors.white);
  });

  testWidgets('last episode range stops with its first row at the top', (
    tester,
  ) async {
    final episodes = List.generate(
      70,
      (index) => PlayerEpisode(
        id: 'ep-${index + 1}',
        number: index + 1,
        isLocked: false,
        unlockType: EpisodeUnlockType.free,
        videoUrl: 'https://example.com/${index + 1}.m3u8',
      ),
    );
    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      currentEpisode: 2,
      episodes: episodes,
    );

    await _expandDetailSheetFromCover(tester);

    await tester.tap(find.text('61-70'));
    await tester.pumpAndSettle();
    final firstRowTop = tester.getTopLeft(find.text('61')).dy;

    // The trailing row (66-70) cannot be scrolled above the range's first row.
    await tester.dragFrom(const Offset(400, 400), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('61')).dy, closeTo(firstRowTop, 1));
    expect(tester.getTopLeft(find.text('66')).dy, greaterThan(firstRowTop));
    expect(tester.widget<Text>(find.text('61-70')).style?.color, Colors.white);
  });

  testWidgets('duplicate episode numbers select only the current episode id', (
    tester,
  ) async {
    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      currentEpisode: 1,
      currentEpisodeId: 'ep-duplicate-b',
      episodes: const [
        PlayerEpisode(
          id: 'ep-duplicate-a',
          number: 1,
          isLocked: false,
          unlockType: EpisodeUnlockType.free,
          videoUrl: 'https://example.com/a.m3u8',
        ),
        PlayerEpisode(
          id: 'ep-duplicate-b',
          number: 1,
          isLocked: false,
          unlockType: EpisodeUnlockType.free,
          videoUrl: 'https://example.com/b.m3u8',
        ),
        PlayerEpisode(
          id: 'ep-2',
          number: 2,
          isLocked: false,
          unlockType: EpisodeUnlockType.free,
          videoUrl: 'https://example.com/2.m3u8',
        ),
      ],
    );

    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('top chrome is outside scrollable content', (tester) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.synopsis);

    final scrollView = find.descendant(
      of: find.byType(PlayerDetailSheet),
      matching: find.byType(CustomScrollView),
    );
    final topChrome = find.byKey(
      const ValueKey('player_detail_sheet_top_chrome'),
    );

    expect(scrollView, findsOneWidget);
    expect(topChrome, findsOneWidget);
    expect(find.descendant(of: scrollView, matching: topChrome), findsNothing);
  });

  testWidgets(
    'recommendation tab shows dedicated empty state when API is empty',
    (tester) async {
      await _openDetailSheet(
        tester,
        initialTab: PlayerDetailTab.synopsis,
        recommendationsFuture: Future<List<PlayerRecommendation>>.value(
          const [],
        ),
      );

      expect(find.text('No recommendations yet'), findsOneWidget);
      expect(find.text('No dramas yet'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppEmptyState),
          matching: find.byType(SvgPicture),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('wide iPhone layout does not overflow the detail header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      useScreenUtil: true,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('detail header grows with the segmented control text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openDetailSheet(
      tester,
      initialTab: PlayerDetailTab.episodes,
      textScaler: const TextScaler.linear(2),
      useScreenUtil: true,
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> _expandDetailSheetFromCover(WidgetTester tester) async {
  await tester.drag(find.text('Reborn: The Cure'), const Offset(0, -500));
  await tester.pumpAndSettle();
}

Future<void> _openDetailSheet(
  WidgetTester tester, {
  required PlayerDetailTab initialTab,
  int currentEpisode = 1,
  String? currentEpisodeId,
  ValueChanged<PlayerEpisode>? onEpisodeSelected,
  List<PlayerEpisode>? episodes,
  List<PlayerRecommendation> recommendations = const [],
  Future<List<PlayerRecommendation>>? recommendationsFuture,
  TextScaler? textScaler,
  bool useScreenUtil = false,
}) async {
  final detailEpisodes =
      episodes ??
      const [
        PlayerEpisode(
          id: 'ep-1',
          number: 1,
          isLocked: false,
          unlockType: EpisodeUnlockType.free,
          videoUrl: 'https://example.com/1.m3u8',
        ),
        PlayerEpisode(
          id: 'ep-2',
          number: 2,
          isLocked: true,
          unlockType: EpisodeUnlockType.coins,
          requiredCoins: 60,
          videoUrl: 'https://example.com/2.m3u8',
        ),
      ];
  final content = PlayerContent(
    id: 'drama-a',
    title: 'Reborn: The Cure',
    playTitle: 'A Life That Shines Again',
    synopsis:
        'Emily Carter is a renowned surgeon and the heir to the immensely wealthy Carter family.',
    viewCountLabel: '16.6M Views',
    likeCountLabel: '43.2K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: detailEpisodes,
    recommendations: recommendations,
    episodeTotal: detailEpisodes.length,
  );

  final app = MaterialApp(
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (sheetContext) {
                    return PlayerDetailSheet(
                      content: content,
                      initialTab: initialTab,
                      currentEpisode: currentEpisode,
                      currentEpisodeId: currentEpisodeId,
                      recommendationsFuture: recommendationsFuture,
                      onEpisodeSelected: (episode) {
                        if (onEpisodeSelected != null) {
                          onEpisodeSelected(episode);
                        }
                        Navigator.of(sheetContext).pop();
                      },
                      onRecommendationSelected: (recommendation, position) {},
                    );
                  },
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        );
      },
    ),
  );
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: useScreenUtil ? const Size(375, 812) : const Size(800, 600),
      builder: (_, child) => child!,
      child: app,
    ),
  );

  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}
