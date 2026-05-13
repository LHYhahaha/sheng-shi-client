import 'package:drama_client/app/app.dart';
import 'package:drama_client/features/store/presentation/pages/store_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Found You,Hea'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('switches between bottom navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    expect(find.text('Collection list'), findsOneWidget);
    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Log in >'), findsOneWidget);
    expect(find.text('Wallet >'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('opens wallet from profile coins card', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();

    expect(find.text('My Wallet'), findsWidgets);
    expect(find.text('Balance and wallet actions come in M5.'), findsOneWidget);
  });

  testWidgets('opens membership from profile and confirms mock purchase', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 186));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);
    expect(find.text('Weekly VIP'), findsOneWidget);
    expect(find.text('VIP Benefits'), findsOneWidget);

    await tester.tap(find.text('Monthly VIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm membership'), findsOneWidget);
    expect(
      find.text('This is a mock membership confirmation for MVP testing.'),
      findsOneWidget,
    );
  });

  testWidgets('returns from membership to profile with top back button', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 186));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('returns from home VIP membership entry back to home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_vip_entry')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
  });

  testWidgets('opens for you player feed and swipes to next item', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('For you'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('My Secret Deal With The Playboy'), findsOneWidget);
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Found You, Heart Thief'), findsOneWidget);
  });

  testWidgets('opens home drama as single drama feed and swipes episodes', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(110, 260));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('EP.01'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets('opens language settings from profile', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('changes app locale from language settings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
  });

  testWidgets('enters collection edit mode from the header menu', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete (0)'), findsOneWidget);

    await tester.tap(find.text('Raja Iblis Hidup Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Delete (1)'), findsOneWidget);
  });

  testWidgets('reveals play list delete action before deleting', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play list'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);

    await tester.drag(
      find.text('Raja Iblis Hidup Kembali'),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);
    expect(find.text('Delete'), findsWidgets);

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Raja Iblis Hidup Kembali'), findsNothing);
  });

  testWidgets('closes play list delete action when tapping elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play list'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Raja Iblis Hidup Kembali'),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsWidgets);

    await tester.tapAt(const Offset(24, 250));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);
  });

  testWidgets('store page shows packages and confirmation sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StorePage(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('Weekly VIP'), findsWidgets);

    await tester.tap(find.text(r'$ 29.99').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm purchase'), findsOneWidget);
    expect(
      find.text('This is a mock confirmation for MVP testing.'),
      findsOneWidget,
    );
  });
}
