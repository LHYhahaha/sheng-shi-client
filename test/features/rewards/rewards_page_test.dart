import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:drama_client/features/rewards/application/member_points_controller.dart';
import 'package:drama_client/features/rewards/data/member_points_repository_provider.dart';
import 'package:drama_client/features/rewards/data/dto/member_point_daily_detail_dto.dart';
import 'package:drama_client/features/rewards/domain/member_point_claim_result.dart';
import 'package:drama_client/features/rewards/domain/member_point_daily_detail.dart';
import 'package:drama_client/features/rewards/domain/member_point_details.dart';
import 'package:drama_client/features/rewards/domain/member_point_exchange_options.dart';
import 'package:drama_client/features/rewards/domain/member_point_exchange_result.dart';
import 'package:drama_client/features/rewards/domain/member_points_repository.dart';
import 'package:drama_client/features/rewards/presentation/pages/member_point_details_page.dart'
    as member_point_details;
import 'package:drama_client/features/rewards/presentation/pages/member_points_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_coins_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

    await tester.tap(find.byKey(const Key('rewards_tab_member_points')));
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

  testWidgets('rewards coins rules button opens reward rules sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardsCoinsPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rewards_coins_rules')));
    await tester.pumpAndSettle();

    expect(find.text('Reward Rules'), findsOneWidget);
    expect(find.byKey(const Key('reward_rules_content')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reward_rules_close')));
    await tester.pumpAndSettle();

    expect(find.text('Reward Rules'), findsNothing);
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
    expect(find.text('Subscribe to unlock daily rewards'), findsOneWidget);
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

  testWidgets('non-member join now pushes membership and can return', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/member-points-test',
      routes: [
        GoRoute(
          path: '/member-points-test',
          builder: (context, state) => const MemberPointsPage(isMember: false),
        ),
        GoRoute(
          path: RoutePaths.membership,
          builder: (context, state) =>
              const Scaffold(body: Text('Membership route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member_points_join_now')));
    await tester.pumpAndSettle();

    expect(find.text('Membership route'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_points_page')), findsOneWidget);
    expect(find.byKey(const Key('member_points_join_now')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily rewards header pushes point details page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/member-points-test',
      routes: [
        GoRoute(
          path: '/member-points-test',
          builder: (context, state) => const MemberPointsPage(isMember: true),
        ),
        GoRoute(
          path: RoutePaths.memberPointDetails,
          builder: (context, state) =>
              const Scaffold(body: Text('Point details route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily Rewards >'));
    await tester.pumpAndSettle();

    expect(find.text('Point details route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points rules button opens reward rules sheet', (
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

    await tester.tap(find.byKey(const Key('daily_rewards_rules_button')));
    await tester.pumpAndSettle();

    expect(find.text('Points Rules'), findsOneWidget);
    expect(find.byKey(const Key('reward_rules_content')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reward_rules_close')));
    await tester.pumpAndSettle();

    expect(find.text('Points Rules'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points claim button opens success dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(
            _FakeMemberPointsRepository(),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage(isMember: true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member_points_action_daily_lottery_draw')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Claimed Successfully'), findsOneWidget);
    expect(
      find.byKey(const Key('member_points_claim_success_image')),
      findsOneWidget,
    );
    expect(find.text('+5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('member_points_claim_success_ok')));
    await tester.pumpAndSettle();

    expect(find.text('Claimed Successfully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points exchange requires confirmation before request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final exchangeCompleter = Completer<MemberPointExchangeResult>();
    final repository = _FakeMemberPointsRepository(
      exchangeCompleter: exchangeCompleter,
    );
    final botToastBuilder = BotToastInit();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: botToastBuilder,
          navigatorObservers: [BotToastNavigatorObserver()],
          home: const MemberPointsPage(isMember: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exchangeButton = find.byKey(
      const Key('member_points_action_redeem_2'),
    );
    await tester.ensureVisible(exchangeButton);
    await tester.tap(exchangeButton);
    await tester.pumpAndSettle();

    expect(repository.exchangeCallCount, 0);
    expect(
      find.byKey(const Key('member_points_exchange_confirm_dialog')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('member_points_exchange_confirm_dialog')),
        matching: find.text('5-Day Membership'),
      ),
      findsOneWidget,
    );
    expect(find.text('1000 Member Points'), findsOneWidget);
    expect(
      find.text(
        '1. After redemption, your current membership will be extended by 5 day(s).\n'
        '2. The redeemed membership duration will take effect after your store membership ends.\n'
        '3. Redeemed items are non-refundable.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('member_points_exchange_confirm_button')),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('member_points_page'))),
    );
    expect(repository.exchangeCallCount, 1);
    expect(container.read(memberPointsControllerProvider).isExchanging, isTrue);
    expect(container.read(paymentLoadingControllerProvider).isVisible, isTrue);

    exchangeCompleter.complete(
      const MemberPointExchangeResult(
        exchangeNo: 'exchange-test',
        memberDays: 5,
        pointBalance: 0,
        status: 'CLAIM_STATUS_SUCCESS',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      container.read(memberPointsControllerProvider).isExchanging,
      isFalse,
    );
    expect(container.read(paymentLoadingControllerProvider).isVisible, isFalse);
    expect(find.text('Redeemed successfully'), findsOneWidget);
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
    expect(find.text('Today is Day 7 of your membership'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('member_daily_reward_day_3')),
        matching: find.text('??'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('member_daily_reward_day_3')),
        matching: find.text('+0'),
      ),
      findsNothing,
    );
    expect(find.text('Daily Lottery'), findsOneWidget);
    expect(find.textContaining('Watch Reward'), findsOneWidget);
    expect(find.text('Claim'), findsWidgets);
    expect(_hasGradientBorder('member_points_action_play_reward'), isTrue);
    expect(
      _hasGradientBorder('member_points_action_daily_lottery_draw'),
      isTrue,
    );
    expect(_hasTopHighlight('member_points_action_daily_lottery_draw'), isTrue);
    expect(find.text('VIP Benefits'), findsNothing);
    final dailyPanel = tester.widget<Container>(
      find.byKey(const Key('member_points_active_daily')),
    );
    final dailyDecoration = dailyPanel.decoration! as BoxDecoration;
    final dailyGradient = dailyDecoration.gradient! as LinearGradient;
    expect(dailyGradient.begin, Alignment.topCenter);
    expect(dailyGradient.end, Alignment.bottomCenter);
    expect(dailyGradient.stops, const [0, 0.35]);
    expect(dailyGradient.colors, [
      const Color(0xFF4D0071).withValues(alpha: 0.3),
      const Color(0xFF130719).withValues(alpha: 0.7),
    ]);
    final dailyBorder = dailyDecoration.border! as GradientBoxBorder;
    final borderGradient = dailyBorder.gradient as LinearGradient;
    expect(borderGradient.colors, [
      const Color(0XFFDA8AFF).withValues(alpha: 0.3),
      const Color(0XFF585858).withValues(alpha: 0.3),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member point details maps record keys to localized labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(
            _FakeMemberPointsRepository(detailRemark: 'point.watch.30m'),
          ),
        ],
        child: const MaterialApp(
          home: member_point_details.MemberPointDetailsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watch Reward'), findsOneWidget);
    expect(find.text('point.watch.30m'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('member point daily detail parses balance and claimed task reward', () {
    final detail = MemberPointDailyDetailDto.fromJson({
      'dayProgress': [
        {
          'claimedPoint': '80',
          'current': false,
          'index': 1,
          'memberDay': 1,
          'totalPoint': '80',
        },
      ],
      'memberDay': 2,
      'tasks': [
        {
          'canClaim': false,
          'claimed': true,
          'claimedRewardAmount': '5',
          'completed': true,
          'conditionText': '非首次会员每日抽奖',
          'displayName': '每日抽奖-后续',
          'progressValue': '1',
          'rewardMax': '9',
          'rewardMin': '1',
          'targetValue': '1',
          'taskKey': 'point.draw.daily',
        },
      ],
      'totalAvailablePoint': '80',
      'totalPointBalance': '85',
    }).toDomain();

    expect(detail.totalAvailablePoint, 80);
    expect(detail.totalPointBalance, 85);
    expect(detail.tasks.single.claimedRewardAmount, 5);
  });

  test('member point daily detail defaults missing point balance to zero', () {
    final detail = MemberPointDailyDetailDto.fromJson({
      'dayProgress': [],
      'memberDay': 2,
      'tasks': [],
      'totalAvailablePoint': '80',
    }).toDomain();

    expect(detail.totalAvailablePoint, 80);
    expect(detail.totalPointBalance, 0);
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

class _FakeMemberPointsRepository implements MemberPointsRepository {
  _FakeMemberPointsRepository({
    this.detailRemark = 'Daily member points',
    this.exchangeCompleter,
  });

  final String detailRemark;
  final Completer<MemberPointExchangeResult>? exchangeCompleter;
  int exchangeCallCount = 0;

  @override
  Future<MemberPointDailyDetail> getDailyDetail() async {
    return const MemberPointDailyDetail(
      dayProgress: [],
      memberDay: 7,
      tasks: [],
      totalAvailablePoint: 0,
      totalPointBalance: 0,
    );
  }

  @override
  Future<MemberPointClaimResult> claimReward({required String taskKey}) async {
    return const MemberPointClaimResult(
      claimNo: 'claim-test',
      grantedAt: '2026-07-15T00:00:00Z',
      pointBalance: 5,
      rewardAmount: 5,
      status: 'CLAIM_STATUS_SUCCESS',
    );
  }

  @override
  Future<MemberPointExchangeOptions> getExchangeOptions() async {
    return const MemberPointExchangeOptions(
      balance: 1000,
      isMember: true,
      list: [
        MemberPointExchangeTier(
          canExchange: true,
          displayName: 'Redeem 5-Day Membership',
          exchangeStatus: 'available',
          memberDays: 5,
          pointCost: 1000,
          priority: 1,
          status: 1,
          tierId: 2,
        ),
      ],
    );
  }

  @override
  Future<MemberPointExchangeResult> exchange({required int tierId}) {
    exchangeCallCount++;
    final pendingResult = exchangeCompleter;
    if (pendingResult != null) return pendingResult.future;
    return Future.value(
      const MemberPointExchangeResult(
        exchangeNo: 'exchange-test',
        memberDays: 5,
        pointBalance: 0,
        status: 'CLAIM_STATUS_SUCCESS',
      ),
    );
  }

  @override
  Future<MemberPointDetailsPage> getPointDetails({
    required int page,
    required int pageSize,
  }) async {
    return MemberPointDetailsPage(
      list: [
        MemberPointDetailRecord(
          amount: 23,
          balanceAfter: 123,
          balanceBefore: 100,
          bizType: 1,
          createdAt: DateTime.parse('2026-04-23T13:21:11Z'),
          direction: 1,
          flowNo: 'flow-test',
          remark: detailRemark,
        ),
      ],
      page: page,
      pageSize: pageSize,
      totalNum: 1,
    );
  }
}
