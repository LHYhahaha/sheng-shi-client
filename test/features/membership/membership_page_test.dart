import 'package:drama_client/features/membership/presentation/pages/membership_page.dart';
import 'package:drama_client/features/membership/presentation/widgets/membership_plan_card.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('membership page layout', () {
    testWidgets('shows hero, plans, benefits and tips', (tester) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Join Membership'), findsOneWidget);
      expect(find.text('10M+ users upgraded'), findsOneWidget);
      expect(find.text('Weekly VIP'), findsOneWidget);
      expect(find.text('Monthly VIP'), findsOneWidget);
      expect(find.text('Yearly VIP'), findsOneWidget);
      expect(find.text('VIP Benefits'), findsOneWidget);
      expect(find.text('Tips'), findsOneWidget);
      expect(
        find.byKey(const Key('membership_benefits_panel')),
        findsOneWidget,
      );
      expect(find.text('Join Now'), findsNothing);
    });

    testWidgets('weekly is selected by default', (tester) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(_planBorderColor(tester, 'weekly_vip'), const Color(0xFFD6BE94));
      expect(
        _planBorderColor(tester, 'monthly_vip'),
        Colors.white.withValues(alpha: 0.24),
      );
      expect(_planDailyBarColor(tester, 'weekly_vip'), const Color(0xFFFADEB7));
    });

    testWidgets('tapping monthly selects it and opens confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MembershipPlanCard.planKey('monthly_vip')));
      await tester.pumpAndSettle();

      expect(
        _planBorderColor(tester, 'weekly_vip'),
        Colors.white.withValues(alpha: 0.24),
      );
      expect(_planBorderColor(tester, 'monthly_vip'), const Color(0xFFD6BE94));
      expect(
        _planDailyBarColor(tester, 'monthly_vip'),
        const Color(0xFFFADEB7),
      );
      expect(find.text('Confirm membership'), findsOneWidget);
    });
  });

  group('membership purchase flow', () {
    testWidgets('membership purchase success closes and reopens idle', (
      tester,
    ) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly VIP'));
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

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Mock purchase completed.'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Join Membership'), findsOneWidget);
      expect(find.text('Confirm membership'), findsNothing);

      await tester.tap(find.text('Yearly VIP'));
      await tester.pumpAndSettle();

      expect(
        find.text('This is a mock membership confirmation for MVP testing.'),
        findsOneWidget,
      );
    });

    testWidgets('membership purchase cancel closes on done', (tester) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weekly VIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Mock purchase cancelled.'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm membership'), findsNothing);
    });
  });
}

Color _planBorderColor(WidgetTester tester, String planId) {
  final card = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(MembershipPlanCard.planKey(planId)),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (card.decoration! as BoxDecoration).border!.top.color;
}

Color _planDailyBarColor(WidgetTester tester, String planId) {
  final bar = tester.widget<ColoredBox>(
    find.descendant(
      of: find.byKey(MembershipPlanCard.planKey(planId)),
      matching: find.byType(ColoredBox),
    ),
  );
  return bar.color;
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
