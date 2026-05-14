import 'dart:async';

import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/presentation/pages/player_page.dart';
import 'package:drama_client/features/player/presentation/widgets/player_chrome.dart';
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
    await tester.pump();

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

  testWidgets('shows poster loading before playback is ready', (tester) async {
    final openCompleter = Completer<void>();
    final playbackSession = _FakePlaybackSession(openCompleter: openCompleter);

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(Image), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsOneWidget,
    );

    openCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
    expect(find.text('A Life That Shines Again >'), findsOneWidget);
  });

  testWidgets('shows retry when playback open fails', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () =>
            _FakePlaybackSession(shouldThrowOnOpen: true),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Player failed to load.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
  });

  testWidgets('keeps video visible while buffering after first frame', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitBuffering(true);
    await tester.pump();
    await tester.pump();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.showVideo, isTrue);
    expect(chrome.showLoading, isTrue);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows video surface with loading when playing before first frame',
    (tester) async {
      final playbackSession = _FakePlaybackSession(emitWidthOnOpen: false);

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository.unlocked(),
          playbackSessionFactory: () => playbackSession,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      var chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
      expect(chrome.showVideo, isTrue);
      expect(chrome.showLoading, isTrue);
      expect(
        find.byKey(const ValueKey('player_seek_track_loading')),
        findsOneWidget,
      );

      playbackSession.emitWidth(1280);
      await tester.pump();
      await tester.pump();

      chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
      expect(chrome.showVideo, isTrue);
      expect(chrome.showLoading, isFalse);
      expect(
        find.byKey(const ValueKey('player_seek_track_loading')),
        findsNothing,
      );
    },
  );

  testWidgets('uses cover fit for vertical video sources', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _items(firstAspectRatio: 9 / 16),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.videoFit, BoxFit.cover);
  });

  testWidgets('uses contain fit for non-vertical video sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _items(firstAspectRatio: 16 / 9),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.videoFit, BoxFit.contain);
  });

  testWidgets('single drama viewport excludes bottom controls', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(
      find.byKey(const ValueKey('player_video_viewport')).first,
    );
    final pageRect = tester.getRect(find.byType(PlayerPage));

    expect(viewportRect.top, pageRect.top);
    expect(viewportRect.bottom, pageRect.bottom - 79);
  });

  testWidgets('for you viewport keeps bottom safe-area-only policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: _FakePlayerFeedRepository.unlocked(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(
      find.byKey(const ValueKey('player_video_viewport')).first,
    );
    final pageRect = tester.getRect(find.byType(PlayerPage));

    expect(viewportRect.top, pageRect.top);
    expect(viewportRect.bottom, pageRect.bottom);
  });

  testWidgets('error state does not expose playable video surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () =>
            _FakePlaybackSession(shouldThrowOnOpen: true),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.showVideo, isFalse);
    expect(chrome.showLoading, isFalse);
  });

  testWidgets('single drama taps video to pause and center play resumes', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('player_video_tap_layer')));
    await tester.pumpAndSettle();

    expect(playbackSession.pauseCount, 1);
    expect(
      find.byKey(const ValueKey('player_center_play_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_center_play_button')));
    await tester.pumpAndSettle();

    expect(playbackSession.playCount, 1);
    expect(
      find.byKey(const ValueKey('player_center_play_button')),
      findsNothing,
    );
  });

  testWidgets('playing tap shows transient pause feedback', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_video_tap_layer')));
    await tester.pump();

    expect(find.byKey(const ValueKey('player_pause_feedback')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('player_pause_feedback')), findsNothing);
  });

  testWidgets('speed sheet selects playback rate', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_speed_button')));
    await tester.pumpAndSettle();

    expect(find.text('Speed'), findsWidgets);
    expect(
      find.byKey(const ValueKey('player_speed_selected_check')),
      findsOneWidget,
    );

    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();

    expect(playbackSession.rates, [1.5]);
    expect(find.text('1.5x'), findsOneWidget);
  });

  testWidgets('single drama shows Download placeholder instead of Next', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_download_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_download_button')));
    await tester.pumpAndSettle();

    expect(find.text('EP.01'), findsOneWidget);
  });

  testWidgets('last episode still shows Download placeholder', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(items: [_items().last]),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('EP.03'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('single drama back button returns home', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player_back_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_single_top_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_episode_label')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_speed_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_more_button')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('player_single_top_bar')),
        matching: find.byType(PageView),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('for you does not show single drama top bar', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: _FakePlayerFeedRepository.unlocked(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player_single_top_bar')), findsNothing);
    expect(find.byKey(const ValueKey('player_back_button')), findsNothing);
  });

  testWidgets('pressing playback surface dims non-video overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(_topBarOpacity(tester), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('player_page_view_surface'))),
    );
    await tester.pump();

    expect(_topBarOpacity(tester), lessThan(1.0));

    await gesture.up();
    await tester.pump();

    expect(_topBarOpacity(tester), 1.0);
  });

  testWidgets('page scroll dims overlay and restores on scroll end', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('player_page_view_surface'))),
    );
    await gesture.moveBy(const Offset(0, -160));
    await tester.pump();

    expect(_topBarOpacity(tester), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_topBarOpacity(tester), 1.0);
  });

  testWidgets('single drama seek bar shows progress and seeks on drag', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pump();
    playbackSession.emitPosition(const Duration(seconds: 25));
    await tester.pump();
    playbackSession.emitBufferedPosition(const Duration(seconds: 60));
    await tester.pump();
    await tester.pump();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.position, const Duration(seconds: 25));
    expect(chrome.duration, const Duration(seconds: 100));
    expect(chrome.bufferedPosition, const Duration(seconds: 60));

    final seekBar = find.byKey(const ValueKey('player_seek_bar'));
    final gesture = await tester.startGesture(tester.getCenter(seekBar));
    await gesture.moveBy(const Offset(240, 0));
    await tester.pump();

    expect(find.textContaining(' / 01:40'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(playbackSession.seekedPositions, isNotEmpty);
  });

  testWidgets('dragging seek bar does not switch PageView item', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pumpAndSettle();

    final seekBar = find.byKey(const ValueKey('player_seek_bar'));
    final gesture = await tester.startGesture(tester.getCenter(seekBar));
    await gesture.moveBy(const Offset(180, -420));
    await tester.pump();

    expect(find.text('EP.01'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('EP.01'), findsOneWidget);
  });

  testWidgets('locked and unavailable episodes do not expose video toggle', (
    tester,
  ) async {
    final lockedSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        playbackSessionFactory: () => lockedSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
    expect(find.byKey(const ValueKey('player_seek_bar')), findsNothing);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
    expect(lockedSession.playCount, 0);

    final unavailableSession = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '3',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        playbackSessionFactory: () => unavailableSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('This episode is unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
    expect(find.byKey(const ValueKey('player_seek_bar')), findsNothing);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
    expect(unavailableSession.playCount, 0);
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

  testWidgets('completed playback auto advances to next episode', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitCompleted(true);
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets(
    'completed playback waits for page animation before state switch',
    (tester) async {
      final playbackSession = _FakePlaybackSession();

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository.unlocked(),
          playbackSessionFactory: () => playbackSession,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      playbackSession.emitCompleted(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const ValueKey('player_single_top_bar')), findsWidgets);
      expect(find.text('EP.01'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('EP.02'), findsOneWidget);
    },
  );

  testWidgets('completed playback to locked episode shows paywall', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.normal(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitCompleted(true);
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
    expect(find.text('Unlock Now'), findsOneWidget);
  });

  testWidgets('completed playback on last episode does not loop', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '3',
        ),
        repository: _FakePlayerFeedRepository._(items: [_items().last]),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitCompleted(true);
    await tester.pumpAndSettle();

    expect(find.text('EP.03'), findsOneWidget);
    expect(find.text('EP.01'), findsNothing);
  });

  testWidgets('completed playback is ignored while a sheet is open', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    playbackSession.emitCompleted(true);
    await tester.pumpAndSettle();

    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('EP.01'), findsOneWidget);
  });

  testWidgets('completed playback is ignored while seeking', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pumpAndSettle();

    final seekBar = find.byKey(const ValueKey('player_seek_bar'));
    final gesture = await tester.startGesture(tester.getCenter(seekBar));
    await tester.pump();
    playbackSession.emitCompleted(true);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('EP.01'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
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

  testWidgets('manual swipe updates per-item top bar episode label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player_single_top_bar')), findsOneWidget);
    expect(find.text('EP.01'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player_single_top_bar')), findsOneWidget);
    expect(find.text('EP.02'), findsOneWidget);
  });
}

double _topBarOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.byKey(const ValueKey('player_top_bar_opacity')).first,
  );
  return opacity.opacity;
}

const _mockVideoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const _mockSecondVideoUrl = 'https://test-streams.mux.dev/tos_ismc/main.m3u8';
const _mockThirdVideoUrl =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8';

Widget _buildPlayerApp({
  required PlayerFeedRepository repository,
  String initialLocation = '/player/drama-a/1',
  PlayerPlaybackSession Function()? playbackSessionFactory,
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
      GoRoute(
        path: '/for-you',
        builder: (context, state) => const PlayerPage.forYou(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      playerFeedRepositoryProvider.overrideWithValue(repository),
      playerPlaybackSessionFactoryProvider.overrideWithValue(
        playbackSessionFactory ?? () => _FakePlaybackSession(),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
      ),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        NoopPlayerPlaybackPrepareManager.new,
      ),
    ],
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

List<PlayerFeedItem> _items({
  bool lockedEpisode2 = false,
  double? firstAspectRatio,
}) {
  final content = _content([
    PlayerEpisode(
      id: 'ep-1',
      number: 1,
      isLocked: false,
      videoUrl: _mockVideoUrl,
      videoAspectRatio: firstAspectRatio,
    ),
    PlayerEpisode(
      id: 'ep-2',
      number: 2,
      isLocked: lockedEpisode2,
      videoUrl: _mockSecondVideoUrl,
    ),
    const PlayerEpisode(
      id: 'ep-3',
      number: 3,
      isLocked: false,
      videoUrl: _mockThirdVideoUrl,
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

class _FakePlaybackSession implements PlayerPlaybackSession {
  _FakePlaybackSession({
    this.openCompleter,
    this.shouldThrowOnOpen = false,
    this.emitWidthOnOpen = true,
  });

  final Completer<void>? openCompleter;
  final bool emitWidthOnOpen;
  bool shouldThrowOnOpen;
  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final seekedPositions = <Duration>[];
  final rates = <double>[];
  int pauseCount = 0;
  int playCount = 0;

  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<double> get rateStream => _rateController.stream;

  @override
  Stream<int?> get widthStream => _widthController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  void emitBuffering(bool isBuffering) {
    _bufferingController.add(isBuffering);
  }

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  void emitDuration(Duration duration) {
    _durationController.add(duration);
  }

  void emitBufferedPosition(Duration position) {
    _bufferedPositionController.add(position);
  }

  void emitWidth(int width) {
    _widthController.add(width);
  }

  @override
  Future<void> open(String source, {bool play = true}) async {
    _bufferingController.add(true);
    await (openCompleter?.future ?? Future<void>.value());
    if (shouldThrowOnOpen) {
      throw StateError('open failed');
    }
    if (emitWidthOnOpen) {
      _widthController.add(1280);
    }
    _completedController.add(false);
    _playingController.add(play);
    _bufferingController.add(false);
  }

  void emitCompleted(bool completed) {
    _completedController.add(completed);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCount += 1;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seekedPositions.add(position);
    _completedController.add(false);
  }

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
    _rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _bufferingController.close();
    await _playingController.close();
    await _completedController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _rateController.close();
    await _widthController.close();
    await _errorController.close();
  }
}
