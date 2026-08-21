import 'package:drama_client/features/player/data/dto/player_episode_dto.dart';
import 'package:drama_client/features/player/data/dto/player_content_dto.dart';
import 'package:drama_client/features/player/data/mapper/player_content_mapper.dart';
import 'package:drama_client/features/player/domain/player_subtitle.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail maps inline watch progress and numeric entitlement safely', () {
    final detail = PlayerContentDto.fromJson({
      'id': 1508,
      'episodes': [
        {
          'id': 8519,
          'episode_no': 1,
          'is_unlocked': 1,
          'status': 1,
          'viewing_entitlement_type': 2,
        },
      ],
      'watch_progress': {
        'watch_episode_id': 8519,
        'watch_episode_no': 1,
        'watch_second': 84,
        'duration_second': 190,
        'progress_percent': 44,
      },
    });

    expect(detail.watchProgress?.episodeId, 8519);
    expect(detail.watchProgress?.watchSecond, 84);
    expect(detail.episodes.single.viewingEntitlementType, '2');
    final content = const PlayerContentMapper().mapContent(detail);
    expect(content.watchProgress?.episodeId, '8519');
    expect(content.watchProgress?.position, const Duration(seconds: 84));
    expect(content.episodes.single.viewingEntitlementType, 'vip');
  });

  test(
    'episode mapper keeps viewing entitlement type from detail response',
    () {
      final episode = PlayerEpisodeDto.fromJson({
        'id': 1,
        'episode_no': 1,
        'source_url': 'https://cdn.test/episode.m3u8',
        'status': 1,
        'is_unlocked': 1,
        'viewing_entitlement_type': 'drama_gift',
      });

      expect(
        const PlayerContentMapper().mapEpisode(episode).viewingEntitlementType,
        'drama_gift',
      );
    },
  );

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
        {
          'id': 12,
          'language': 'English',
          'subtitle_name': 'english.srt',
          'subtitle_url': 'https://cdn.test/en.srt',
          'format': 'srt',
          'status': 1,
          // 真实 `/api/home/detail` 响应返回 number，而非文档中的 string。
          'subtitle_position': 2,
        },
        {
          'id': 13,
          'language': 'Español',
          'subtitle_name': 'spanish.srt',
          'subtitle_url': 'https://cdn.test/es.srt',
          'format': 'srt',
          'status': 1,
          'subtitle_position': '1',
        },
      ],
    });
    final externalEpisode = const PlayerContentMapper().mapEpisode(external);

    expect(externalEpisode.subtitles, hasLength(3));
    expect(externalEpisode.subtitles.first.language, '简体中文');
    expect(externalEpisode.subtitles.first.languageCode, 'zh');
    expect(
      externalEpisode.subtitles.first.position,
      PlayerSubtitlePosition.top,
    );
    expect(
      externalEpisode.subtitles[1].position,
      PlayerSubtitlePosition.middle,
    );
    expect(
      externalEpisode.subtitles[2].position,
      PlayerSubtitlePosition.bottom,
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
          language: '外挂独有语言',
          name: 'external',
          url: 'external',
          format: 'srt',
          isDefault: true,
        ),
      ],
      episodeSources: const [
        PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
      ],
    );
    expect(find.byKey(const ValueKey('player_subtitle_button')), findsNothing);

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

  testWidgets('subtitle menu shows at most three options before scrolling', (
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
              PlayerEpisodeSource(id: '2', language: 'Spanish', url: 'two'),
              PlayerEpisodeSource(id: '3', language: 'French', url: 'three'),
              PlayerEpisodeSource(id: '4', language: 'German', url: 'four'),
            ],
            currentSubtitleLanguage: 'English',
            onSubtitleSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player_subtitle_button')));
    await tester.pumpAndSettle();

    final scrollable = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('player_subtitle_menu_scroll')),
    );
    expect(scrollable, isNotNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('player_subtitle_menu_scroll')))
          .height,
      100,
    );

    await tester.drag(
      find.byKey(const ValueKey('player_subtitle_menu_scroll')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('German')).dy, lessThan(200));
  });

  testWidgets('subtitle menu closes when immersive chrome is entered', (
    tester,
  ) async {
    Widget buildTopBar({required bool showChromeOverlays}) {
      return MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlayerTopBar(
            episodeNumber: 1,
            playbackRate: 1,
            overlayOpacity: 1,
            onBackTap: () {},
            onSpeedTap: () {},
            showChromeOverlays: showChromeOverlays,
            subtitles: const [],
            episodeSources: const [
              PlayerEpisodeSource(id: '1', language: 'English', url: 'one'),
              PlayerEpisodeSource(id: '2', language: '中文', url: 'two'),
            ],
            currentSubtitleLanguage: 'English',
            onSubtitleSelected: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTopBar(showChromeOverlays: true));
    await tester.tap(find.byKey(const ValueKey('player_subtitle_button')));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(buildTopBar(showChromeOverlays: false));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
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

  testWidgets('embedded menu excludes external-only languages and Closed', (
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
            subtitles: const [
              PlayerSubtitle(
                id: 1,
                language: '外挂独有语言',
                name: 'external',
                url: 'external',
                format: 'srt',
                isDefault: true,
              ),
            ],
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
    expect(find.text('外挂独有语言'), findsNothing);
    expect(find.text('English'), findsWidgets);
    expect(find.text('中文'), findsOneWidget);
  });
}
