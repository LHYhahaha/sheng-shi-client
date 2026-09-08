import 'package:drama_client/features/membership/data/membership_repository_provider.dart';
import 'package:drama_client/features/membership/domain/membership_plan.dart';
import 'package:drama_client/features/membership/domain/membership_repository.dart';
import 'package:drama_client/features/membership/presentation/membership_layout.dart';
import 'package:drama_client/features/membership/presentation/pages/membership_page.dart';
import 'package:drama_client/features/membership/presentation/widgets/membership_plan_card.dart';
import 'package:drama_client/features/pay/application/iap_price_service.dart';
import 'package:drama_client/features/pay/provider/iap_price_service_provider.dart';
import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../helpers/app_modal_test_harness.dart';

void main() {
  group('membership page layout', () {
    testWidgets('tab retains scroll position when payment starts and ends', (tester) async {
      await tester.pumpWidget(_buildMembershipPage(
        home: const MembershipPage(showBackButton: false, handleBackNavigation: false),
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final list = find.byKey(const Key('membership_scroll_body'));
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(of: list, matching: find.byType(Scrollable)).first;
      final before = tester.state<ScrollableState>(scrollable);
      final offset = before.position.pixels;
      expect(offset, greaterThan(0));
      final container = ProviderScope.containerOf(tester.element(find.byType(MembershipPage)));
      final loading = container.read(paymentLoadingControllerProvider.notifier);
      loading.show();
      await tester.pump();
      expect(tester.state<ScrollableState>(scrollable), same(before));
      expect(before.position.pixels, closeTo(offset, 0.1));
      loading.hide();
      await tester.pump();
      expect(tester.state<ScrollableState>(scrollable), same(before));
      expect(before.position.pixels, closeTo(offset, 0.1));
    });

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

    testWidgets('plan cards keep the shared horizontal inset on wide screens', (
      tester,
    ) async {
      for (final width in [430.0, 480.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildMembershipPage());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(
          _weeklyCardLeft(tester),
          closeTo(MembershipLayout.horizontalPadding, 1),
        );
      }
    });

    testWidgets('plan cards keep their inset after loading and selection', (
      tester,
    ) async {
      const width = 430.0;
      await tester.binding.setSurfaceSize(const Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        _weeklyCardLeft(tester),
        closeTo(MembershipLayout.horizontalPadding, 1),
      );

      await tester.tap(find.byKey(MembershipPlanCard.planKey('monthly_vip')));
      await tester.pumpAndSettle();
      expect(
        _weeklyCardLeft(tester),
        closeTo(MembershipLayout.horizontalPadding, 1),
      );

      await tester.tap(find.byKey(const ValueKey('app_payment_close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MembershipPlanCard.planKey('yearly_vip')));
      await tester.pumpAndSettle();
      expect(
        _weeklyCardLeft(tester),
        closeTo(MembershipLayout.horizontalPadding, 1),
      );
    });

    testWidgets('weekly is selected by default', (tester) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(_planBorderColor(tester, 'weekly_vip'), const Color(0xFFD6BE94));
      expect(
        _planBorderColor(tester, 'monthly_vip'),
        Colors.white.withValues(alpha: 0.18),
      );
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
        Colors.white.withValues(alpha: 0.18),
      );
      expect(_planBorderColor(tester, 'monthly_vip'), const Color(0xFFD6BE94));
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Google Pay'), findsOneWidget);
    });

    testWidgets('payment loading disables membership route pop gesture', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildMembershipPage(
          overrides: [
            paymentLoadingControllerProvider.overrideWith(
              _InitiallyLoadingPaymentLoadingController.new,
            ),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MembershipPage),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopScope && widget.canPop == false,
          ),
        ),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(MembershipPage), findsOneWidget);
    });

    testWidgets('shows no data when Google returns no membership products', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildMembershipPage(
          repository: const _GoogleMembershipRepository(),
          overrides: [
            iapPriceServiceProvider.overrideWithValue(_EmptyIapPriceService()),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('No data'), findsOneWidget);
      expect(find.text('Weekly VIP'), findsNothing);
      expect(find.text('Join Now'), findsOneWidget);

      await tester.tap(find.text('Join Now'));
      await tester.pumpAndSettle();
      expect(find.text('Payment method'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('membership_benefits_panel')),
        320,
        scrollable: find.descendant(
          of: find.byKey(const Key('membership_scroll_body')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('membership_benefits_panel')),
        findsOneWidget,
      );
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

      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Buy now'), findsOneWidget);
    });

    testWidgets('membership purchase sheet closes from close button', (
      tester,
    ) async {
      await tester.pumpWidget(_buildMembershipPage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weekly VIP'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('app_payment_close')));
      await tester.pumpAndSettle();

      expect(find.text('Payment method'), findsNothing);
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

Widget _buildMembershipPage({
  Widget home = const MembershipPage(),
  MembershipRepository repository = const _FakeMembershipRepository(),
  List overrides = const [],
}) {
  return buildAppModalTestApp(
    home: home,
    overrides: [
      membershipRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
  );
}

class _InitiallyLoadingPaymentLoadingController
    extends PaymentLoadingController {
  @override
  PaymentLoadingState build() => const PaymentLoadingState(
    isVisible: true,
    label: PaymentLoadingLabel.confirmingPayment,
  );
}

class _FakeMembershipRepository implements MembershipRepository {
  const _FakeMembershipRepository();

  @override
  Future<MembershipData> fetchMembership() async {
    return const MembershipData(
      isActive: false,
      heroTitle: 'Join Membership',
      heroSubtitle: '10M+ users upgraded',
      plans: [
        MembershipPlan(
          id: 'weekly_vip',
          title: 'Weekly VIP',
          priceLabel: r'$14.99',
          dailyPriceLabel: r'$2.14/day',
          period: 'P1W',
        ),
        MembershipPlan(
          id: 'monthly_vip',
          title: 'Monthly VIP',
          priceLabel: r'$39.99',
          dailyPriceLabel: r'$1.33/day',
          period: 'P1M',
        ),
        MembershipPlan(
          id: 'yearly_vip',
          title: 'Yearly VIP',
          priceLabel: r'$99.99',
          dailyPriceLabel: r'$0.27/day',
          period: 'P1Y',
        ),
      ],
    );
  }
}

class _GoogleMembershipRepository implements MembershipRepository {
  const _GoogleMembershipRepository();

  @override
  Future<MembershipData> fetchMembership() async {
    return const MembershipData(
      isActive: false,
      heroTitle: 'Join Membership',
      heroSubtitle: '10M+ users upgraded',
      plans: [
        MembershipPlan(
          id: '348',
          title: 'Weekly VIP',
          priceLabel: r'$2.99',
          dailyPriceLabel: '',
          platformProductId: 'test_sub_weekly_1',
          period: 'P1W',
        ),
      ],
    );
  }
}

class _EmptyIapPriceService extends IapPriceService {
  @override
  Future<Map<String, ProductDetails>> queryProducts({
    required Set<String> productIds,
  }) async {
    return const {};
  }

  @override
  void dispose() {}
}
