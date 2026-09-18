import 'package:drama_client/features/membership/application/membership_controller.dart';
import 'package:drama_client/features/membership/data/membership_repository_provider.dart';
import 'package:drama_client/features/membership/domain/membership_plan.dart';
import 'package:drama_client/features/membership/domain/membership_repository.dart';
import 'package:drama_client/features/pay/application/iap_price_service.dart';
import 'package:drama_client/features/pay/provider/iap_price_service_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class _Repository implements MembershipRepository {
  bool fail = false;
  List<MembershipPlan> plans = [];
  @override
  Future<MembershipData> fetchMembership() async {
    if (fail) throw StateError('backend unavailable');
    return MembershipData(
      isActive: false,
      heroTitle: '',
      heroSubtitle: '',
      plans: plans,
    );
  }
}

class _Billing implements IapPriceService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Map<String, dynamic>? extractPromoInfo(ProductDetails product) => null;
  bool available = true;
  bool fail = false;
  Map<String, ProductDetails> products = {};
  @override
  Future<bool> isStoreAvailable() async => available;
  @override
  Future<Map<String, ProductDetails>> queryProducts({
    required Set<String> productIds,
  }) async {
    if (fail) throw StateError('billing query failed');
    return products;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late _Billing billing;
  late ProviderContainer container;
  setUp(() {
    repository = _Repository();
    billing = _Billing();
    container = ProviderContainer(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(repository),
        iapPriceServiceProvider.overrideWithValue(billing),
      ],
    );
    addTearDown(container.dispose);
  });
  MembershipPlan plan(String id) => MembershipPlan(
    id: id,
    title: id,
    priceLabel: '',
    dailyPriceLabel: '',
    platformProductId: id,
  );
  Future<MembershipState> load() async {
    await container.read(membershipControllerProvider.notifier).load();
    return container.read(membershipControllerProvider);
  }

  test('backend request failure is request_failed', () async {
    repository.fail = true;
    expect((await load()).vipProductLoadResult?.result, 'request_failed');
  });
  test('empty backend catalog is empty', () async {
    expect((await load()).vipProductLoadResult?.result, 'empty');
  });
  test('missing Google services is google_request_failed', () async {
    repository.plans = [plan('a')];
    billing.available = false;
    expect(
      (await load()).vipProductLoadResult?.result,
      'google_request_failed',
    );
  });
  test('missing Google products is google_request_failed', () async {
    repository.plans = [plan('a')];
    expect(
      (await load()).vipProductLoadResult?.result,
      'google_request_failed',
    );
  });
  test('Google query exception is google_request_failed', () async {
    repository.plans = [plan('a')];
    billing.fail = true;
    expect(
      (await load()).vipProductLoadResult?.result,
      'google_request_failed',
    );
  });
  test('iOS Apple catalog price replaces the backend display price', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    repository.plans = [
      const MembershipPlan(
        id: 'vip.monthly',
        title: 'Backend title',
        priceLabel: r'US$99.99',
        dailyPriceLabel: r'US$3.33',
        platformProductId: 'vip.monthly',
        payChannel: 'PAY_CHANNEL_APPLE',
      ),
    ];
    billing.products = {
      'vip.monthly': ProductDetails(
        id: 'vip.monthly',
        title: 'VIP Monthly',
        description: '',
        price: r'$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
    };

    final state = await load();

    expect(state.plans.single.priceLabel, r'$4.99');
    expect(state.plans.single.title, 'VIP Monthly');
  });
  test('iOS introductory price is exposed as a promotion', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final locale = SKPriceLocaleWrapper(
      currencySymbol: r'$',
      currencyCode: 'USD',
      countryCode: 'US',
    );
    final product = AppStoreProductDetails.fromSKProduct(
      SKProductWrapper(
        productIdentifier: 'vip.monthly',
        localizedTitle: 'VIP Monthly',
        localizedDescription: '',
        priceLocale: locale,
        price: '9.99',
        introductoryPrice: SKProductDiscountWrapper(
          price: '1.99',
          priceLocale: locale,
          numberOfPeriods: 1,
          paymentMode: SKProductDiscountPaymentMode.payAsYouGo,
          subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
            numberOfUnits: 1,
            unit: SKSubscriptionPeriodUnit.month,
          ),
          identifier: null,
          type: SKProductDiscountType.introductory,
        ),
      ),
    );

    final promo = IapPriceService().extractPromoInfo(product);

    expect(promo?['hasPromo'], isTrue);
    expect(promo?['promoPrice'], r'$1.99');
    expect(promo?['regularPrice'], r'$9.99');
    expect(promo?['promoPeriod'], 'P1M');
  });
  test(
    'partial catalog succeeds with only matched cards and retry has new identity',
    () async {
      repository.plans = [plan('a'), plan('b')];
      billing.products = {
        'a': ProductDetails(
          id: 'a',
          title: 'A',
          description: '',
          price: r'$1',
          rawPrice: 1,
          currencyCode: 'USD',
        ),
      };
      final first = await load();
      expect(first.vipProductLoadResult?.result, 'success');
      expect(first.plans, hasLength(1));
      await container.read(membershipControllerProvider.notifier).retry();
      expect(
        identical(
          first.vipProductLoadResult,
          container.read(membershipControllerProvider).vipProductLoadResult,
        ),
        false,
      );
    },
  );
}
