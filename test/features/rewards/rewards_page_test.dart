import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/domain/entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:drama_client/features/rewards/application/member_points_controller.dart';
import 'package:drama_client/features/rewards/data/reward_coins_repository_provider.dart';
import 'package:drama_client/features/rewards/data/member_points_repository_provider.dart';
import 'package:drama_client/features/rewards/data/dto/member_point_daily_detail_dto.dart';
import 'package:drama_client/features/rewards/domain/member_point_claim_result.dart';
import 'package:drama_client/features/rewards/domain/member_point_daily_detail.dart';
import 'package:drama_client/features/rewards/domain/member_point_details.dart';
import 'package:drama_client/features/rewards/domain/member_point_exchange_options.dart';
import 'package:drama_client/features/rewards/domain/member_point_exchange_result.dart';
import 'package:drama_client/features/rewards/domain/member_points_repository.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_status.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_claim_result.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_repository.dart';
import 'package:drama_client/features/rewards/domain/reward_task.dart';
import 'package:drama_client/features/rewards/presentation/pages/member_point_details_page.dart'
    as member_point_details;
import 'package:drama_client/features/rewards/presentation/pages/member_points_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_coins_page.dart';
import 'package:drama_client/features/rewards/presentation/pages/rewards_page.dart';
import 'package:drama_client/features/membership/presentation/membership_route_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

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
      ProviderScope(
        overrides: [
          rewardCoinsRepositoryProvider.overrideWithValue(
            const _FakeRewardCoinsRepository(
              status: RewardCoinsCheckInStatus(
                checkedToday: true,
                currentDay: 4,
                days: [
                  RewardCoinsCheckInDay(
                    checked: true,
                    claimable: false,
                    current: false,
                    day: 1,
                    rewardCoin: '5',
                  ),
                  RewardCoinsCheckInDay(
                    checked: true,
                    claimable: false,
                    current: false,
                    day: 2,
                    rewardCoin: '10',
                  ),
                  RewardCoinsCheckInDay(
                    checked: true,
                    claimable: false,
                    current: false,
                    day: 3,
                    rewardCoin: '15',
                  ),
                  RewardCoinsCheckInDay(
                    checked: false,
                    claimable: false,
                    current: true,
                    day: 4,
                    rewardCoin: '20',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RewardsCoinsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('rewards_coins_page'))),
    );

    expect(find.byKey(const Key('rewards_coins_balance')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text(l10n.rewardsCoinBalanceCurrent), findsOneWidget);
    expect(
      find.byKey(const Key('rewards_coins_check_in_panel')),
      findsOneWidget,
    );
    expect(find.text(l10n.rewardsSigninDaysCount(4)), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text(l10n.rewardsSigninDayIndex(4)), findsOneWidget);
    expect(find.byKey(const Key('rewards_coins_sign_in')), findsOneWidget);
    final signInButton = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('rewards_coins_sign_in')),
            matching: find.byType(Container),
          )
          .last,
    );
    expect(
      (signInButton.decoration! as BoxDecoration).color,
      const Color(0xFF696A6E),
    );
    expect(find.text('Earn Rewards'), findsOneWidget);
    expect(
      find.byKey(const Key('reward_task_coin.bind_account')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reward_task_coin.share_drama')),
      findsOneWidget,
    );
    expect(find.text(l10n.rewardsTaskWatch5), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rewards coins rules button opens reward rules sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardCoinsRepositoryProvider.overrideWithValue(
            _FakeRewardCoinsRepository(status: _rewardCoinsStatus()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RewardsCoinsPage())),
      ),
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
    expect(
      find.byKey(const Key('member_points_action_redeem_1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('member_points_action_redeem_2')),
      findsNothing,
    );
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

  testWidgets('non-member points redemption uses server options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMemberPointsRepository(
      exchangeOptions: const MemberPointExchangeOptions(
        balance: 1200,
        isMember: false,
        list: [
          MemberPointExchangeTier(
            canExchange: true,
            displayName: 'Server 3-Day Pass',
            exchangeStatus: 'available',
            memberDays: 3,
            pointCost: 1200,
            priority: 1,
            status: 1,
            tierId: 3,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(states: [_nonMemberEntitlement()]),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server 3-Day Pass'), findsOneWidget);
    expect(find.text('3-Day Membership'), findsNothing);

    final exchangeButton = find.byKey(
      const Key('member_points_action_redeem_3'),
    );
    await tester.ensureVisible(exchangeButton);
    await tester.tap(exchangeButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('member_points_exchange_confirm_dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points redemption keeps server order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMemberPointsRepository(
      exchangeOptions: const MemberPointExchangeOptions(
        balance: 138,
        isMember: false,
        list: [
          MemberPointExchangeTier(
            canExchange: false,
            displayName: '兑换23日会员',
            exchangeStatus: 'not_member',
            memberDays: 23,
            pointCost: 23,
            priority: 3232323,
            status: 1,
            tierId: 8,
          ),
          MemberPointExchangeTier(
            canExchange: false,
            displayName: '兑换2日会员',
            exchangeStatus: 'not_member',
            memberDays: 2,
            pointCost: 2,
            priority: 2,
            status: 1,
            tierId: 5,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(states: [_nonMemberEntitlement()]),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('兑换23日会员')).dy,
      lessThan(tester.getTopLeft(find.text('兑换2日会员')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-member points redemption shows when daily detail fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMemberPointsRepository(
      dailyDetailError: StateError('not member'),
      exchangeOptions: const MemberPointExchangeOptions(
        balance: 138,
        isMember: false,
        list: [
          MemberPointExchangeTier(
            canExchange: false,
            displayName: '兑换23日会员',
            exchangeStatus: 'not_member',
            memberDays: 23,
            pointCost: 23,
            priority: 1,
            status: 1,
            tierId: 8,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(states: [_nonMemberEntitlement()]),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('兑换23日会员'), findsOneWidget);
    expect(
      find.byKey(const Key('member_points_action_redeem_8')),
      findsOneWidget,
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

  testWidgets('member points refreshes after membership purchase return', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final memberPointsRepository = _FakeMemberPointsRepository();
    final entitlementRepository = _FakeEntitlementRepository(
      states: [_nonMemberEntitlement(), _memberEntitlement(pointBalance: 5)],
    );
    final router = GoRouter(
      initialLocation: '/member-points-test',
      routes: [
        GoRoute(
          path: '/member-points-test',
          builder: (context, state) => const MemberPointsPage(),
        ),
        GoRoute(
          path: RoutePaths.membership,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    context.pop(MembershipRouteResult.purchaseCompleted),
                child: const Text('Complete purchase'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(
            memberPointsRepository,
          ),
          entitlementRepositoryProvider.overrideWithValue(
            entitlementRepository,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(memberPointsRepository.dailyDetailCallCount, 1);
    expect(entitlementRepository.fetchStateCallCount, 1);
    expect(find.byKey(const Key('member_points_join_now')), findsOneWidget);

    await tester.tap(find.byKey(const Key('member_points_join_now')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete purchase'));
    await tester.pumpAndSettle();

    expect(memberPointsRepository.dailyDetailCallCount, 2);
    expect(entitlementRepository.fetchStateCallCount, 2);
    expect(find.byKey(const Key('member_points_join_now')), findsNothing);
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
    final entitlementRepository = _FakeEntitlementRepository(
      states: [_memberEntitlement(pointBalance: 5)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(
            _FakeMemberPointsRepository(),
          ),
          entitlementRepositoryProvider.overrideWithValue(
            entitlementRepository,
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
    expect(entitlementRepository.fetchStateCallCount, 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('member_points_page'))),
    );
    expect(container.read(entitlementControllerProvider).totalPointBalance, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points watch task claims when daily detail completed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMemberPointsRepository(
      tasks: [_watchTask(completed: true)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(
              states: [
                _memberEntitlement(pointBalance: 0),
                _memberEntitlement(pointBalance: 5),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('member_points_action_play_reward')),
    );
    await tester.tap(find.byKey(const Key('member_points_action_play_reward')));
    await tester.pumpAndSettle();

    expect(repository.claimedTaskKeys, ['point.watch.30m']);
    expect(find.text('Claimed Successfully'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member points push task claims when notifications are enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugRequestMemberPointsNotificationPermission = () async => true;
    addTearDown(debugResetMemberPointsNotificationPermission);
    final repository = _FakeMemberPointsRepository(tasks: [_pushTask()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(
              states: [
                _memberEntitlement(pointBalance: 0),
                _memberEntitlement(pointBalance: 5),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: MemberPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('member_points_action_enable_push')),
    );
    await tester.tap(find.byKey(const Key('member_points_action_enable_push')));
    await tester.pumpAndSettle();

    expect(repository.claimedTaskKeys, ['point.enable_push']);
    expect(find.text('Claimed Successfully'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'member points notification permission claims when already granted',
    () async {
      var requestCallCount = 0;
      var firebaseRequestCallCount = 0;
      var openSettingsCallCount = 0;
      debugGetMemberPointsNotificationPermissionStatus = () async =>
          permissions.PermissionStatus.granted;
      debugRequestMemberPointsNotificationPermissionStatus = () async {
        requestCallCount++;
        return permissions.PermissionStatus.denied;
      };
      debugRequestMemberPointsFirebaseNotificationPermission = () async {
        firebaseRequestCallCount++;
        return false;
      };
      debugOpenMemberPointsNotificationSettings = () async {
        openSettingsCallCount++;
        return true;
      };
      addTearDown(debugResetMemberPointsNotificationPermission);

      expect(await debugRequestMemberPointsNotificationPermission(), isTrue);
      expect(requestCallCount, 0);
      expect(firebaseRequestCallCount, 0);
      expect(openSettingsCallCount, 0);
    },
  );

  test('member points notification permission requests when denied', () async {
    var requestCallCount = 0;
    var firebaseRequestCallCount = 0;
    var openSettingsCallCount = 0;
    debugGetMemberPointsNotificationPermissionStatus = () async =>
        permissions.PermissionStatus.denied;
    debugRequestMemberPointsNotificationPermissionStatus = () async {
      requestCallCount++;
      return permissions.PermissionStatus.denied;
    };
    debugRequestMemberPointsFirebaseNotificationPermission = () async {
      firebaseRequestCallCount++;
      return true;
    };
    debugOpenMemberPointsNotificationSettings = () async {
      openSettingsCallCount++;
      return true;
    };
    addTearDown(debugResetMemberPointsNotificationPermission);

    expect(await debugRequestMemberPointsNotificationPermission(), isTrue);
    expect(firebaseRequestCallCount, 1);
    expect(requestCallCount, 0);
    expect(openSettingsCallCount, 0);
  });

  test(
    'member points notification permission stays denied when request is denied',
    () async {
      var requestCallCount = 0;
      var firebaseRequestCallCount = 0;
      var openSettingsCallCount = 0;
      debugGetMemberPointsNotificationPermissionStatus = () async =>
          permissions.PermissionStatus.denied;
      debugRequestMemberPointsNotificationPermissionStatus = () async {
        requestCallCount++;
        return permissions.PermissionStatus.denied;
      };
      debugRequestMemberPointsFirebaseNotificationPermission = () async {
        firebaseRequestCallCount++;
        return false;
      };
      debugOpenMemberPointsNotificationSettings = () async {
        openSettingsCallCount++;
        return true;
      };
      addTearDown(debugResetMemberPointsNotificationPermission);

      expect(await debugRequestMemberPointsNotificationPermission(), isFalse);
      expect(firebaseRequestCallCount, 1);
      expect(requestCallCount, 1);
      expect(openSettingsCallCount, 1);
    },
  );

  test(
    'member points notification permission falls back when Firebase is unavailable',
    () async {
      var requestCallCount = 0;
      var firebaseRequestCallCount = 0;
      var openSettingsCallCount = 0;
      debugGetMemberPointsNotificationPermissionStatus = () async =>
          permissions.PermissionStatus.denied;
      debugRequestMemberPointsNotificationPermissionStatus = () async {
        requestCallCount++;
        return permissions.PermissionStatus.granted;
      };
      debugRequestMemberPointsFirebaseNotificationPermission = () async {
        firebaseRequestCallCount++;
        throw StateError('No Firebase App');
      };
      debugOpenMemberPointsNotificationSettings = () async {
        openSettingsCallCount++;
        return true;
      };
      addTearDown(debugResetMemberPointsNotificationPermission);

      expect(await debugRequestMemberPointsNotificationPermission(), isTrue);
      expect(firebaseRequestCallCount, 1);
      expect(requestCallCount, 1);
      expect(openSettingsCallCount, 0);
    },
  );

  test(
    'member points notification permission does not request after permanent denial',
    () async {
      var requestCallCount = 0;
      var firebaseRequestCallCount = 0;
      var openSettingsCallCount = 0;
      debugGetMemberPointsNotificationPermissionStatus = () async =>
          permissions.PermissionStatus.permanentlyDenied;
      debugRequestMemberPointsNotificationPermissionStatus = () async {
        requestCallCount++;
        return permissions.PermissionStatus.granted;
      };
      debugRequestMemberPointsFirebaseNotificationPermission = () async {
        firebaseRequestCallCount++;
        return true;
      };
      debugOpenMemberPointsNotificationSettings = () async {
        openSettingsCallCount++;
        return true;
      };
      addTearDown(debugResetMemberPointsNotificationPermission);

      expect(await debugRequestMemberPointsNotificationPermission(), isFalse);
      expect(requestCallCount, 0);
      expect(firebaseRequestCallCount, 0);
      expect(openSettingsCallCount, 1);
    },
  );

  testWidgets('member points watch task shows toast when not completed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMemberPointsRepository(
      tasks: [_watchTask(completed: false, canClaim: true)],
    );
    final botToastBuilder = BotToastInit();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            _FakeEntitlementRepository(
              states: [_memberEntitlement(pointBalance: 0)],
            ),
          ),
        ],
        child: MaterialApp(
          builder: botToastBuilder,
          navigatorObservers: [BotToastNavigatorObserver()],
          home: const MemberPointsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('member_points_action_play_reward')),
    );
    await tester.tap(find.byKey(const Key('member_points_action_play_reward')));
    await tester.pumpAndSettle();

    expect(repository.claimedTaskKeys, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(const Key('app_center_toast')),
        matching: find.text('(＞ 30 min)'),
      ),
      findsOneWidget,
    );
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
    final entitlementRepository = _FakeEntitlementRepository(
      states: [
        _memberEntitlement(pointBalance: 1000),
        _memberEntitlement(pointBalance: 0),
      ],
    );
    final botToastBuilder = BotToastInit();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(repository),
          entitlementRepositoryProvider.overrideWithValue(
            entitlementRepository,
          ),
        ],
        child: MaterialApp(
          builder: botToastBuilder,
          navigatorObservers: [BotToastNavigatorObserver()],
          home: const MemberPointsPage(),
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
    expect(entitlementRepository.fetchStateCallCount, 1);
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
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('member_points_exchange_confirm_points')),
          )
          .data,
      '1000',
    );
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
    expect(entitlementRepository.fetchStateCallCount, 2);
    expect(container.read(entitlementControllerProvider).totalPointBalance, 0);
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

  testWidgets('member point details shows configured empty text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberPointsRepositoryProvider.overrideWithValue(
            _FakeMemberPointsRepository(details: const []),
          ),
        ],
        child: const MaterialApp(
          home: member_point_details.MemberPointDetailsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No records'), findsOneWidget);
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
    this.dailyDetailError,
    this.exchangeOptions,
    this.exchangeCompleter,
    this.tasks = const [],
    this.details,
  });

  final String detailRemark;
  final Object? dailyDetailError;
  final MemberPointExchangeOptions? exchangeOptions;
  final Completer<MemberPointExchangeResult>? exchangeCompleter;
  final List<MemberPointTask> tasks;
  final List<MemberPointDetailRecord>? details;
  final List<String> claimedTaskKeys = [];
  int dailyDetailCallCount = 0;
  int exchangeCallCount = 0;

  @override
  Future<MemberPointDailyDetail> getDailyDetail() async {
    dailyDetailCallCount++;
    final error = dailyDetailError;
    if (error != null) throw error;
    return MemberPointDailyDetail(
      dayProgress: const [],
      memberDay: 7,
      tasks: tasks,
      totalAvailablePoint: 0,
      totalPointBalance: 0,
    );
  }

  @override
  Future<MemberPointClaimResult> claimReward({required String taskKey}) async {
    claimedTaskKeys.add(taskKey);
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
    return exchangeOptions ??
        const MemberPointExchangeOptions(
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
    final detailRecords = details;
    if (detailRecords != null) {
      return MemberPointDetailsPage(
        list: detailRecords,
        page: page,
        pageSize: pageSize,
        totalNum: detailRecords.length,
      );
    }

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

class _FakeRewardCoinsRepository implements RewardCoinsRepository {
  const _FakeRewardCoinsRepository({required this.status});

  final RewardCoinsCheckInStatus status;

  @override
  Future<RewardCoinsCheckInStatus> getCheckInStatus() async => status;

  @override
  Future<RewardCoinsCheckInClaimResult> claimCheckIn() {
    throw UnimplementedError();
  }

  @override
  Future<RewardCoinsCheckInClaimResult> claimTask({required String taskKey}) {
    throw UnimplementedError();
  }

  @override
  Future<List<RewardTask>> getTasks({required int rewardType}) async =>
      _rewardCoinTasks();

  @override
  Future<void> reportTaskAction({required String actionKey}) async {}
}

List<RewardTask> _rewardCoinTasks() => const [
  RewardTask(
    claimed: true,
    completed: true,
    conditionText: '',
    cycleType: 'TASK_CYCLE_TYPE_ONCE',
    displayName: '',
    progressValue: 1,
    rewardMax: 10,
    rewardMin: 10,
    rewardType: 'REWARD_TYPE_BONUS_COIN',
    targetValue: 1,
    taskKey: 'coin.bind_account',
  ),
  RewardTask(
    claimed: false,
    completed: false,
    conditionText: '',
    cycleType: 'TASK_CYCLE_TYPE_ONCE',
    displayName: '',
    progressValue: 0,
    rewardMax: 10,
    rewardMin: 10,
    rewardType: 'REWARD_TYPE_BONUS_COIN',
    targetValue: 1,
    taskKey: 'coin.share_drama',
  ),
  RewardTask(
    claimed: false,
    completed: false,
    conditionText: '',
    cycleType: 'TASK_CYCLE_TYPE_DAILY',
    displayName: '',
    progressValue: 0,
    rewardMax: 10,
    rewardMin: 10,
    rewardType: 'REWARD_TYPE_BONUS_COIN',
    targetValue: 5,
    taskKey: 'coin.watch.5m',
  ),
];

RewardCoinsCheckInStatus _rewardCoinsStatus() {
  return const RewardCoinsCheckInStatus(
    checkedToday: false,
    currentDay: 2,
    days: [
      RewardCoinsCheckInDay(
        checked: true,
        claimable: false,
        current: false,
        day: 1,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: true,
        current: true,
        day: 2,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: false,
        current: false,
        day: 3,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: false,
        current: false,
        day: 4,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: false,
        current: false,
        day: 5,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: false,
        current: false,
        day: 6,
        rewardCoin: '10',
      ),
      RewardCoinsCheckInDay(
        checked: false,
        claimable: false,
        current: false,
        day: 7,
        rewardCoin: '10',
      ),
    ],
  );
}

MemberPointTask _watchTask({required bool completed, bool canClaim = false}) {
  return MemberPointTask(
    canClaim: canClaim,
    claimed: false,
    claimedRewardAmount: 0,
    completed: completed,
    conditionText: '',
    displayName: 'Watch over 30 mins',
    progressValue: completed ? 30 : 0,
    rewardMax: 5,
    rewardMin: 5,
    targetValue: 30,
    taskKey: 'point.watch.30m',
  );
}

MemberPointTask _pushTask() {
  return const MemberPointTask(
    canClaim: true,
    claimed: false,
    claimedRewardAmount: 0,
    completed: true,
    conditionText: '',
    displayName: 'Turn push notification',
    progressValue: 1,
    rewardMax: 5,
    rewardMin: 5,
    targetValue: 1,
    taskKey: 'point.enable_push',
  );
}

UserEntitlementState _nonMemberEntitlement() {
  return const UserEntitlementState(
    isGuest: false,
    isMember: false,
    coinBalance: 20,
    bonusBalance: 0,
    totalPointBalance: 0,
    autoUnlockEnabled: false,
    unlockedEpisodeIds: <String>{},
  );
}

UserEntitlementState _memberEntitlement({required int pointBalance}) {
  return UserEntitlementState(
    isGuest: false,
    isMember: true,
    coinBalance: 20,
    bonusBalance: 0,
    totalPointBalance: pointBalance,
    autoUnlockEnabled: false,
    unlockedEpisodeIds: const <String>{},
  );
}

class _FakeEntitlementRepository implements EntitlementRepository {
  _FakeEntitlementRepository({required List<UserEntitlementState> states})
    : _states = states;

  final List<UserEntitlementState> _states;
  int fetchStateCallCount = 0;

  UserEntitlementState get _currentState => _stateAt(fetchStateCallCount - 1);

  UserEntitlementState _stateAt(int rawIndex) {
    if (_states.isEmpty) {
      return _memberEntitlement(pointBalance: 0);
    }
    final index = rawIndex < 0
        ? 0
        : rawIndex >= _states.length
        ? _states.length - 1
        : rawIndex;
    return _states[index];
  }

  @override
  Future<UserEntitlementState> fetchState() async {
    final state = _stateAt(fetchStateCallCount);
    fetchStateCallCount++;
    return state;
  }

  @override
  Future<UserEntitlementState> setAutoUnlockEnabled(bool enabled) async {
    return _currentState.copyWith(autoUnlockEnabled: enabled);
  }

  @override
  Future<UserEntitlementState> grantMockMembership({
    required String source,
  }) async {
    return _currentState.copyWith(isGuest: false, isMember: true);
  }

  @override
  Future<UserEntitlementState> grantMockCoins({
    required int amount,
    required String source,
  }) async {
    return _currentState.copyWith(
      coinBalance: _currentState.coinBalance + amount,
    );
  }

  @override
  Future<UserEntitlementState> unlockEpisodeWithCoins({
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  }) async {
    return _currentState.copyWith(
      coinBalance: _currentState.coinBalance - price,
      unlockedEpisodeIds: <String>{
        ..._currentState.unlockedEpisodeIds,
        episodeId,
      },
    );
  }
}
