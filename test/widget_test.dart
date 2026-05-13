import 'package:drama_client/app/app.dart';
import 'package:flutter/material.dart';
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
    expect(find.text('Language'), findsOneWidget);
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
}
