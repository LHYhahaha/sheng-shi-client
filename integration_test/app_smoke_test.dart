import 'package:drama_client/app/app.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app smoke flow covers core tabs and entry pages', (
    tester,
  ) async {
    MediaKit.ensureInitialized();

    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
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
  await tester.pump(const Duration(milliseconds: 300));
  _takeKnownMediaKitTeardownException(tester);
}

void _takeKnownMediaKitTeardownException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }
  final message = exception.toString();
  final isKnownMediaKitTeardown =
      message.contains('ValueNotifier<Rect?> was used after being disposed') ||
      message.contains('[Player] has been disposed');
  if (isKnownMediaKitTeardown) {
    // media_kit_video Android native resize/wid 回调偶尔会晚于测试卸载树到达。
    // 产品代码已经 pause/release；这里仅在 smoke 中清理这两个精确 teardown
    // 异常，普通播放错误仍继续抛出。
    debugPrint(
      'Ignored media_kit_video Android late callback during smoke teardown: '
      '$message',
    );
    return;
  }
  throw exception;
}
