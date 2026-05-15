import 'dart:async';

import 'package:drama_client/app/app.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app smoke flow covers core tabs and entry pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerPlaybackSessionFactoryProvider.overrideWithValue(
            _SmokePlaybackSession.new,
          ),
          playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
            NoopPlayerPlaybackPrepareManager.new,
          ),
        ],
        child: const DramaClientApp(),
      ),
    );
    await _settle(tester);

    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('bottom_nav_forYou')));
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    await tester.drag(find.byType(PageView).first, const Offset(0, -420));
    await _settle(tester);
    expect(find.text('Watch Now'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('bottom_nav_home')));
    await _tap(tester, find.byKey(const ValueKey('home_drama_card_0')));
    expect(find.text('EP.01'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player_back_button')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('bottom_nav_home')), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('bottom_nav_myList')));
    expect(find.text('Collection list'), findsOneWidget);
    expect(find.text('Play list'), findsOneWidget);
    await _tap(tester, find.text('Play list'));
    expect(find.text('Collection list'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('bottom_nav_profile')));
    expect(find.text('Log in >'), findsOneWidget);
    await _tap(tester, find.text('Log in >'));
    expect(find.text('Sign in with Google'), findsOneWidget);
    await _tap(tester, find.text('Sign in with Google'));
    expect(find.text('Google User'), findsOneWidget);
    expect(find.text('Log in >'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('profile_top_up_entry')));
    expect(find.text('Store'), findsOneWidget);
    await _tap(tester, find.byIcon(Icons.chevron_left_rounded).first);
    expect(find.text('Google User'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('profile_membership_entry')));
    expect(find.text('Join Membership'), findsOneWidget);
    await _tap(tester, find.byIcon(Icons.chevron_left_rounded).first);
    expect(find.text('Google User'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('profile_wallet_entry')));
    expect(find.text('My Wallet'), findsWidgets);
    await _tap(tester, find.byIcon(Icons.chevron_left_rounded).first);
    expect(find.text('Google User'), findsOneWidget);

    await _stabilizePlayerTeardown(tester);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // Video surface 在真机上可能持续派发帧，`pumpAndSettle` 会被原生纹理拖住。
  // smoke 只验证核心路径是否能走通，所以这里使用有界 pump。
  for (var i = 0; i < 12; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    _takeKnownMediaKitTeardownException(tester);
  }
}

Future<void> _stabilizePlayerTeardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  _takeKnownMediaKitTeardownException(tester);
  await _waitForPlayerSurfaceDetached(tester);
}

Future<void> _waitForPlayerSurfaceDetached(WidgetTester tester) async {
  await tester.pump(
    PlayerPlaybackController.videoSurfaceTeardownDelay +
        const Duration(milliseconds: 150),
  );
  _takeKnownMediaKitTeardownException(tester);
  for (var i = 0; i < 3; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    _takeKnownMediaKitTeardownException(tester);
  }
}

void _takeKnownMediaKitTeardownException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }
  if (_isKnownMediaKitTeardownException(exception)) {
    _logIgnoredMediaKitTeardown(exception);
    return;
  }
  throw exception;
}

bool _isKnownMediaKitTeardownException(Object exception) {
  final message = exception.toString();
  return message.contains(
        'ValueNotifier<Rect?> was used after being disposed',
      ) ||
      message.contains('[Player] has been disposed');
}

void _logIgnoredMediaKitTeardown(Object exception) {
  // media_kit_video Android native resize/wid 回调偶尔会晚于测试卸载树到达。
  // 产品代码已经 pause/release；这里仅在 smoke 中清理这两个精确 teardown
  // 异常，普通播放错误仍继续抛出。
  debugPrint(
    'Ignored media_kit_video Android late callback during smoke teardown: '
    '$exception',
  );
}

class _SmokePlaybackSession implements PlayerPlaybackSession {
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
