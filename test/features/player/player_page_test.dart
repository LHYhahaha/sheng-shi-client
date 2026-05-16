import 'dart:async';

import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
import 'package:drama_client/features/player/application/player_viewport_controller.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/presentation/pages/player_page.dart';
import 'package:drama_client/features/player/presentation/widgets/player_chrome.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
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

  testWidgets('shows loading over blank viewport before playback is ready', (
    tester,
  ) async {
    final openCompleter = Completer<void>();
    final playbackSession = _FakePlaybackSession(openCompleter: openCompleter);

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('player_poster_repaint_boundary')),
      findsWidgets,
    );
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

  testWidgets(
    'preloads next item even while current playback open is pending',
    (tester) async {
      final openCompleter = Completer<void>();
      final preloadManager = MockPlayerPlaybackPreloadManager(
        preloadDelay: Duration.zero,
      );

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository.unlocked(),
          playbackSessionFactory: () =>
              _FakePlaybackSession(openCompleter: openCompleter),
          preloadManager: preloadManager,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(preloadManager.preloadedItemIds, contains('drama-a-ep-2'));
      expect(openCompleter.isCompleted, isFalse);

      openCompleter.complete();
      await tester.pumpAndSettle();
    },
  );

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

    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
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

      expect(
        find.byKey(const ValueKey('player_video_tap_layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player_seek_track_loading')),
        findsOneWidget,
      );

      playbackSession.emitWidth(1280);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('player_seek_track_loading')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'active video surface follows PageView drag with dimmed opacity',
    (tester) async {
      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository.unlocked(),
          performancePolicy: PlayerPerformancePolicy.rich,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final followSurface = find.byKey(
        const ValueKey('active_playback_surface_follow_scroll'),
      );
      expect(followSurface, findsOneWidget);
      final before = tester.widget<Transform>(followSurface);
      expect(before.transform.getTranslation().y, 0);

      await tester.drag(find.byType(PageView), const Offset(0, -420));
      await tester.pump(const Duration(milliseconds: 50));

      expect(followSurface, findsOneWidget);
      final duringDrag = tester.widget<Transform>(followSurface);
      expect(duringDrag.transform.getTranslation().y, isNot(0.0));
      final dragOpacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: followSurface,
          matching: find.byKey(
            const ValueKey('active_playback_surface_opacity'),
          ),
        ),
      );
      expect(
        dragOpacity.opacity,
        ActivePlaybackSurfaceOverlay.richScrollFollowOpacity,
      );

      await tester.pumpAndSettle();

      expect(followSurface, findsOneWidget);
      final settledOpacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: followSurface,
          matching: find.byKey(
            const ValueKey('active_playback_surface_opacity'),
          ),
        ),
      );
      expect(settledOpacity.opacity, 1);
    },
  );

  testWidgets('stable 策略下拖动不跟手 transform 且隐藏 Video surface', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.stable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_playback_surface_follow_scroll')),
      findsNothing,
    );

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('active_playback_video_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('active_playback_surface_follow_scroll')),
      findsNothing,
    );
  });

  testWidgets('stable 策略下暂停无 scale feedback', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        performancePolicy: PlayerPerformancePolicy.stable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_video_tap_layer')));
    await tester.pump();

    expect(find.byKey(const ValueKey('player_pause_feedback')), findsNothing);
  });

  testWidgets('ultraStable 策略下拖动隐藏 Video 且无 chrome 渐隐', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.ultraStable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_playback_surface_follow_scroll')),
      findsNothing,
    );

    await tester.drag(find.byType(PageView), const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('active_playback_video_surface')),
      findsNothing,
    );

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome).first);
    expect(chrome.overlayOpacityListenable, isNull);
  });

  testWidgets('stable 策略下按压不触发 chrome 渐隐', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.stable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final pageSurface = find.byKey(const ValueKey('player_page_view_surface'));
    await tester.startGesture(tester.getCenter(pageSurface));
    await tester.pump(const Duration(milliseconds: 16));

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome).first);
    expect(chrome.overlayOpacityListenable, isNull);
  });

  testWidgets('drag page offset follows scroll without viewport state churn', (
    tester,
  ) async {
    final observer = _ViewportUpdateObserver();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        observers: [observer],
        performancePolicy: PlayerPerformancePolicy.rich,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    observer.reset();

    final pageSurface = find.byKey(const ValueKey('player_page_view_surface'));
    final gesture = await tester.startGesture(tester.getCenter(pageSurface));

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 16));

    final updatesAfterScrollStart = observer.updateCount;
    final chromeAfterScrollStart = tester.widget<PlayerChrome>(
      find.byType(PlayerChrome).first,
    );
    final followSurface = find.byKey(
      const ValueKey('active_playback_surface_follow_scroll'),
    );
    expect(followSurface, findsOneWidget);
    final transformAfterFirstMove = tester.widget<Transform>(followSurface);

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 16));

    final chromeAfterPageOffset = tester.widget<PlayerChrome>(
      find.byType(PlayerChrome).first,
    );
    final transformAfterSecondMove = tester.widget<Transform>(followSurface);

    expect(observer.updateCount, updatesAfterScrollStart);
    expect(identical(chromeAfterScrollStart, chromeAfterPageOffset), isTrue);
    expect(
      transformAfterFirstMove.transform.getTranslation().y,
      isNot(transformAfterSecondMove.transform.getTranslation().y),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_playback_surface_follow_scroll')),
      findsOneWidget,
    );
  });

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

  testWidgets('player shell isolates static paint layers', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_poster_repaint_boundary')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('player_gradient_repaint_boundary')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('player_action_rail_repaint_boundary')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('player_meta_repaint_boundary')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('player_top_bar_repaint_boundary')),
      findsWidgets,
    );
  });

  testWidgets('locked overlay is isolated from poster repaint layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player_unlock_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_unlock_repaint_boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_poster_repaint_boundary')),
      findsWidgets,
    );
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

    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
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
        performancePolicy: PlayerPerformancePolicy.rich,
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
    // Top bar lives above PageView so playback progress does not rebuild feed pages.
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('player_single_top_bar')),
        matching: find.byType(PageView),
      ),
      findsNothing,
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
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.rich,
      ),
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
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.rich,
      ),
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

    final seekBar = find.byKey(const ValueKey('player_seek_bar'));
    final seekBarWidget = tester.widget<PlayerSeekBar>(
      find.byType(PlayerSeekBar),
    );
    expect(seekBarWidget.position, const Duration(seconds: 25));
    expect(seekBarWidget.duration, const Duration(seconds: 100));
    expect(seekBarWidget.bufferedPosition, const Duration(seconds: 60));
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

  testWidgets('single drama seek bar stays visible before duration arrives', (
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

    final seekBar = find.byKey(const ValueKey('player_seek_bar'));
    expect(seekBar, findsOneWidget);
    final seekBarWidget = tester.widget<PlayerSeekBar>(
      find.byType(PlayerSeekBar),
    );
    expect(seekBarWidget.duration, Duration.zero);
    expect(seekBarWidget.enabled, isFalse);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );
  });

  testWidgets('progress updates do not rebuild PlayerChrome shell', (
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
    final chromeBefore = tester.widget<PlayerChrome>(find.byType(PlayerChrome));

    playbackSession.emitPosition(const Duration(seconds: 20));
    await tester.pump();
    playbackSession.emitBufferedPosition(const Duration(seconds: 45));
    await tester.pump();

    final chromeAfter = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(identical(chromeBefore, chromeAfter), isTrue);

    final seekBarWidget = tester.widget<PlayerSeekBar>(
      find.byType(PlayerSeekBar),
    );
    expect(seekBarWidget.position, const Duration(seconds: 20));
    expect(seekBarWidget.duration, const Duration(seconds: 100));
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

  testWidgets('membership episode sends non-member to member paywall', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.membershipLocked(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Member unlock'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);

    await tester.tap(find.text('Member unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Membership'), findsOneWidget);
    expect(playbackSession.playCount, 0);
  });

  testWidgets('membership episode allows member to play', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.membershipLocked(),
        entitlementRepository: MockEntitlementRepository.loggedInMember(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Member unlock'), findsNothing);
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets('coin episode already unlocked can play', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        entitlementRepository: MockEntitlementRepository(
          initialState: const UserEntitlementState(
            isGuest: false,
            isMember: false,
            coinBalance: 20,
            autoUnlockEnabled: false,
            unlockedEpisodeIds: <String>{'ep-2'},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Now'), findsNothing);
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets('coin episode auto unlock enabled still requires confirmation', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        entitlementRepository:
            MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsOneWidget,
    );
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
    expect(playbackSession.playCount, 0);
  });

  testWidgets('coin episode enough balance with auto off shows coin dialog', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession(emitWidthOnOpen: false);
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        entitlementRepository:
            MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_coin_unlock_price')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_coin_unlock_balance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_coin_unlock_auto_next_switch')),
      findsOneWidget,
    );
    expect(find.text('Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('player_coin_unlock_close')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_unlock_button')), findsOneWidget);

    await _pumpAutoUnlockSheet(tester);

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player_unlock_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_coin_unlock_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsOneWidget,
    );
    expect(find.text('Unlock Now'), findsNothing);
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets('locked episode opens recharge unlock sheet with offer details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_info')),
      findsOneWidget,
    );
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('+9%'), findsOneWidget);
    expect(find.text('Weekly VIP'), findsOneWidget);
    expect(find.text(r'$12.99'), findsOneWidget);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_promo_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_tips')),
      findsOneWidget,
    );
  });

  testWidgets('swiping into locked episode shows unlock before auto sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _itemsWithAccessPattern([
            _EpisodeAccessFixture.free(1, _mockVideoUrl),
            _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
          ]),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(0, -700), 1600);
    await tester.pump();

    expect(find.text('Recharge to unlock'), findsNothing);

    await _pumpAutoUnlockSheet(tester);

    expect(find.text('EP.02'), findsOneWidget);
    expect(find.text('Recharge to unlock'), findsOneWidget);
  });

  testWidgets('dragging toward locked episode does not run runtime work', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager(
      preloadDelay: Duration.zero,
    );

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _itemsWithAccessPattern([
            _EpisodeAccessFixture.free(1, _mockVideoUrl),
            _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
          ]),
        ),
        playbackSessionFactory: () => playbackSession,
        preloadManager: preloadManager,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.pauseCount = 0;
    playbackSession.playCount = 0;
    preloadManager.preloadedItemIds.clear();
    preloadManager.preloadCount = 0;
    preloadManager.releasePendingCount = 0;

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(playbackSession.pauseCount, 0);
    expect(playbackSession.playCount, 0);
    expect(playbackSession.openedSources, [_mockVideoUrl]);
    expect(preloadManager.preloadedItemIds, isEmpty);
    expect(preloadManager.preloadCount, 0);
    expect(preloadManager.releasePendingCount, 0);
  });

  testWidgets(
    'fast swipe across locked episodes only opens final current sheet',
    (tester) async {
      final playbackSession = _FakePlaybackSession();
      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository._(
            items: _itemsWithAccessPattern([
              _EpisodeAccessFixture.free(1, _mockVideoUrl),
              _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
              _EpisodeAccessFixture.locked(3, _mockThirdVideoUrl),
            ]),
          ),
          playbackSessionFactory: () => playbackSession,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PageView), const Offset(0, -700), 1600);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Recharge to unlock'), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(0, -700), 1600);
      await _pumpAutoUnlockSheet(tester);

      expect(find.text('EP.03'), findsOneWidget);
      expect(find.text('Recharge to unlock'), findsOneWidget);
      expect(playbackSession.openedSources, [_mockVideoUrl]);
    },
  );

  testWidgets('coin package purchase continues to coin unlock confirmation', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_coin_coins_300')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_processing')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(playbackSession.playCount, 0);

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('player_coin_unlock_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsNothing);
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets('membership package can start mock unlock purchase', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_membership_weekly_vip_promo')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_processing')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
  });

  testWidgets('membership package success from recharge sheet stays blocked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_membership_weekly_vip_promo')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_processing')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
  });

  testWidgets('unavailable episode remains blocked for member', (tester) async {
    final unavailableSession = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '3',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        entitlementRepository: MockEntitlementRepository.loggedInMember(),
        playbackSessionFactory: () => unavailableSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('This episode is unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_video_tap_layer')), findsNothing);
    expect(unavailableSession.playCount, 0);
  });

  testWidgets('promotion badge hides when countdown ends', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_promo_badge')),
      findsOneWidget,
    );

    await tester.pump(const Duration(hours: 1, seconds: 1));

    expect(
      find.byKey(const ValueKey('player_recharge_promo_badge')),
      findsNothing,
    );
  });

  testWidgets('recharge sheet close keeps player in pending unlock state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_unlock_button')), findsOneWidget);
    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets('closing locked sheet allows swiping to free episode playback', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _itemsWithAccessPattern([
            _EpisodeAccessFixture.free(1, _mockVideoUrl),
            _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
            _EpisodeAccessFixture.free(3, _mockThirdVideoUrl),
          ]),
        ),
        playbackSessionFactory: () => playbackSession,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(playbackSession.openedSources, [_mockVideoUrl]);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await _pumpAutoUnlockSheet(tester);
    expect(find.text('EP.02'), findsOneWidget);
    expect(find.text('Recharge to unlock'), findsOneWidget);
    expect(playbackSession.pauseCount, greaterThan(0));
    expect(playbackSession.openedSources, [_mockVideoUrl]);

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('Recharge to unlock'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await _pumpAutoUnlockSheet(tester);

    expect(find.text('EP.03'), findsOneWidget);
    expect(find.text('Unlock Now'), findsNothing);
    expect(playbackSession.openedSources, [_mockVideoUrl, _mockThirdVideoUrl]);
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets(
    'swiping back to access-overlay paused episode resumes playback',
    (tester) async {
      final playbackSession = _FakePlaybackSession();

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository._(
            items: _itemsWithAccessPattern([
              _EpisodeAccessFixture.free(1, _mockVideoUrl),
              _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
            ]),
          ),
          playbackSessionFactory: () => playbackSession,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(playbackSession.openedSources, [_mockVideoUrl]);

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 16));

      expect(playbackSession.pauseCount, 0);
      expect(playbackSession.openedSources, [_mockVideoUrl]);

      await tester.pumpAndSettle();

      expect(find.text('EP.02'), findsOneWidget);
      expect(find.text('Unlock Now'), findsOneWidget);
      expect(playbackSession.pauseCount, greaterThan(0));
      expect(playbackSession.openedSources, [_mockVideoUrl]);

      if (find.text('Recharge to unlock').evaluate().isNotEmpty) {
        await tester.tap(
          find.byKey(const ValueKey('player_recharge_unlock_close')),
        );
        await tester.pumpAndSettle();
      }

      await tester.drag(find.byType(PageView), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('EP.01'), findsOneWidget);
      expect(find.text('Unlock Now'), findsNothing);
      expect(playbackSession.openedSources, [_mockVideoUrl]);
      expect(playbackSession.playCount, 1);
      expect(
        find.byKey(const ValueKey('player_video_tap_layer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'consecutive locked episodes reopen sheet without opening locked sources',
    (tester) async {
      final playbackSession = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager(
        preloadDelay: Duration.zero,
      );

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository._(
            items: _itemsWithAccessPattern([
              _EpisodeAccessFixture.free(1, _mockVideoUrl),
              _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
              _EpisodeAccessFixture.locked(3, _mockThirdVideoUrl),
              _EpisodeAccessFixture.free(
                4,
                'https://cdn.example.test/free-4.m3u8',
              ),
            ]),
          ),
          playbackSessionFactory: () => playbackSession,
          preloadManager: preloadManager,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await _pumpAutoUnlockSheet(tester);
      expect(find.text('EP.02'), findsOneWidget);
      expect(find.text('Recharge to unlock'), findsOneWidget);
      expect(playbackSession.openedSources, [_mockVideoUrl]);

      await tester.tap(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recharge to unlock'), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await _pumpAutoUnlockSheet(tester);

      expect(find.text('EP.03'), findsOneWidget);
      expect(find.text('Recharge to unlock'), findsOneWidget);
      expect(playbackSession.openedSources, [_mockVideoUrl]);
      expect(preloadManager.preloadedItemIds, isNot(contains('drama-a-ep-2')));
      expect(preloadManager.preloadedItemIds, isNot(contains('drama-a-ep-3')));
    },
  );

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('Recharge to unlock'), findsNothing);

    await _pumpAutoUnlockSheet(tester);

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets('selecting locked episode pauses previous playback', (
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

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await _pumpAutoUnlockSheet(tester);

    expect(find.text('Recharge to unlock'), findsOneWidget);
    expect(playbackSession.pauseCount, greaterThan(0));
    expect(playbackSession.playCount, 0);
  });

  testWidgets('closing unlock sheet does not resume previous playback', (
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

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await _pumpAutoUnlockSheet(tester);
    final pauseCountAfterLock = playbackSession.pauseCount;

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(playbackSession.pauseCount, pauseCountAfterLock);
    expect(playbackSession.playCount, 0);

    await _pumpAutoUnlockSheet(tester);

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(find.text('Unlock Now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player_unlock_button')));
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsOneWidget);
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
    await _pumpAutoUnlockSheet(tester);

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
    await _pumpAutoUnlockSheet(tester);

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

  testWidgets('back closes unlock sheet and keeps inline unlock action', (
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
    await _pumpAutoUnlockSheet(tester);
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(find.text('Recharge to unlock'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Recharge to unlock'), findsNothing);
    expect(find.text('Unlock Now'), findsOneWidget);

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

Future<void> _pumpAutoUnlockSheet(WidgetTester tester) async {
  for (var i = 0; i < 80; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(Duration.zero);
    if (find.text('Recharge to unlock').evaluate().isNotEmpty ||
        find
            .byKey(const ValueKey('player_coin_unlock_confirm'))
            .evaluate()
            .isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

const _mockVideoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const _mockSecondVideoUrl = 'https://test-streams.mux.dev/tos_ismc/main.m3u8';
const _mockThirdVideoUrl =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8';

Widget _buildPlayerApp({
  required PlayerFeedRepository repository,
  String initialLocation = '/player/drama-a/1',
  PlayerPlaybackSession Function()? playbackSessionFactory,
  PlayerPlaybackPreloadManager? preloadManager,
  MockEntitlementRepository? entitlementRepository,
  List<ProviderObserver> observers = const [],
  PlayerPerformancePolicy? performancePolicy,
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
      GoRoute(
        path: RoutePaths.membership,
        builder: (context, state) => const Scaffold(body: Text('Membership')),
      ),
    ],
  );

  return ProviderScope(
    observers: observers,
    overrides: [
      entitlementRepositoryProvider.overrideWithValue(
        entitlementRepository ??
            MockEntitlementRepository.loggedInNonMemberLowCoins(),
      ),
      playerFeedRepositoryProvider.overrideWithValue(repository),
      playerPlaybackSessionFactoryProvider.overrideWithValue(
        playbackSessionFactory ?? () => _FakePlaybackSession(),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        preloadManager ??
            MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
      ),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        NoopPlayerPlaybackPrepareManager.new,
      ),
      if (performancePolicy != null)
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          performancePolicy,
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

final class _ViewportUpdateObserver extends ProviderObserver {
  int updateCount = 0;

  void reset() {
    updateCount = 0;
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (previousValue is PlayerViewportState ||
        newValue is PlayerViewportState) {
      updateCount += 1;
    }
  }
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

  factory _FakePlayerFeedRepository.membershipLocked() {
    return _FakePlayerFeedRepository._(
      items: _items(
        lockedEpisode2: true,
        episode2UnlockType: EpisodeUnlockType.membership,
      ),
    );
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
  EpisodeUnlockType episode2UnlockType = EpisodeUnlockType.coins,
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
      unlockType: lockedEpisode2 ? episode2UnlockType : EpisodeUnlockType.free,
      requiredCoins: 60,
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

List<PlayerFeedItem> _itemsWithAccessPattern(
  List<_EpisodeAccessFixture> fixtures,
) {
  final content = _content([
    for (final fixture in fixtures)
      PlayerEpisode(
        id: 'ep-${fixture.number}',
        number: fixture.number,
        isLocked: fixture.isLocked,
        unlockType: fixture.isLocked
            ? fixture.unlockType
            : EpisodeUnlockType.free,
        requiredCoins: fixture.requiredCoins,
        videoUrl: fixture.videoUrl,
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

class _EpisodeAccessFixture {
  const _EpisodeAccessFixture({
    required this.number,
    required this.videoUrl,
    required this.isLocked,
    this.unlockType = EpisodeUnlockType.coins,
    this.requiredCoins = 60,
  });

  factory _EpisodeAccessFixture.free(int number, String videoUrl) {
    return _EpisodeAccessFixture(
      number: number,
      videoUrl: videoUrl,
      isLocked: false,
    );
  }

  factory _EpisodeAccessFixture.locked(
    int number,
    String videoUrl, {
    EpisodeUnlockType unlockType = EpisodeUnlockType.coins,
    int requiredCoins = 60,
  }) {
    return _EpisodeAccessFixture(
      number: number,
      videoUrl: videoUrl,
      isLocked: true,
      unlockType: unlockType,
      requiredCoins: requiredCoins,
    );
  }

  final int number;
  final String videoUrl;
  final bool isLocked;
  final EpisodeUnlockType unlockType;
  final int requiredCoins;
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
  final openedSources = <String>[];
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
    openedSources.add(source);
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
