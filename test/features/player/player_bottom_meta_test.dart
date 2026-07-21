import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/presentation/widgets/player_chrome.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('for you synopsis toggles between More and Collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Material(
          color: Colors.black,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 240,
              child: PlayerBottomMeta(
                content: _content(),
                expandableSynopsis: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('player_synopsis_more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_synopsis_collapse')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('player_synopsis_more')));
    await tester.pump();

    expect(find.byKey(const ValueKey('player_synopsis_more')), findsNothing);
    expect(
      find.byKey(const ValueKey('player_synopsis_collapse')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_synopsis_collapse')));
    await tester.pump();

    expect(find.byKey(const ValueKey('player_synopsis_more')), findsOneWidget);
  });

  testWidgets('for you synopsis prefixes the localized current episode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Material(
          child: SizedBox(
            width: 400,
            child: PlayerBottomMeta(
              content: _content(synopsis: 'A short synopsis.'),
              episodeNumber: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('EP.01｜A short synopsis.'), findsOneWidget);
  });
}

PlayerContent _content({String? synopsis}) {
  return PlayerContent(
    id: 'drama-1',
    title: 'Drama',
    playTitle: 'Drama',
    synopsis:
        synopsis ??
        'This is a deliberately long synopsis that needs more than two lines '
            'at the test width, so the For You expansion control is displayed.',
    viewCountLabel: '1M',
    likeCountLabel: '1K',
    backgroundAssetPath: '',
    posterAssetPath: '',
    episodes: [],
    recommendations: [],
    episodeTotal: 0,
  );
}
