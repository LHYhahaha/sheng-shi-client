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

/// Device verification: video surface stays visible and follows PageView drag.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('player video surface follows vertical swipe on device', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('bottom_nav_forYou')));
    await _settle(tester);

    final followSurface = find.byKey(
      const ValueKey('active_playback_surface_follow_scroll'),
    );
    expect(followSurface, findsOneWidget);

    await tester.drag(find.byType(PageView).first, const Offset(0, -520));
    await tester.pump(const Duration(milliseconds: 150));
    expect(followSurface, findsOneWidget);

    final dragOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: followSurface,
        matching: find.byKey(const ValueKey('active_playback_surface_opacity')),
      ),
    );
    expect(
      dragOpacity.opacity,
      ActivePlaybackSurfaceOverlay.scrollFollowOpacity,
    );

    final duringDrag = tester.widget<Transform>(followSurface);
    expect(duringDrag.transform.getTranslation().y, isNot(0.0));

    await _settle(tester);

    final settledOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: followSurface,
        matching: find.byKey(const ValueKey('active_playback_surface_opacity')),
      ),
    );
    expect(settledOpacity.opacity, 1.0);

    await tester.drag(find.byType(PageView).first, const Offset(0, 520));
    await _settle(tester);
    expect(followSurface, findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i += 1) {
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
    debugPrint('Ignored media_kit teardown during scroll follow test: $exception');
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
