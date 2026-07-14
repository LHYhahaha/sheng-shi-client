import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/rewards/presentation/pages/member_points_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_coins_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

void main() {
  test('member points can be addressed as an independent rewards tab', () {
    expect(
      RoutePaths.rewardsLocation(tab: RoutePaths.memberPointsTab),
      '/rewards?tab=member-points',
    );
    expect(
      RewardTab.fromRouteValue(RoutePaths.memberPointsTab),
      RewardTab.memberPoints,
    );
  });

  testWidgets('rewards container switches between independent pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RewardsPage())),
    );

    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      RewardTab.rewardsCoins.index,
    );
    expect(_backgroundGradient(tester).colors, const [
      Color(0xFF4E370D),
      Color(0xFF121418),
    ]);
    expect(
      _tabIndicatorColor(tester, 'rewards_coins'),
      const Color(0xFFF7DFB9),
    );

    await tester.tap(find.text('Member Points'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      RewardTab.memberPoints.index,
    );
    final memberPointsBackground = _backgroundGradient(tester);
    expect(memberPointsBackground.begin, Alignment.topRight);
    expect(memberPointsBackground.end, Alignment.bottomLeft);
    expect(memberPointsBackground.stops, const [0, 0.33]);
    expect(memberPointsBackground.colors, const [
      Color(0xFF390E4E),
      Color(0xFF0E0D0F),
    ]);
    expect(
      _tabIndicatorColor(tester, 'member_points'),
      const Color(0xFFDFB6F1),
    );
  });

  testWidgets('rewards coins page shows check-in and earning tasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardsCoinsPage())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rewards_coins_balance')), findsOneWidget);
    expect(find.text('2230'), findsOneWidget);
    expect(find.text('Your Balance'), findsOneWidget);
    expect(
      find.byKey(const Key('rewards_coins_check_in_panel')),
      findsOneWidget,
    );
    expect(find.text('Check-in for Rewards'), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.byKey(const Key('rewards_coins_sign_in')), findsOneWidget);
    expect(find.text('Earn Rewards'), findsOneWidget);
    expect(find.byKey(const Key('reward_task_login')), findsOneWidget);
    expect(find.byKey(const Key('reward_task_invite')), findsOneWidget);
    expect(find.text('Watch for 5 mins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-member points page shows the subscription design', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MemberPointsPage(isMember: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_points_locked_daily')), findsOneWidget);
    expect(find.byKey(const Key('daily_rewards_rules_button')), findsOneWidget);
    expect(
      tester
          .getBottomLeft(find.byKey(const Key('daily_rewards_rules_button')))
          .dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('daily_rewards_card'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('member_points_locked_daily'))).dx,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('daily_rewards_card'))).dx,
        0.1,
      ),
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const Key('member_points_locked_daily')))
          .dy,
      closeTo(
        tester.getBottomLeft(find.byKey(const Key('daily_rewards_card'))).dy,
        0.1,
      ),
    );
    expect(find.text('Subscribe to unlock daily\nrewards'), findsOneWidget);
    expect(find.text('Join Now'), findsOneWidget);
    expect(_hasGradientBorder('member_points_join_now'), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('member_points_join_now')),
        matching: find.byKey(const Key('member_points_button_top_highlight')),
      ),
      findsOneWidget,
    );
    expect(find.text('VIP Benefits'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('vip_benefits_panel'))).dx,
      closeTo(0, 0.1),
    );
    expect(
      tester.getSize(find.byKey(const Key('vip_benefits_panel'))).width,
      closeTo(375, 0.1),
    );
    expect(
      tester
          .widget<CustomPaint>(find.byKey(const Key('vip_benefits_top_border')))
          .foregroundPainter,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points page shows check-in and task design', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MemberPointsPage(isMember: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_points_active_daily')), findsOneWidget);
    expect(find.text('Today is the 7th day as a member'), findsOneWidget);
    expect(find.text('Daily lottery draw'), findsOneWidget);
    expect(find.textContaining('Play reward'), findsOneWidget);
    expect(_hasGradientBorder('member_points_action_play_reward'), isTrue);
    expect(
      _hasGradientBorder('member_points_action_daily_lottery_draw'),
      isFalse,
    );
    expect(
      _hasTopHighlight('member_points_action_daily_lottery_draw'),
      isFalse,
    );
    expect(find.text('VIP Benefits'), findsNothing);
    final dailyPanel = tester.widget<Container>(
      find.byKey(const Key('member_points_active_daily')),
    );
    final dailyGradient =
        (dailyPanel.decoration! as BoxDecoration).gradient! as RadialGradient;
    expect(dailyGradient.center, Alignment.topRight);
    expect(dailyGradient.radius, 0.95);
    expect(dailyGradient.stops, const [0, 0.72]);
    expect(dailyGradient.colors, const [Color(0xFF390E4E), Color(0xFF0E0D0F)]);
    expect(tester.takeException(), isNull);
  });
}

LinearGradient _backgroundGradient(WidgetTester tester) {
  final background = tester.widget<AnimatedContainer>(
    find.byKey(const Key('rewards_page_background')),
  );
  return (background.decoration! as BoxDecoration).gradient! as LinearGradient;
}

Color? _tabIndicatorColor(WidgetTester tester, String tab) {
  final indicator = tester.widget<AnimatedContainer>(
    find.byKey(Key('rewards_tab_indicator_$tab')),
  );
  return (indicator.decoration! as BoxDecoration).color;
}

bool _hasGradientBorder(String key) {
  return find
      .descendant(
        of: find.byKey(Key(key)),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).border is GradientBoxBorder,
        ),
      )
      .evaluate()
      .isNotEmpty;
}

bool _hasTopHighlight(String key) {
  return find
      .descendant(
        of: find.byKey(Key(key)),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.foregroundPainter != null,
        ),
      )
      .evaluate()
      .isNotEmpty;
}
