import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drama_client/app/app_root_navigator_key.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/app/router/route_names.dart';
import 'package:drama_client/bootstrap/app_modal_registry_bootstrap.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:drama_client/features/player/data/dto/watch_progress_dto.dart';
import 'package:drama_client/features/player/data/mock_playback_progress_repository.dart';
import 'package:drama_client/features/player/data/playback_progress_repository_provider.dart';
import 'package:drama_client/features/player/data/player_content_repository_provider.dart';
import 'package:drama_client/features/player/data/player_exit_recommendation_history_repository_provider.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/player_remote_data_source_provider.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:drama_client/features/player/data/shared_preferences_player_exit_recommendation_history_repository.dart';
import 'package:drama_client/features/player/application/player_chrome_auto_immersive_config_provider.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_recharge_unlock_controller.dart';
import 'package:drama_client/features/player/domain/player_chrome_auto_immersive_config.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
import 'package:drama_client/features/player/application/player_viewport_controller.dart';
import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/for_you_player_handoff.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/features/player/presentation/pages/player_page.dart';
import 'package:drama_client/features/player/presentation/widgets/player_payment_method_modal_layer.dart';
import 'package:drama_client/features/player/presentation/widgets/player_payment_method_sheet.dart';
import 'package:drama_client/features/player/domain/player_recharge_unlock_offer.dart';
import '../../core/toast/recording_app_toast_service.dart';
import 'package:drama_client/features/player/presentation/widgets/player_chrome.dart';
import 'package:drama_client/features/player/presentation/widgets/player_detail_sheet.dart';
import 'package:drama_client/features/player/presentation/widgets/player_exit_recommendation_dialog.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
import 'package:drama_client/features/popup/data/popup_repository.dart';
import 'package:drama_client/features/popup/data/popup_repository_provider.dart';
import 'package:drama_client/features/popup/domain/popup.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('for you like highlights and reports the current drama', (
    tester,
  ) async {
    final remoteDataSource = _FakePlayerRemoteDataSource(watchProgress: null);
    final repository = _FakePlayerFeedRepository._(items: _numericDramaItems());

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.forYou,
        repository: repository,
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          playerRemoteDataSourceProvider.overrideWithValue(remoteDataSource),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final likeButton = find.byKey(const ValueKey('player_like_button_42'));
    expect(likeButton, findsOneWidget);
    expect(_likeIconAsset(tester, likeButton), contains('unclick_like.png'));

    await tester.tap(likeButton);
    await tester.pump();

    expect(remoteDataSource.followedDramaIds, [42]);
    expect(_likeIconAsset(tester, likeButton), contains('click_like.png'));

    await tester.tap(likeButton);
    await tester.pump();

    expect(remoteDataSource.unfollowedDramaIds, [42]);
    expect(_likeIconAsset(tester, likeButton), contains('unclick_like.png'));
  });

  testWidgets('for you search pauses on leave and always plays on return', (
    tester,
  ) async {
    final session = _FakePlaybackSession();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.forYou,
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => session,
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          playerRemoteDataSourceProvider.overrideWithValue(
            _FakePlayerRemoteDataSource(watchProgress: null),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    session.emitPlaying(false);
    await tester.pump();
    final pauseCountBeforeSearch = session.pauseCount;
    final playCountBeforeSearch = session.playCount;
    await tester.tap(
      find.byKey(const ValueKey('player_for_you_search_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(session.pauseCount, greaterThan(pauseCountBeforeSearch));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsNothing);
    expect(session.playCount, greaterThan(playCountBeforeSearch));
  });

  testWidgets('for you watch now opens single drama at current position', (
    tester,
  ) async {
    final repository = _FakePlayerFeedRepository.unlocked();
    final sessions = <_FakePlaybackSession>[];

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: repository,
        playbackSessionFactory: () {
          final session = _FakePlaybackSession();
          sessions.add(session);
          return session;
        },
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          playerRemoteDataSourceProvider.overrideWithValue(
            _FakePlayerRemoteDataSource(watchProgress: null),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final forYouSession = sessions.first;
    forYouSession.emitDuration(const Duration(seconds: 120));
    forYouSession.emitPosition(const Duration(seconds: 37));
    await tester.pump();

    await tester.tap(find.text('Watch Now').first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.lastSingleDramaEpisodeId, 'ep-1');
    expect(sessions, hasLength(2));
    expect(
      sessions.last.openStartPositions,
      contains(const Duration(seconds: 37)),
    );
    expect(find.byKey(const ValueKey('player_back_button')), findsOneWidget);
  });

  testWidgets(
    'returning from watch now resumes for you at latest player position',
    (tester) async {
      final sessions = <_FakePlaybackSession>[];

      await tester.pumpWidget(
        _buildPlayerApp(
          initialLocation: '/for-you',
          repository: _FakePlayerFeedRepository.unlocked(),
          playbackSessionFactory: () {
            final session = _FakePlaybackSession();
            sessions.add(session);
            return session;
          },
          useDefaultRemoteDataSource: false,
          providerOverrides: [
            playerRemoteDataSourceProvider.overrideWithValue(
              _FakePlayerRemoteDataSource(watchProgress: null),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      sessions.first.emitDuration(const Duration(seconds: 120));
      sessions.first.emitPosition(const Duration(seconds: 37));
      await tester.pump();
      await tester.tap(find.text('Watch Now').first);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      sessions.last.emitDuration(const Duration(seconds: 120));
      sessions.last.emitPosition(const Duration(seconds: 68));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('player_back_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(
        sessions.first.seekedPositions,
        contains(const Duration(seconds: 68)),
      );
      expect(sessions.first.playCount, greaterThan(0));
    },
  );

  testWidgets('for you completion opens single drama player', (tester) async {
    final sessions = <_FakePlaybackSession>[];

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () {
          final session = _FakePlaybackSession();
          sessions.add(session);
          return session;
        },
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          playerRemoteDataSourceProvider.overrideWithValue(
            _FakePlayerRemoteDataSource(watchProgress: null),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 60; attempt += 1) {
      if (sessions.first.openedSources.isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    sessions.first.emitDuration(const Duration(seconds: 120));
    sessions.first.emitPosition(const Duration(seconds: 120));
    sessions.first.emitPlaying(true);
    await tester.pump();
    sessions.first.emitCompleted(true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(sessions, hasLength(2));
  });

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

  testWidgets('remote resume switches viewport before starting playback', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final repository = _FakePlayerFeedRepository.unlocked();

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: '1',
          episodeId: '1',
        ),
        repository: repository,
        playbackSessionFactory: () => playbackSession,
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          useRemotePlayerApiProvider.overrideWithValue(true),
          playerRemoteDataSourceProvider.overrideWithValue(
            _FakePlayerRemoteDataSource(
              watchProgress: WatchProgressDto(
                dramaId: 1,
                episodeId: 2,
                episodeNo: 2,
                watchSecond: 35,
                durationSecond: 120,
                progressPercent: 29,
              ),
              delay: const Duration(milliseconds: 100),
            ),
          ),
          apiClientProvider.overrideWithValue(
            ApiClient(
              requestContext: const ApiRequestContext.test(
                deviceId: 'test-device-id',
                accessToken: 'test-access-token',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(playbackSession.openedSources, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(repository.lastSingleDramaEpisodeId, '2');
    expect(find.text('EP.02'), findsOneWidget);
    expect(playbackSession.openedSources, [_mockSecondVideoUrl]);
    expect(
      playbackSession.openStartPositions,
      contains(const Duration(seconds: 35)),
    );
    expect(playbackSession.seekedPositions, isEmpty);
  });

  testWidgets('remote completed episode before locked next rewinds current', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final repository = _FakePlayerFeedRepository.normal();

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: '1',
          episodeId: '1',
        ),
        repository: repository,
        playbackSessionFactory: () => playbackSession,
        useDefaultRemoteDataSource: false,
        providerOverrides: [
          useRemotePlayerApiProvider.overrideWithValue(true),
          playerRemoteDataSourceProvider.overrideWithValue(
            _FakePlayerRemoteDataSource(
              watchProgress: WatchProgressDto(
                dramaId: 1,
                episodeId: 1,
                episodeNo: 1,
                watchSecond: 120,
                durationSecond: 120,
                progressPercent: 100,
              ),
            ),
          ),
          apiClientProvider.overrideWithValue(
            ApiClient(
              requestContext: const ApiRequestContext.test(
                deviceId: 'test-device-id',
                accessToken: 'test-access-token',
              ),
            ),
          ),
        ],
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.lastSingleDramaEpisodeId, '1');
    expect(find.text('EP.01'), findsOneWidget);
    expect(playbackSession.openedSources, [_mockVideoUrl]);
    expect(
      playbackSession.openStartPositions,
      contains(const Duration(seconds: 112)),
    );
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

  testWidgets('stable 策略下拖动 Video surface 跟手且无 opacity 压暗', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        performancePolicy: PlayerPerformancePolicy.stable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_playback_surface_static')),
      findsNothing,
    );
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
    final dragOpacity = tester.widget<Opacity>(
      find.descendant(
        of: followSurface,
        matching: find.byKey(const ValueKey('active_playback_surface_opacity')),
      ),
    );
    expect(dragOpacity.opacity, 1.0);
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

  testWidgets('single drama viewport extends after hiding bottom actions', (
    tester,
  ) async {
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
    expect(viewportRect.bottom, pageRect.bottom - 32);
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

    await _doubleTapVideo(tester);
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

    await _doubleTapVideo(tester);
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

  testWidgets('single drama hides commerce placeholders for current version', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(find.byKey(const ValueKey('player_download_button')), findsNothing);
    expect(find.byKey(const ValueKey('player_member_button')), findsNothing);
  });

  testWidgets('last episode still hides commerce placeholders', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(items: [_items().last]),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('EP.03'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(find.byKey(const ValueKey('player_download_button')), findsNothing);
    expect(find.byKey(const ValueKey('player_member_button')), findsNothing);
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
        performancePolicy: PlayerPerformancePolicy.rich,
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
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player_seek_time_bubble')),
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

  testWidgets('stable 策略拖动 seekbar 无缩略图但有轻量时间气泡', (tester) async {
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

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pump();
    playbackSession.emitPosition(const Duration(seconds: 25));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('player_seek_bar'))),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player_seek_time_bubble')),
      findsOneWidget,
    );
    expect(find.textContaining(' / 01:40'), findsOneWidget);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('ultraStable 策略拖动 seekbar 无缩略图且无时间气泡', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        performancePolicy: PlayerPerformancePolicy.ultraStable,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pump();
    playbackSession.emitPosition(const Duration(seconds: 25));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('player_seek_bar'))),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('player_seek_time_bubble')), findsNothing);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('single drama default mode shows chrome overlays', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => _FakePlaybackSession(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.showChromeOverlays, isTrue);
    expect(
      find.byKey(const ValueKey('player_top_bar_repaint_boundary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player_back_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_episode_label')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_speed_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_more_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_download_button')), findsNothing);
    expect(find.byKey(const ValueKey('player_member_button')), findsNothing);
    expect(
      find.byKey(const ValueKey('player_action_rail_repaint_boundary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player_seek_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_immersive_button')), findsNothing);
  });

  testWidgets('single drama auto enters immersive chrome while playing', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        providerOverrides: _singleDramaAutoImmersiveTestOverrides,
      ),
    );
    await _pumpUntilSingleDramaPlaybackReady(tester);

    expect(
      tester.widget<PlayerChrome>(find.byType(PlayerChrome)).showChromeOverlays,
      isTrue,
    );

    await tester.pump(
      _testAutoImmersiveDelay + const Duration(milliseconds: 80),
    );

    final chrome = tester.widget<PlayerChrome>(find.byType(PlayerChrome));
    expect(chrome.showChromeOverlays, isFalse);
    expect(find.byKey(const ValueKey('player_seek_bar')), findsOneWidget);
    final topBarVisibility = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('player_top_bar_chrome_visibility')),
    );
    expect(topBarVisibility.opacity, 0);
  });

  testWidgets('single drama immersive tap restores default without pausing', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        providerOverrides: _singleDramaAutoImmersiveTestOverrides,
      ),
    );
    await _pumpUntilSingleDramaPlaybackReady(tester);
    await tester.pump(
      _testAutoImmersiveDelay + const Duration(milliseconds: 80),
    );

    expect(
      tester.widget<PlayerChrome>(find.byType(PlayerChrome)).showChromeOverlays,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('player_video_tap_layer')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<PlayerChrome>(find.byType(PlayerChrome)).showChromeOverlays,
      isTrue,
    );
    expect(playbackSession.pauseCount, 0);
  });

  testWidgets('single drama default tap pauses while playing', (tester) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        providerOverrides: _singleDramaAutoImmersiveDisabledOverrides,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_video_tap_layer')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(playbackSession.pauseCount, 1);
    expect(
      tester.widget<PlayerChrome>(find.byType(PlayerChrome)).showChromeOverlays,
      isTrue,
    );
  });

  testWidgets('for you does not auto enter immersive chrome', (tester) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => _FakePlaybackSession(),
        providerOverrides: _singleDramaAutoImmersiveTestOverrides,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(_testAutoImmersiveDelay + const Duration(seconds: 1));
    await tester.pump();

    expect(
      tester.widget<PlayerChrome>(find.byType(PlayerChrome)).showChromeOverlays,
      isTrue,
    );
  });

  testWidgets('single drama immersive mode seek bar remains draggable', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => playbackSession,
        providerOverrides: _singleDramaAutoImmersiveTestOverrides,
      ),
    );
    await _pumpUntilSingleDramaPlaybackReady(tester);

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pump();
    playbackSession.emitPosition(const Duration(seconds: 10));
    await tester.pump();

    await tester.pump(
      _testAutoImmersiveDelay + const Duration(milliseconds: 80),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('player_seek_bar'))),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(playbackSession.seekedPositions, isNotEmpty);
  });

  testWidgets('PlayerChrome keeps unlock affordance when overlays hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerChrome(
          content: _content(const [
            PlayerEpisode(
              id: 'ep-1',
              number: 1,
              isLocked: true,
              videoUrl: _mockVideoUrl,
            ),
          ]),
          isPlaying: false,
          showCenterPlayButton: false,
          showChromeOverlays: false,
          showUnlockButton: true,
          unlockLabel: 'Unlock Now',
          onTogglePlay: () {},
          onWatchNowTap: () {},
          onEpisodesTap: () {},
          onShareTap: () {},
          onMoreTap: () {},
          onUnlockTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('player_unlock_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_download_button')), findsNothing);
  });

  testWidgets('single drama seek bar uses episode metadata duration fallback', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();

    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _itemsWithAccessPattern([
            _EpisodeAccessFixture.free(
              1,
              _mockVideoUrl,
              duration: const Duration(seconds: 105),
            ),
            _EpisodeAccessFixture.free(
              2,
              _mockSecondVideoUrl,
              duration: const Duration(seconds: 90),
            ),
            _EpisodeAccessFixture.free(
              3,
              _mockThirdVideoUrl,
              duration: const Duration(seconds: 95),
            ),
          ]),
        ),
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
    expect(seekBarWidget.duration, const Duration(seconds: 105));
    expect(seekBarWidget.enabled, isTrue);
    expect(seekBarWidget.isPassiveTrack, isFalse);
    expect(
      find.byKey(const ValueKey('player_seek_track_loading')),
      findsNothing,
    );

    playbackSession.emitDuration(const Duration(seconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    final seekBarAfter = tester.widget<PlayerSeekBar>(
      find.byType(PlayerSeekBar),
    );
    expect(seekBarAfter.isPassiveTrack, isFalse);
    expect(seekBarAfter.duration, const Duration(seconds: 100));
    expect(find.byKey(const ValueKey('player_seek_bar')), findsOneWidget);
  });

  testWidgets('seek bar remains passive without media or metadata duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository.unlocked(),
        playbackSessionFactory: () => _FakePlaybackSession(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final seekBarWidget = tester.widget<PlayerSeekBar>(
      find.byType(PlayerSeekBar),
    );
    expect(seekBarWidget.duration, Duration.zero);
    expect(seekBarWidget.enabled, isFalse);
    expect(seekBarWidget.isPassiveTrack, isTrue);
  });

  testWidgets(
    'EP02 and EP03 metadata duration enables seek before media duration',
    (tester) async {
      final playbackSession = _FakePlaybackSession();

      await tester.pumpWidget(
        _buildPlayerApp(
          repository: _FakePlayerFeedRepository._(
            items: _itemsWithAccessPattern([
              _EpisodeAccessFixture.free(
                1,
                _mockVideoUrl,
                duration: const Duration(seconds: 105),
              ),
              _EpisodeAccessFixture.free(
                2,
                _mockSecondVideoUrl,
                duration: const Duration(seconds: 90),
              ),
              _EpisodeAccessFixture.free(
                3,
                _mockThirdVideoUrl,
                duration: const Duration(seconds: 95),
              ),
            ]),
          ),
          playbackSessionFactory: () => playbackSession,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();

      var seekBarWidget = tester.widget<PlayerSeekBar>(
        find.byType(PlayerSeekBar),
      );
      expect(find.text('EP.02'), findsOneWidget);
      expect(seekBarWidget.duration, const Duration(seconds: 90));
      expect(seekBarWidget.enabled, isTrue);

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();

      seekBarWidget = tester.widget<PlayerSeekBar>(find.byType(PlayerSeekBar));
      expect(find.text('EP.03'), findsOneWidget);
      expect(seekBarWidget.duration, const Duration(seconds: 95));
      expect(seekBarWidget.enabled, isTrue);
    },
  );

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

  testWidgets('membership episode sends non-member to recharge sheet', (
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

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
    expect(find.text('Membership'), findsNothing);
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

  testWidgets(
    'returning from auto membership route restores locked episode action',
    (tester) async {
      await tester.pumpWidget(
        _buildPlayerApp(
          initialLocation: RoutePaths.playerLocation(
            dramaId: 'drama-a',
            episodeId: '2',
          ),
          repository: _FakePlayerFeedRepository.membershipLocked(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      for (var i = 0; i < 30; i += 1) {
        if (find.text('Membership').evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Membership'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('EP.02'), findsOneWidget);
      expect(find.text('Member unlock'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player_unlock_button')),
        findsOneWidget,
      );
    },
  );

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

  testWidgets(
    'coin unlock sheet toggle updates shared auto unlock preference',
    (tester) async {
      await tester.pumpWidget(
        _buildPlayerApp(
          initialLocation: RoutePaths.playerLocation(
            dramaId: 'drama-a',
            episodeId: '2',
          ),
          repository: _FakePlayerFeedRepository.normal(),
          entitlementRepository:
              MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(
        const ValueKey('player_coin_unlock_auto_next_switch'),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(switchFinder));
      expect(
        container.read(entitlementControllerProvider).autoUnlockEnabled,
        isTrue,
      );
    },
  );

  testWidgets('coin episode auto unlock enabled auto deducts and plays', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final toast = RecordingAppToastService();
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
        toastService: toast,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _pumpAutoUnlockSheet(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsNothing,
    );
    expect(toast.successes, contains('Unlocked automatically'));
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
  });

  testWidgets('coin episode enough balance with auto off shows coin dialog', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession(emitWidthOnOpen: false);
    final toast = RecordingAppToastService();
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
        toastService: toast,
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
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('player_coin_unlock_auto_next_switch')),
          )
          .value,
      isFalse,
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

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_info')),
      findsOneWidget,
    );
    expect(find.text('Price:'), findsOneWidget);
    expect(find.text('Balance:'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_balance')),
      findsOneWidget,
    );
    expect(find.text('10'), findsOneWidget);
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

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );

    await _pumpAutoUnlockSheet(tester);

    expect(find.text('EP.02'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
  });

  testWidgets('auto unlock sheet can reappear after leaving dismissed item', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        repository: _FakePlayerFeedRepository._(
          items: _itemsWithAccessPattern([
            _EpisodeAccessFixture.free(1, _mockVideoUrl),
            _EpisodeAccessFixture.locked(2, _mockSecondVideoUrl),
            _EpisodeAccessFixture.free(3, _mockThirdVideoUrl),
          ]),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await _pumpAutoUnlockSheet(tester);

    expect(find.text('EP.02'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('EP.03'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 500));
    await _pumpAutoUnlockSheet(tester);

    expect(find.text('EP.02'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
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

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
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
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsNothing,
      );

      await tester.fling(find.byType(PageView), const Offset(0, -700), 1600);
      await _pumpAutoUnlockSheet(tester);

      expect(find.text('EP.03'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsOneWidget,
      );
      expect(playbackSession.openedSources, [_mockVideoUrl]);
    },
  );

  testWidgets(
    'coin tap keeps recharge drawer and stacks payment method sheet',
    (tester) async {
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
      await _pumpAutoUnlockSheet(tester);

      await tester.tap(
        find.byKey(const ValueKey('player_recharge_coin_coins_300')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player_recharge_offer_sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player_recharge_payment_sheet')),
        findsOneWidget,
      );
      expect(find.text('Payment method'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player_recharge_coin_coins_300')),
        findsOneWidget,
      );
    },
  );

  testWidgets('closing payment sheet returns to recharge drawer', (
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
    await _pumpAutoUnlockSheet(tester);

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_coin_coins_300')),
    );
    await _pumpPaymentMethodSheet(tester);
    expect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_payment_close')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_recharge_coin_coins_300')),
      findsOneWidget,
    );
  });

  testWidgets(
    'payment method dismiss before purchase returns dismissed result',
    (tester) async {
      bool? dismissedResult;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PlayerPaymentMethodModalLayer(
                sessionKey: 'single-a',
                selection: PlayerPaymentSelection.coin(
                  const PlayerRechargeCoinPackage(
                    id: '100',
                    baseCoins: 300,
                    bonusCoins: 0,
                    googleProductId: 'coins_300',
                    googlePriceLabel: r'$2.99',
                  ),
                ),
                onDismissed: (result) => dismissedResult = result,
                onPurchaseSuccess: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('player_recharge_payment_close')),
      );
      await tester.pumpAndSettle();

      expect(dismissedResult, isNull);

      dismissedResult = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PlayerPaymentMethodModalLayer(
                key: const ValueKey('barrier_dismiss_layer'),
                sessionKey: 'single-a',
                selection: PlayerPaymentSelection.coin(
                  const PlayerRechargeCoinPackage(
                    id: '100',
                    baseCoins: 300,
                    bonusCoins: 0,
                    googleProductId: 'coins_300',
                    googlePriceLabel: r'$2.99',
                  ),
                ),
                onDismissed: (result) => dismissedResult = result,
                onPurchaseSuccess: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(dismissedResult, isNull);
    },
  );

  testWidgets('coin package purchase continues to coin unlock confirmation', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final toast = RecordingAppToastService();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.normal(),
        playbackSessionFactory: () => playbackSession,
        toastService: toast,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_coin_coins_300')),
    );
    await _pumpPaymentMethodSheet(tester);

    expect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
      findsOneWidget,
    );
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('300 Coins'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player_recharge_payment_sheet')),
        matching: find.text(r'$2.99'),
      ),
      findsOneWidget,
    );
    final paymentSheetRect = tester.getRect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
    );
    final paymentCloseRect = tester.getRect(
      find.byKey(const ValueKey('player_recharge_payment_close')),
    );
    expect(paymentCloseRect.left, greaterThanOrEqualTo(paymentSheetRect.left));
    expect(paymentCloseRect.right, lessThanOrEqualTo(paymentSheetRect.right));
    expect(paymentCloseRect.top, greaterThanOrEqualTo(paymentSheetRect.top));

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_payment_buy_now')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_recharge_payment_buy_now')),
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
    final balanceText = tester.widget<Text>(
      find.byKey(const ValueKey('player_coin_unlock_balance')),
    );
    expect(balanceText.textSpan!.toPlainText(), contains('340'));
    await tester.tap(find.byKey(const ValueKey('player_coin_unlock_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('player_coin_unlock_confirm')),
      findsNothing,
    );
    expect(toast.successes, contains('Unlock successful'));
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
    await _pumpPaymentMethodSheet(tester);

    expect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player_recharge_payment_sheet')),
        matching: find.text('Weekly VIP'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_payment_buy_now')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player_recharge_payment_buy_now')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
  });

  testWidgets('cancelled player payment sheet offers purchase again', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(playerRechargeUnlockControllerProvider('single-a').notifier)
        .close();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerPaymentMethodSheet(
              sessionKey: 'single-a',
              selection: PlayerPaymentSelection.coin(
                const PlayerRechargeCoinPackage(
                  id: '100',
                  baseCoins: 300,
                  bonusCoins: 0,
                  googleProductId: 'coins_300',
                  googlePriceLabel: r'$2.99',
                ),
              ),
              onDismiss: () {},
              onPurchaseSuccess: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Payment canceled'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('player_recharge_payment_buy_now')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('payment loading disables player route pop gesture', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: '/for-you',
        repository: _FakePlayerFeedRepository.unlocked(),
        providerOverrides: [
          paymentLoadingControllerProvider.overrideWith(
            _InitiallyLoadingPaymentLoadingController.new,
          ),
        ],
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PlayerPage),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopScope && widget.canPop == false,
        ),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('membership package success from recharge sheet plays episode', (
    tester,
  ) async {
    final playbackSession = _FakePlaybackSession();
    final toast = RecordingAppToastService();
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.playerLocation(
          dramaId: 'drama-a',
          episodeId: '2',
        ),
        repository: _FakePlayerFeedRepository.membershipLocked(),
        playbackSessionFactory: () => playbackSession,
        toastService: toast,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Member unlock'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_membership_weekly_vip_promo')),
    );
    await _pumpPaymentMethodSheet(tester);
    expect(
      find.byKey(const ValueKey('player_recharge_payment_sheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('player_recharge_payment_buy_now')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
    expect(toast.successes, contains('Membership activated'));
    expect(
      find.byKey(const ValueKey('player_video_tap_layer')),
      findsOneWidget,
    );
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

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
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
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
    expect(playbackSession.pauseCount, greaterThan(0));
    expect(playbackSession.openedSources, [_mockVideoUrl]);

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );

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

      if (find
          .byKey(const ValueKey('player_recharge_unlock_close'))
          .evaluate()
          .isNotEmpty) {
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
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsOneWidget,
      );
      expect(playbackSession.openedSources, [_mockVideoUrl]);

      await tester.tap(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsNothing,
      );

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await _pumpAutoUnlockSheet(tester);

      expect(find.text('EP.03'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player_recharge_unlock_close')),
        findsOneWidget,
      );
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
    await _expandPlayerDetailSheet(tester);
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Unlock Now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );

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
    await _expandPlayerDetailSheet(tester);
    await tester.tap(find.text('2'));
    await _pumpAutoUnlockSheet(tester);

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
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
    await _expandPlayerDetailSheet(tester);
    await tester.tap(find.text('2'));
    await _pumpAutoUnlockSheet(tester);
    final pauseCountAfterLock = playbackSession.pauseCount;

    await tester.tap(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(playbackSession.pauseCount, pauseCountAfterLock);
    expect(playbackSession.playCount, 0);

    await _pumpAutoUnlockSheet(tester);

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player_unlock_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );
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

      await _pumpUntilSessionOpened(tester, playbackSession);
      playbackSession.emitDuration(const Duration(seconds: 100));
      playbackSession.emitPosition(const Duration(seconds: 100));
      playbackSession.emitPlaying(true);
      await tester.pump();
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

    await _pumpUntilSessionOpened(tester, playbackSession);
    playbackSession.emitDuration(const Duration(seconds: 100));
    playbackSession.emitPosition(const Duration(seconds: 100));
    playbackSession.emitPlaying(true);
    await tester.pump();
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

  testWidgets(
    'single drama starts at requested episode and swipes back in order',
    (tester) async {
      await tester.pumpWidget(
        _buildPlayerApp(
          initialLocation: RoutePaths.playerLocation(
            dramaId: 'drama-a',
            episodeId: '2',
          ),
          repository: _FakePlayerFeedRepository.unlocked(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('EP.02'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('EP.01'), findsOneWidget);
      expect(find.text('EP.03'), findsNothing);
    },
  );

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
    await _expandPlayerDetailSheet(tester);
    await tester.tap(find.text('2'));
    await _pumpAutoUnlockSheet(tester);
    expect(find.text('Unlock Now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_recharge_unlock_close')),
      findsNothing,
    );
    expect(find.text('Unlock Now'), findsOneWidget);

    expect(find.text('EP.02'), findsOneWidget);
    expect(find.text('A Life That Shines Again >'), findsOneWidget);
  });

  testWidgets('detail sheet opens compact and toggles expand/shrink', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_detail_sheet_expand')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player_detail_sheet_shrink')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_expand')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_detail_sheet_shrink')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_shrink')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_detail_sheet_expand')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_close')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerDetailSheet), findsNothing);
  });

  testWidgets('More opens Synopsis tab and Episodes opens Episodes tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerApp(repository: _FakePlayerFeedRepository.unlocked()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More').first);
    await tester.pumpAndSettle();
    expect(find.text('More Like This'), findsOneWidget);
    expect(find.text('1-30'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('player_detail_sheet_close')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    expect(find.text('1-30'), findsOneWidget);
    expect(find.text('More Like This'), findsNothing);
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

  testWidgets('exit recommendation play replaces current player route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakePlayerFeedRepository._(
      items: _itemsWithAccessPattern([
        _EpisodeAccessFixture.free(1, _mockVideoUrl),
        _EpisodeAccessFixture.free(2, _mockSecondVideoUrl),
        _EpisodeAccessFixture.free(3, _mockThirdVideoUrl),
      ]),
    );
    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.home,
        repository: repository,
        initialExitRecommendationsForTesting: _popupExitRecommendations(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Player'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player_exit_recommendation_dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('player_exit_recommendation_play_button')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.lastSingleDramaId, '101');

    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_back_button')), findsNothing);
  });

  testWidgets('exit recommendation cover tap plays selected recommendation', (
    tester,
  ) async {
    PopupExitRecommendation? playedRecommendation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerExitRecommendationDialog(
            recommendations: _popupExitRecommendations(),
            onExit: () {},
            onPlay: (recommendation) {
              playedRecommendation = recommendation;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('player_exit_recommendation_cover_tap_target')),
    );

    expect(playedRecommendation?.id, 101);
  });

  testWidgets('exit recommendation tags only render labels that fit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const recommendations = [
      PopupExitRecommendation(
        id: 101,
        sort: 0,
        coverUrl: '',
        title: 'Recommended Drama 101',
        summary: 'Summary 101',
        tagsName: [
          'mother_in_law_conflict',
          'spy_war',
          'counterattack',
          'plot_twist',
          'secret_identity',
        ],
        categoryNames: ['Drama'],
        playCount: 1000,
        trailerEpisodeNum: 1,
        isVipOnly: 0,
        status: 1,
        episodeTotal: 10,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerExitRecommendationDialog(
            recommendations: recommendations,
            onExit: () {},
            onPlay: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('mother_in_law_conflict'), findsOneWidget);
    expect(find.text('spy_war'), findsOneWidget);
    expect(find.text('secret_identity'), findsNothing);
  });

  testWidgets('shown exit recommendation skips future recommendation request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final popupRepository = _RecordingExitRecommendationPopupRepository(
      recommendations: _popupExitRecommendations(),
    );
    final historyRepository =
        SharedPreferencesPlayerExitRecommendationHistoryRepository();
    final repository = _FakePlayerFeedRepository._(
      items: _itemsWithAccessPattern([
        _EpisodeAccessFixture.free(1, _mockVideoUrl),
        _EpisodeAccessFixture.free(2, _mockSecondVideoUrl),
        _EpisodeAccessFixture.free(3, _mockThirdVideoUrl),
      ]),
    );

    await tester.pumpWidget(
      _buildPlayerApp(
        initialLocation: RoutePaths.home,
        repository: repository,
        initialExitRecommendationsForTesting: _popupExitRecommendations(),
        providerOverrides: [
          popupRepositoryProvider.overrideWithValue(popupRepository),
          playerExitRecommendationHistoryRepositoryProvider.overrideWithValue(
            historyRepository,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Player'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player_exit_recommendation_dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('player_exit_recommendation_exit_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(popupRepository.exitRecommendationCalls, 0);

    await tester.tap(find.text('Open Player'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(popupRepository.exitRecommendationCalls, 0);
    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player_exit_recommendation_dialog')),
      findsNothing,
    );
  });
}

double _topBarOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.byKey(const ValueKey('player_top_bar_opacity')).first,
  );
  return opacity.opacity;
}

Future<void> _expandPlayerDetailSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('player_detail_sheet_expand')));
  await tester.pumpAndSettle();
}

Future<void> _pumpAutoUnlockSheet(WidgetTester tester) async {
  for (var i = 0; i < 80; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(Duration.zero);
    if (find
            .byKey(const ValueKey('player_recharge_unlock_close'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const ValueKey('player_coin_unlock_confirm'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const ValueKey('player_video_tap_layer'))
            .evaluate()
            .isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpPaymentMethodSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump(Duration.zero);
}

Future<void> _pumpUntilSingleDramaPlaybackReady(WidgetTester tester) async {
  await tester.pump();
  for (var attempt = 0; attempt < 120; attempt++) {
    if (find
        .byKey(const ValueKey('player_video_tap_layer'))
        .evaluate()
        .isNotEmpty) {
      return;
    }
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpUntilSessionOpened(
  WidgetTester tester,
  _FakePlaybackSession session,
) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    if (session.openedSources.isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Playback session did not open a source');
}

Future<void> _doubleTapVideo(WidgetTester tester) async {
  final tapTarget = find.byKey(const ValueKey('player_video_tap_layer'));
  await tester.tap(tapTarget);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tap(tapTarget);
}

const _testAutoImmersiveDelay = Duration(milliseconds: 100);

final _singleDramaAutoImmersiveTestOverrides = [
  playerChromeAutoImmersiveConfigOverrideProvider.overrideWithValue(
    const PlayerChromeAutoImmersiveConfig(
      autoImmersiveDelay: _testAutoImmersiveDelay,
      enableAutoImmersiveForSingleDrama: true,
    ),
  ),
];

/// 避免 `pumpAndSettle` 期间误触发自动沉浸。
final _singleDramaAutoImmersiveDisabledOverrides = [
  playerChromeAutoImmersiveConfigOverrideProvider.overrideWithValue(
    const PlayerChromeAutoImmersiveConfig(
      autoImmersiveDelay: Duration(hours: 1),
      enableAutoImmersiveForSingleDrama: true,
    ),
  ),
];

class _InitiallyLoadingPaymentLoadingController
    extends PaymentLoadingController {
  @override
  PaymentLoadingState build() => const PaymentLoadingState(
    isVisible: true,
    label: PaymentLoadingLabel.confirmingPayment,
  );
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
  List providerOverrides = const [],
  PlayerPerformancePolicy? performancePolicy,
  RecordingAppToastService? toastService,
  List<PopupExitRecommendation>? initialExitRecommendationsForTesting,
  int? initialExitRecommendationPopupIdForTesting,
  bool useDefaultRemoteDataSource = true,
}) {
  final toast = toastService ?? RecordingAppToastService();
  final effectivePreloadManager =
      preloadManager ??
      MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero);
  final router = GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Home'),
              TextButton(
                onPressed: () => context.push(
                  RoutePaths.playerLocation(dramaId: 'drama-a', episodeId: '1'),
                ),
                child: const Text('Open Player'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.player,
        builder: (context, state) {
          final dramaId = state.pathParameters['dramaId']!;
          return PlayerPage(
            dramaId: dramaId,
            episodeId: state.pathParameters['episodeId']!,
            forYouHandoff: state.extra is ForYouPlayerHandoff
                ? state.extra! as ForYouPlayerHandoff
                : null,
            initialExitRecommendationsForTesting: dramaId == 'drama-a'
                ? initialExitRecommendationsForTesting
                : null,
            initialExitRecommendationPopupIdForTesting: dramaId == 'drama-a'
                ? initialExitRecommendationPopupIdForTesting
                : null,
          );
        },
      ),
      GoRoute(
        path: '/for-you',
        builder: (context, state) => const PlayerPage.forYou(),
      ),
      GoRoute(
        path: RoutePaths.search,
        builder: (context, state) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Center(child: Text('Search')),
        ),
      ),
      GoRoute(
        path: RoutePaths.membership,
        name: RouteNames.membership,
        builder: (context, state) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Text('Membership'),
        ),
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
        effectivePreloadManager,
      ),
      playerPlaybackSourceRepositoryProvider.overrideWithValue(
        MockPlayerPlaybackSourceRepository(
          preloadManager: effectivePreloadManager,
        ),
      ),
      playbackProgressRepositoryProvider.overrideWithValue(
        InMemoryPlaybackProgressRepository(),
      ),
      if (useDefaultRemoteDataSource)
        playerRemoteDataSourceProvider.overrideWithValue(
          _FakePlayerRemoteDataSource(watchProgress: null),
        ),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        NoopPlayerPlaybackPrepareManager.new,
      ),
      if (performancePolicy != null)
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          performancePolicy,
        ),
      appToastProvider.overrideWithValue(toast),
      ...appModalRegistryOverrides,
      ...providerOverrides,
    ],
    child: MaterialApp.router(
      builder: (context, child) => AppModalHost(child: child),
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

class _RecordingExitRecommendationPopupRepository implements PopupRepository {
  _RecordingExitRecommendationPopupRepository({required this.recommendations});

  final List<PopupExitRecommendation> recommendations;
  int exitRecommendationCalls = 0;

  @override
  Future<List<PopupConfig>> fetchPopups({
    required PopupPlacementCode placement,
  }) async {
    return const [];
  }

  @override
  Future<PopupExitRecommendationSet> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  }) async {
    exitRecommendationCalls += 1;
    return PopupExitRecommendationSet(recommendations: recommendations);
  }

  @override
  Future<void> reportPopupEvent({
    required int popupId,
    required PopupEventType eventType,
  }) async {}
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
  String? lastSingleDramaId;
  String? lastSingleDramaEpisodeId;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    lastSingleDramaId = dramaId;
    lastSingleDramaEpisodeId = episodeId;
    if (shouldThrowOnce) {
      shouldThrowOnce = false;
      throw StateError('failed');
    }
    if (shouldReturnEmpty) {
      return const [];
    }

    return items;
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

class _FakePlayerRemoteDataSource extends PlayerRemoteDataSource {
  _FakePlayerRemoteDataSource({
    required this.watchProgress,
    this.delay = Duration.zero,
  }) : super(apiClient: ApiClient());

  final WatchProgressDto? watchProgress;
  final Duration delay;
  final List<int> followedDramaIds = [];
  final List<int> unfollowedDramaIds = [];

  @override
  Future<void> followShort({required int dramaId}) async {
    followedDramaIds.add(dramaId);
  }

  @override
  Future<void> unfollowShort({required int dramaId}) async {
    unfollowedDramaIds.add(dramaId);
  }

  @override
  Future<WatchProgressDto?> fetchWatchProgress({required int dramaId}) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return watchProgress;
  }

  @override
  Future<bool> checkShortFollowStatus({required int dramaId}) async {
    return false;
  }

  @override
  Future<void> reportWatchProgress({
    required bool autoUnlockNext,
    required int dramaId,
    required int durationSecond,
    int? episodeId,
    required int episodeNo,
    required int eventType,
    required int watchSecond,
  }) async {}
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
        duration: fixture.duration,
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
    this.duration,
  });

  factory _EpisodeAccessFixture.free(
    int number,
    String videoUrl, {
    Duration? duration,
  }) {
    return _EpisodeAccessFixture(
      number: number,
      videoUrl: videoUrl,
      isLocked: false,
      duration: duration,
    );
  }

  factory _EpisodeAccessFixture.locked(
    int number,
    String videoUrl, {
    EpisodeUnlockType unlockType = EpisodeUnlockType.coins,
    int requiredCoins = 60,
    Duration? duration,
  }) {
    return _EpisodeAccessFixture(
      number: number,
      videoUrl: videoUrl,
      isLocked: true,
      unlockType: unlockType,
      requiredCoins: requiredCoins,
      duration: duration,
    );
  }

  final int number;
  final String videoUrl;
  final bool isLocked;
  final EpisodeUnlockType unlockType;
  final int requiredCoins;
  final Duration? duration;
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
    episodeTotal: episodes.length,
  );
}

List<PlayerFeedItem> _numericDramaItems() {
  return _items()
      .map((item) {
        final content = item.content;
        return PlayerFeedItem(
          id: item.id,
          mode: item.mode,
          content: PlayerContent(
            id: '42',
            title: content.title,
            playTitle: content.playTitle,
            synopsis: content.synopsis,
            viewCountLabel: content.viewCountLabel,
            likeCountLabel: content.likeCountLabel,
            backgroundAssetPath: content.backgroundAssetPath,
            posterAssetPath: content.posterAssetPath,
            coverUrl: content.coverUrl,
            episodes: content.episodes,
            recommendations: content.recommendations,
            tags: content.tags,
            playCount: content.playCount,
            favoriteCount: content.favoriteCount,
            likeCountDelta: content.likeCountDelta,
            episodeTotal: content.episodeTotal,
            recommendationsStatus: content.recommendationsStatus,
          ),
          episode: item.episode,
        );
      })
      .toList(growable: false);
}

String _likeIconAsset(WidgetTester tester, Finder likeButton) {
  final image = tester.widget<Image>(
    find.descendant(of: likeButton, matching: find.byType(Image)),
  );
  return (image.image as AssetImage).assetName;
}

List<PopupExitRecommendation> _popupExitRecommendations() {
  return List<PopupExitRecommendation>.generate(5, (index) {
    final id = 101 + index;
    return PopupExitRecommendation(
      id: id,
      sort: index,
      coverUrl: '',
      title: 'Recommended Drama $id',
      summary: 'Summary $id',
      tagsName: const ['Romance'],
      categoryNames: const ['Drama'],
      playCount: 1000 + index,
      trailerEpisodeNum: 1,
      isVipOnly: 0,
      status: 1,
      episodeTotal: 10,
    );
  });
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
  final openStartPositions = <Duration?>[];
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

  void emitPlaying(bool isPlaying) {
    _playingController.add(isPlaying);
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
  Future<void> open(
    String source, {
    bool play = true,
    Duration? start,
    Map<String, String>? httpHeaders,
  }) async {
    openedSources.add(source);
    openStartPositions.add(start);
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
