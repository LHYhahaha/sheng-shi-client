import 'package:drama_client/features/player/data/dto/player_episode_dto.dart';
import 'package:drama_client/features/player/data/mapper/player_content_mapper.dart';
import 'package:drama_client/features/player/domain/player_subtitle.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('episode mapper parses external and embedded subtitle metadata', () {
    final external = PlayerEpisodeDto.fromJson({
      'id': 1,
      'episode_no': 1,
      'source_url': 'https://cdn.test/default.m3u8',
      'status': 1,
      'is_unlocked': 1,
      'subtitles': [
        {
          'id': 11,
          'language': '简体中文',
          'language_code': 'zh',
          'subtitle_name': 'ignored.srt',
          'subtitle_url': 'https://cdn.test/zh.srt',
          'format': 'srt',
          'status': 1,
          'subtitle_position': '3',
        },
      ],
    });
    final externalEpisode = const PlayerContentMapper().mapEpisode(external);

    expect(externalEpisode.subtitles.single.language, '简体中文');
    expect(externalEpisode.subtitles.single.languageCode, 'zh');
    expect(
      externalEpisode.subtitles.single.position,
      PlayerSubtitlePosition.top,
    );

    final embedded = PlayerEpisodeDto.fromJson({
      'id': 2,
      'episode_no': 2,
      'source_url': 'https://cdn.test/default.m3u8',
      'status': 1,
      'is_unlocked': 1,
      'episode_sources': [
        {
          'id': 21,
          'language': 'English',
          'language_code': 'en',
          'source_url': 'https://cdn.test/en.m3u8',
          'status': 1,
        },
        {
          'id': '22',
          'language': '下架资源',
          'source_url': 'https://cdn.test/offline.m3u8',
          'status': '0',
        },
      ],
    });
    final embeddedEpisode = const PlayerContentMapper().mapEpisode(embedded);

    expect(embeddedEpisode.episodeSources, hasLength(1));
    expect(embeddedEpisode.episodeSources.single.id, '21');
    expect(embeddedEpisode.episodeSources.single.language, 'English');
    expect(embeddedEpisode.episodeSources.single.languageCode, 'en');
  });

  testWidgets('language entry follows external and embedded count rules', (
    tester,
  ) async {
    Future<void> pump({
      List<PlayerSubtitle> subtitles = const [],
      List<PlayerEpisodeSource> episodeSources = const [],
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerTopBar(
              episodeNumber: 1,
              playbackRate: 1,
              overlayOpacity: 1,
              onBackTap: () {},
              onSpeedTap: () {},
              showChromeOverlays: true,
              subtitles: subtitles,
              episodeSources: episodeSources,
              currentSubtitleLanguage: null,
              onSubtitleSelected: (_) {},
            ),
          ),
        ),
      );
    }

    await pump();
    expect(find.byKey(const ValueKey('player_subtitle_button')), findsNothing);

    await pump(
      episodeSources: const [
        PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
      ],
    );
    expect(find.byKey(const ValueKey('player_subtitle_button')), findsNothing);

    await pump(
      episodeSources: const [
        PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
        PlayerEpisodeSource(id: '2', language: 'Español', url: 'two'),
      ],
    );
    expect(
      find.byKey(const ValueKey('player_subtitle_button')),
      findsOneWidget,
    );

    await pump(
      subtitles: const [
        PlayerSubtitle(
          id: 1,
          language: '简体中文',
          name: 'ignored.srt',
          url: 'subtitle',
          format: 'srt',
          isDefault: false,
        ),
      ],
    );
    expect(
      find.byKey(const ValueKey('player_subtitle_button')),
      findsOneWidget,
    );
  });

  testWidgets('selected embedded language is highlighted with check mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlayerTopBar(
            episodeNumber: 1,
            playbackRate: 1,
            overlayOpacity: 1,
            onBackTap: () {},
            onSpeedTap: () {},
            showChromeOverlays: true,
            subtitles: const [],
            episodeSources: const [
              PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
              PlayerEpisodeSource(id: '2', language: '中文', url: 'two'),
            ],
            currentSubtitleLanguage: '中文',
            onSubtitleSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player_subtitle_button')));
    await tester.pumpAndSettle();

    final selectedText = tester.widget<Text>(find.text('中文').last);
    expect(selectedText.style?.color, AppColors.primary);
    expect(selectedText.style?.fontWeight, FontWeight.w600);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('subtitle entry stays hidden until the selection is resolved', (
    tester,
  ) async {
    Future<void> pump({required bool isResolved}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerTopBar(
              episodeNumber: 1,
              playbackRate: 1,
              overlayOpacity: 1,
              onBackTap: () {},
              onSpeedTap: () {},
              showChromeOverlays: true,
              subtitles: const [
                PlayerSubtitle(
                  id: 1,
                  language: 'English',
                  name: 'English',
                  url: 'subtitle',
                  format: 'srt',
                  isDefault: true,
                ),
              ],
              episodeSources: const [],
              currentSubtitleLanguage: isResolved ? 'English' : null,
              isSubtitleSelectionResolved: isResolved,
              onSubtitleSelected: (_) {},
            ),
          ),
        ),
      );
    }

    await pump(isResolved: false);
    expect(find.byKey(const ValueKey('player_subtitle_button')), findsNothing);
    expect(find.text('Subtitle: Closed'), findsNothing);

    await pump(isResolved: true);
    expect(
      find.byKey(const ValueKey('player_subtitle_button')),
      findsOneWidget,
    );
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('subtitle entry stays hidden while the page is moving', (
    tester,
  ) async {
    Future<void> pump({required bool showSubtitleEntry}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerTopBar(
              episodeNumber: 1,
              playbackRate: 1,
              overlayOpacity: 1,
              onBackTap: () {},
              onSpeedTap: () {},
              showChromeOverlays: true,
              subtitles: const [
                PlayerSubtitle(
                  id: 1,
                  language: 'English',
                  name: 'English',
                  url: 'subtitle',
                  format: 'srt',
                  isDefault: true,
                ),
              ],
              episodeSources: const [],
              currentSubtitleLanguage: 'English',
              showSubtitleEntry: showSubtitleEntry,
              onSubtitleSelected: (_) {},
            ),
          ),
        ),
      );
    }

    await pump(showSubtitleEntry: false);
    expect(find.byKey(const ValueKey('player_subtitle_button')), findsNothing);

    await pump(showSubtitleEntry: true);
    expect(
      find.byKey(const ValueKey('player_subtitle_button')),
      findsOneWidget,
    );
  });

  testWidgets('embedded subtitle language menu does not show closed option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlayerTopBar(
            episodeNumber: 1,
            playbackRate: 1,
            overlayOpacity: 1,
            onBackTap: () {},
            onSpeedTap: () {},
            showChromeOverlays: true,
            subtitles: const [],
            episodeSources: const [
              PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
              PlayerEpisodeSource(id: '2', language: '中文', url: 'two'),
            ],
            currentSubtitleLanguage: 'English',
            onSubtitleSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player_subtitle_button')));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsNothing);
    expect(find.text('English'), findsWidgets);
    expect(find.text('中文'), findsOneWidget);
  });
}
