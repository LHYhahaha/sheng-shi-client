import 'package:drama_client/app/app.dart';
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
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
