import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/presentation/widgets/player_detail_sheet.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail sheet opens compact with expand control for Episodes', (
    tester,
  ) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);

    expect(
      find.byKey(const ValueKey('player_detail_sheet_expand')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_detail_sheet_shrink')),
      findsNothing,
    );
    expect(find.text('1-30'), findsOneWidget);
  });

  testWidgets('expand and shrink toggle detail sheet mode controls', (
    tester,
  ) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.episodes);

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_expand')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_detail_sheet_shrink')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_detail_sheet_expand')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_shrink')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_detail_sheet_expand')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_detail_sheet_shrink')),
      findsNothing,
    );
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
    expect(find.text('1-30'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(selectedEpisodeNumber, 1);
    expect(find.byType(PlayerDetailSheet), findsNothing);
  });

  testWidgets('top chrome is outside scrollable content', (tester) async {
    await _openDetailSheet(tester, initialTab: PlayerDetailTab.synopsis);

    final scrollView = find.descendant(
      of: find.byType(PlayerDetailSheet),
      matching: find.byType(SingleChildScrollView),
    );
    final topChrome = find.byKey(
      const ValueKey('player_detail_sheet_top_chrome'),
    );

    expect(scrollView, findsOneWidget);
    expect(topChrome, findsOneWidget);
    expect(find.descendant(of: scrollView, matching: topChrome), findsNothing);
  });
}

Future<void> _openDetailSheet(
  WidgetTester tester, {
  required PlayerDetailTab initialTab,
  int currentEpisode = 1,
  ValueChanged<PlayerEpisode>? onEpisodeSelected,
  List<PlayerRecommendation> recommendations = const [],
}) async {
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
    episodes: const [
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
    ],
    recommendations: recommendations,
  );

  await tester.pumpWidget(
    MaterialApp(
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
                        onEpisodeSelected: (episode) {
                          if (onEpisodeSelected != null) {
                            onEpisodeSelected(episode);
                          }
                          Navigator.of(sheetContext).pop();
                        },
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
    ),
  );

  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}
