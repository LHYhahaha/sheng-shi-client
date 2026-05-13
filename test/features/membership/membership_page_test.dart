import 'package:drama_client/features/membership/presentation/pages/membership_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('membership purchase success closes and reopens idle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildMembershipPage());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly VIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm membership'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(find.text('Processing mock purchase...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Mock purchase completed.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);
    expect(find.text('Confirm membership'), findsNothing);

    await tester.tap(find.text('Yearly VIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Now'));
    await tester.pumpAndSettle();

    expect(
      find.text('This is a mock membership confirmation for MVP testing.'),
      findsOneWidget,
    );
    expect(find.text('Mock purchase completed.'), findsNothing);
  });

  testWidgets('membership purchase cancel closes on done', (tester) async {
    await tester.pumpWidget(_buildMembershipPage());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Mock purchase cancelled.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);
    expect(find.text('Confirm membership'), findsNothing);
  });
}

Widget _buildMembershipPage() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MembershipPage(),
    ),
  );
}
