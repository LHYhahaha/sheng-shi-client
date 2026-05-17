import 'package:drama_client/features/membership/presentation/membership_layout.dart';
import 'package:drama_client/features/membership/presentation/pages/membership_page.dart';
import 'package:drama_client/features/membership/presentation/widgets/membership_plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_modal_test_harness.dart';

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

    testWidgets('scroll body is clipped below hero title area', (tester) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final scrollBody = tester.widget<Positioned>(
        find.byKey(const Key('membership_scroll_body')),
      );
      expect(scrollBody.top, MembershipLayout.scrollContentTop);
      expect(
        find.descendant(
          of: find.byKey(const Key('membership_scroll_body')),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );

      final titleTop = tester.getTopLeft(find.text('Join Membership')).dy;
      expect(titleTop, lessThan(MembershipLayout.scrollContentTop));

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Join Membership')).dy,
        closeTo(titleTop, 1),
      );
      expect(find.text('Join Membership'), findsOneWidget);
    });

    testWidgets('plan cards align to figma at 375 width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Weekly VIP'), findsOneWidget);
      expect(
        _weeklyCardLeft(tester),
        closeTo(MembershipLayout.horizontalPadding, 1),
      );
    });

    testWidgets('plan cards are centered on wide screens', (tester) async {
      for (final width in [430.0, 480.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildMembershipPage());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        final expectedLeft = (width - MembershipLayout.planCardGroupWidth) / 2;
        expect(_weeklyCardLeft(tester), closeTo(expectedLeft, 1));
      }
    });

    testWidgets('plan cards stay centered after loading and selection', (
      tester,
    ) async {
      const width = 430.0;
      await tester.binding.setSurfaceSize(const Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final expectedLeft = (width - MembershipLayout.planCardGroupWidth) / 2;
      expect(_weeklyCardLeft(tester), closeTo(expectedLeft, 1));

      await tester.tap(find.byKey(MembershipPlanCard.planKey('monthly_vip')));
      await tester.pumpAndSettle();
      expect(_weeklyCardLeft(tester), closeTo(expectedLeft, 1));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MembershipPlanCard.planKey('yearly_vip')));
      await tester.pumpAndSettle();
      expect(_weeklyCardLeft(tester), closeTo(expectedLeft, 1));
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
    testWidgets('membership confirmation opens via AppModalService channel', (
      tester,
    ) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly VIP'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm membership'), findsOneWidget);
    });

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

double _weeklyCardLeft(WidgetTester tester) {
  return tester
      .getTopLeft(find.byKey(MembershipPlanCard.planKey('weekly_vip')))
      .dx;
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
  return buildAppModalTestApp(home: const MembershipPage());
}
