import 'dart:async';

import 'package:drama_client/app/app.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 真机压测：For You 播放器 + 单剧播放器 的 PageView 纵向切条/切集。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('For You PlayerPage: repeated vertical swipes', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('bottom_nav_forYou')));
    await _settle(tester);

    // 确认进入播放器页，而非首页网格
    expect(find.byType(PageView), findsWidgets);
    expect(find.text('Watch Now'), findsOneWidget);

    final issues = await _stressSwipe(
      tester,
      pageView: find.byType(PageView).first,
      label: 'for_you',
      rounds: 6,
    );
    expect(issues, isEmpty, reason: issues.join('\n'));
  });

  testWidgets('Single drama PlayerPage: repeated vertical swipes', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home_drama_card_0')));
    await _settle(tester);

    expect(find.text('EP.01'), findsOneWidget);
    expect(find.byKey(const ValueKey('player_single_top_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('player_back_button')), findsOneWidget);

    final issues = await _stressSwipe(
      tester,
      pageView: find.byType(PageView),
      label: 'single_drama',
      rounds: 6,
    );
    expect(issues, isEmpty, reason: issues.join('\n'));
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerPlaybackSessionFactoryProvider.overrideWithValue(
          _ScrollFollowSmokePlaybackSession.new,
        ),
        playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
          NoopPlayerPlaybackPrepareManager.new,
        ),
      ],
      child: const DramaClientApp(),
    ),
  );
  await _settle(tester);
}

Future<List<String>> _stressSwipe(
  WidgetTester tester, {
  required Finder pageView,
  required String label,
  required int rounds,
}) async {
  final followSurface = find.byKey(
    const ValueKey('active_playback_surface_follow_scroll'),
  );
  final issues = <String>[];

  for (var round = 0; round < rounds; round++) {
    issues.addAll(
      await _swipeOnce(
        tester,
        pageView: pageView,
        followSurface: followSurface,
        offset: const Offset(0, -560),
        tag: '${label}_up_$round',
      ),
    );
    issues.addAll(
      await _swipeOnce(
        tester,
        pageView: pageView,
        followSurface: followSurface,
        offset: const Offset(0, 560),
        tag: '${label}_down_$round',
      ),
    );
  }

  return issues;
}

Future<List<String>> _swipeOnce(
  WidgetTester tester, {
  required Finder pageView,
  required Finder followSurface,
  required Offset offset,
  required String tag,
}) async {
  final issues = <String>[];
  await tester.drag(pageView, offset);
  await tester.pump(const Duration(milliseconds: 100));

  if (followSurface.evaluate().isEmpty) {
    issues.add('$tag: video follow surface missing while dragging');
    debugPrint('PLAYER_STRESS $tag MISSING_SURFACE');
  } else {
    final y = tester
        .widget<Transform>(followSurface)
        .transform
        .getTranslation()
        .y;
    final opacity = tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: followSurface,
            matching: find.byKey(
              const ValueKey('active_playback_surface_opacity'),
            ),
          ),
        )
        .opacity;
    debugPrint(
      'PLAYER_STRESS $tag drag translateY=${y.toStringAsFixed(1)} opacity=$opacity',
    );
    if (offset.dy.abs() > 200 && y == 0) {
      issues.add('$tag: expected translate while dragging');
    }
    if (opacity != ActivePlaybackSurfaceOverlay.scrollFollowOpacity) {
      issues.add('$tag: expected dim ${ActivePlaybackSurfaceOverlay.scrollFollowOpacity}, got $opacity');
    }
  }

  await _settle(tester);

  if (followSurface.evaluate().isNotEmpty) {
    final opacity = tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: followSurface,
            matching: find.byKey(
              const ValueKey('active_playback_surface_opacity'),
            ),
          ),
        )
        .opacity;
    debugPrint('PLAYER_STRESS $tag settled opacity=$opacity');
    if (opacity != 1.0) {
      issues.add('$tag: expected opacity 1 after settle, got $opacity');
    }
  }

  _takeKnownMediaKitTeardownException(tester);
  return issues;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    _takeKnownMediaKitTeardownException(tester);
  }
}

void _takeKnownMediaKitTeardownException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }
  final message = exception.toString();
  if (message.contains('ValueNotifier<Rect?> was used after being disposed') ||
      message.contains('[Player] has been disposed')) {
    return;
  }
  throw exception;
}

class _ScrollFollowSmokePlaybackSession implements PlayerPlaybackSession {
  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  var _disposed = false;

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

  @override
  Future<void> open(String source, {bool play = true}) async {
    if (_disposed) {
      return;
    }
    _bufferingController.add(false);
    _completedController.add(false);
    _playingController.add(play);
    _durationController.add(const Duration(seconds: 100));
    _widthController.add(1280);
  }

  @override
  Future<void> pause() async {
    if (!_disposed) {
      _playingController.add(false);
    }
  }

  @override
  Future<void> play() async {
    if (!_disposed) {
      _playingController.add(true);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_disposed) {
      _positionController.add(position);
      _completedController.add(false);
    }
  }

  @override
  Future<void> setRate(double rate) async {
    if (!_disposed) {
      _rateController.add(rate);
    }
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
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
