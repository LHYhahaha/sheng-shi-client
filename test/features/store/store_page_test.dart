import 'package:drama_client/core/modal/app_modal_provider.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:drama_client/features/store/data/store_repository_provider.dart';
import 'package:drama_client/features/store/domain/store_package.dart';
import 'package:drama_client/features/store/domain/store_repository.dart';
import 'package:drama_client/features/store/presentation/modal/store_modal_channels.dart';
import 'package:drama_client/features/store/presentation/pages/store_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/toast/recording_app_toast_service.dart';
import '../../helpers/app_modal_test_harness.dart';
import '../../helpers/recording_app_modal_service.dart';

void main() {
  testWidgets('store confirmation opens and can be cancelled', (tester) async {
    await tester.pumpWidget(_buildStorePage());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Buy Now'), findsNothing);

    await tester.tap(find.text('2000').first);
    await tester.pumpAndSettle();

    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('Order details:'), findsOneWidget);
    expect(find.text('Total:'), findsOneWidget);
    expect(find.text('Buy now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app_payment_close')));
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Payment method'), findsNothing);
  });

  testWidgets('store confirmation opens via AppModalService channel', (
    tester,
  ) async {
    final modal = RecordingAppModalService();
    await tester.pumpWidget(_buildStorePage(modalService: modal));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Buy Now'), findsNothing);

    await tester.tap(find.text('2000').first);
    await tester.pumpAndSettle();

    expect(modal.requests, isNotEmpty);
    final request = modal.requests.last;
    expect(request, isA<FeatureAppModalRequest>());
    expect(
      (request as FeatureAppModalRequest).channel,
      StoreModalChannels.purchaseConfirmation,
    );
    expect(request.source, AppModalSource.store);
  });

  testWidgets('store restore uses app toast not snackbar', (tester) async {
    final toast = RecordingAppToastService();
    await tester.pumpWidget(_buildStorePage(toastService: toast));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(toast.infos, contains('Restore is unavailable right now'));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(ScaffoldMessenger), findsWidgets);
  });

  testWidgets('payment loading disables store route pop gesture', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildStorePage(
        overrides: [
          paymentLoadingControllerProvider.overrideWith(
            _InitiallyLoadingPaymentLoadingController.new,
          ),
        ],
      ),
    );

    expect(
      find.descendant(
        of: find.byType(StorePage),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopScope && widget.canPop == false,
        ),
      ),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(StorePage), findsOneWidget);
  });
}

Widget _buildStorePage({
  RecordingAppToastService? toastService,
  RecordingAppModalService? modalService,
  List overrides = const [],
}) {
  final toast = toastService ?? RecordingAppToastService();
  return buildAppModalTestApp(
    home: const StorePage(),
    overrides: [
      storeRepositoryProvider.overrideWithValue(const _FakeStoreRepository()),
      appToastProvider.overrideWithValue(toast),
      if (modalService != null)
        appModalServiceProvider.overrideWithValue(modalService),
      ...overrides,
    ],
  );
}

class _InitiallyLoadingPaymentLoadingController
    extends PaymentLoadingController {
  @override
  bool build() => true;
}

class _FakeStoreRepository implements StoreRepository {
  const _FakeStoreRepository();

  @override
  Future<StoreRechargeData> fetchRechargeData() async {
    return const StoreRechargeData(
      balance: 60,
      coinPackages: [
        StorePackage(
          id: 'coins_2000',
          kind: StorePackageKind.coins,
          title: '2000',
          baseCoins: 2000,
          priceLabel: r'$19.99',
        ),
      ],
      vipPackages: [
        StorePackage(
          id: 'weekly_vip',
          kind: StorePackageKind.vip,
          title: 'Weekly VIP',
          priceLabel: r'$14.99',
        ),
      ],
      tips: StoreTips(
        linksLabel: 'Privacy policy',
        subscriptionNote: 'Auto renew. Cancel anytime.',
        items: ['Prices may vary by region.'],
      ),
    );
  }
}
