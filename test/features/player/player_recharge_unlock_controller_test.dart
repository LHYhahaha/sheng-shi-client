import 'dart:async';

import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/pay/application/iap_purchase_service.dart';
import 'package:drama_client/features/pay/data/dto/payment_order_verify_response_dto.dart';
import 'package:drama_client/features/pay/domain/iap_product_info.dart';
import 'package:drama_client/features/pay/domain/pay_repository.dart';
import 'package:drama_client/features/pay/domain/payment_method_options.dart';
import 'package:drama_client/features/pay/domain/payment_order.dart';
import 'package:drama_client/features/pay/provider/iap_purchase_service_provider.dart';
import 'package:drama_client/features/pay/provider/pay_repository_provider.dart';
import 'package:drama_client/features/player/application/player_recharge_unlock_controller.dart';
import 'package:drama_client/features/player/data/dto/player_episode_unlock_dto.dart';
import 'package:drama_client/features/player/data/player_recharge_unlock_repository_provider.dart';
import 'package:drama_client/features/player/domain/player_recharge_unlock_offer.dart';
import 'package:drama_client/features/player/domain/player_recharge_unlock_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  test('bonus badge percent uses bonus over total coins', () {
    const package = PlayerRechargeCoinPackage(
      id: '100',
      baseCoins: 300,
      bonusCoins: 30,
      googleProductId: 'coins_300_bonus',
      googlePriceLabel: r'$2.99',
    );

    expect(package.bonusPercent, 9);
  });

  test('loads offer without embedding coin balance', () async {
    final container = _container();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    await container
        .read(provider.notifier)
        .open(itemId: 'drama-a-ep-2', requiredCoins: 60);

    final state = container.read(provider);
    expect(state.status, PlayerRechargeUnlockStatus.idle);
    expect(state.offer?.requiredCoins, 60);
    expect(state.offer?.coinPackages, hasLength(1));
    expect(state.offer?.membershipPackages, hasLength(1));
  });

  test('marks a membership episode recharge sheet as vip only', () async {
    final container = _container();
    addTearDown(container.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    await container
        .read(provider.notifier)
        .open(itemId: 'drama-a-ep-2', requiredCoins: 60, vipOnly: true);

    expect(
      container.read(provider).rechargePopupType,
      PlayerRechargePopupType.vipOnly,
    );
  });

  test('coin package verifies payment before completing purchase', () async {
    final iap = _FakeIapPurchaseService();
    final pay = _FakePayRepository();
    final container = _container(iap: iap, pay: pay);
    addTearDown(container.dispose);
    addTearDown(iap.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: '123', requiredCoins: 60);

    final purchase = controller.selectCoinPackage('100');
    expect(container.read(provider).selectedCoinPackageId, '100');
    expect(
      container.read(provider).status,
      PlayerRechargeUnlockStatus.processing,
    );

    await purchase;

    expect(container.read(provider).status, PlayerRechargeUnlockStatus.success);
    expect(pay.createdProductType, 1);
    expect(pay.verifiedOrderNo, 'order-1');
    expect(pay.verifiedProductType, 1);
    expect(pay.verifiedChannelProductId, 'coins_300_bonus');
    expect(iap.applicationUserName, 'c:client-order-1|s:order-1');
    expect(iap.completedCount, 1);
  });

  test(
    'membership package verifies payment before completing purchase',
    () async {
      final iap = _FakeIapPurchaseService();
      final pay = _FakePayRepository();
      final container = _container(iap: iap, pay: pay);
      addTearDown(container.dispose);
      addTearDown(iap.dispose);

      final provider = playerRechargeUnlockControllerProvider('single-a');
      final controller = container.read(provider.notifier);
      await controller.open(itemId: '123', requiredCoins: 60);

      final purchase = controller.selectMembershipPackage('200');
      expect(container.read(provider).selectedMembershipPackageId, '200');
      expect(
        container.read(provider).status,
        PlayerRechargeUnlockStatus.processing,
      );

      await purchase;

      expect(
        container.read(provider).status,
        PlayerRechargeUnlockStatus.success,
      );
      expect(pay.createdProductType, 2);
      expect(pay.verifiedProductType, 2);
      expect(pay.verifiedChannelProductId, 'vip_weekly_intro');
      expect(iap.completedCount, 1);
    },
  );

  test('verification failure fails purchase without completing it', () async {
    final iap = _FakeIapPurchaseService();
    final pay = _FakePayRepository(orderStatus: 'ORDER_STATUS_FAILED');
    final container = _container(iap: iap, pay: pay);
    addTearDown(container.dispose);
    addTearDown(iap.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: '123', requiredCoins: 60);

    await controller.selectCoinPackage('100');

    final state = container.read(provider);
    expect(state.status, PlayerRechargeUnlockStatus.failed);
    expect(state.error, isNotNull);
    expect(pay.verifiedOrderNo, 'order-1');
    expect(iap.completedCount, 0);
  });

  test('closing sheet cancels pending purchase completion', () async {
    final iap = _FakeIapPurchaseService(
      purchaseDelay: const Duration(milliseconds: 20),
    );
    final pay = _FakePayRepository();
    final container = _container(iap: iap, pay: pay);
    addTearDown(container.dispose);
    addTearDown(iap.dispose);

    final provider = playerRechargeUnlockControllerProvider('single-a');
    final controller = container.read(provider.notifier);
    await controller.open(itemId: '123', requiredCoins: 60);

    final purchase = controller.selectCoinPackage('100');
    controller.close();
    await purchase;

    expect(
      container.read(provider).status,
      PlayerRechargeUnlockStatus.cancelled,
    );
    expect(pay.verifiedOrderNo, isNull);
    expect(iap.completedCount, 0);
  });

  test(
    'closing an untouched sheet does not report a cancelled payment',
    () async {
      final container = _container();
      addTearDown(container.dispose);

      final provider = playerRechargeUnlockControllerProvider('single-a');
      final controller = container.read(provider.notifier);
      await controller.open(itemId: '123', requiredCoins: 60);

      controller.close();

      expect(container.read(provider).status, PlayerRechargeUnlockStatus.idle);
    },
  );
}

ProviderContainer _container({
  _FakeIapPurchaseService? iap,
  _FakePayRepository? pay,
}) {
  return ProviderContainer(
    overrides: [
      playerRechargeUnlockRepositoryProvider.overrideWithValue(
        const _FakePlayerRechargeUnlockRepository(),
      ),
      iapPurchaseServiceProvider.overrideWithValue(
        iap ?? _FakeIapPurchaseService(),
      ),
      payRepositoryProvider.overrideWithValue(pay ?? _FakePayRepository()),
      entitlementRepositoryProvider.overrideWithValue(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
      ),
    ],
  );
}

class _FakePlayerRechargeUnlockRepository
    implements PlayerRechargeUnlockRepository {
  const _FakePlayerRechargeUnlockRepository();

  @override
  Future<PlayerRechargeUnlockOffer> fetchOffer({
    required String itemId,
    required int requiredCoins,
    bool isMember = false,
  }) async {
    return PlayerRechargeUnlockOffer(
      requiredCoins: requiredCoins,
      coinPackages: [
        PlayerRechargeCoinPackage(
          id: '100',
          baseCoins: 300,
          bonusCoins: 30,
          googleProductId: 'coins_300_bonus',
          googlePriceLabel: r'$2.99',
          iapInfo: IapProductInfo(productDetails: _product('coins_300_bonus')),
        ),
      ],
      membershipPackages: isMember
          ? const []
          : [
              PlayerRechargeMembershipPackage(
                id: '200',
                periodLabel: 'Weekly',
                googleProductId: 'vip_weekly_intro',
                googlePriceLabel: r'$12.99',
                iapInfo: IapProductInfo(
                  productDetails: _product('vip_weekly_intro'),
                  offerToken: 'offer-token',
                ),
              ),
            ],
      benefits: const [
        PlayerRechargeBenefit(
          icon: PlayerRechargeBenefitIcon.series,
          label: 'Unlock dramas',
        ),
      ],
      tips: 'Coins are used to unlock paid episodes.',
    );
  }

  @override
  Future<PlayerEpisodeUnlockDto> unlockEpisodeWithCoin({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    String? cover,
    int? episodeId,
    required String requestId,
  }) async {
    return PlayerEpisodeUnlockDto(
      autoUnlock: autoUnlockNext,
      bonusCoin: 0,
      coin: 100,
      costCoin: coin,
      dramaId: dramaId,
      episodeId: episodeId ?? 1,
      success: true,
      userId: 1,
    );
  }
}

class _FakeIapPurchaseService extends IapPurchaseService {
  _FakeIapPurchaseService({this.purchaseDelay = Duration.zero})
    : super(setup: false);

  final Duration purchaseDelay;
  final _controller = StreamController<PurchaseDetails>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  int completedCount = 0;
  String? applicationUserName;

  @override
  Stream<PurchaseDetails> get purchaseStream => _controller.stream;

  @override
  Stream<Object> get purchaseErrorStream => _errorController.stream;

  @override
  Future<int> restoreAndConsumePendingPurchases({
    required String source,
    Set<String>? productIds,
    Duration waitForCallbacks = const Duration(seconds: 3),
  }) async {
    return 0;
  }

  @override
  Future<bool> buyProduct({
    required ProductDetails product,
    bool isConsumable = false,
    String? offerToken,
    String? applicationUserName,
  }) async {
    this.applicationUserName = applicationUserName;
    Future<void>.delayed(purchaseDelay, () {
      if (_controller.isClosed) {
        return;
      }
      _controller.add(_purchase(product.id, PurchaseStatus.purchased));
    });
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails details) async {
    completedCount++;
  }

  @override
  void dispose() {
    _controller.close();
    _errorController.close();
  }
}

class _FakePayRepository implements PayRepository {
  _FakePayRepository({this.orderStatus = 'ORDER_STATUS_SUCCESS'});

  final String orderStatus;
  int? createdProductType;
  String? verifiedOrderNo;
  String? verifiedChannelProductId;
  int? verifiedProductType;

  @override
  Future<PaymentMethodOptions> getPaymentOrderOptions({
    required int osType,
    required int payScene,
    required int productId,
    required int productType,
    String? countryCode,
    int? dramaId,
    int? episodeId,
    int? episodeNo,
    String? scene,
  }) async => throw UnimplementedError();

  @override
  Future<PaymentOrder> createPaymentOrder({
    required int productId,
    required int productType,
    String? clientOrderNo,
    int? episodeId,
    int? payChannel,
    String? scene,
    int? shortId,
  }) async {
    createdProductType = productType;
    return PaymentOrder(
      amountMicros: 2990000,
      channelProductId: 'channel-product',
      currency: 'USD',
      expireAt: DateTime.now().millisecondsSinceEpoch + 60000,
      orderNo: 'order-1',
      clientOrderNo: clientOrderNo ?? 'client-order-1',
      orderStatus: 'ORDER_STATUS_PENDING',
      orderTitle: 'Test order',
      payChannel: 'PAY_CHANNEL_GOOGLE',
      priceText: r'$2.99',
      productId: productId,
      productType: productType == 1
          ? 'PRODUCT_TYPE_COIN'
          : 'PRODUCT_TYPE_MEMBERSHIP',
    );
  }

  @override
  Future<PaymentOrderVerifyResponseDto> verifyGooglePayment({
    required String orderNo,
    required String channelProductId,
    required String packageName,
    required int productType,
    required String purchaseToken,
    String? channelOrderId,
    String? rawReceipt,
  }) async {
    verifiedOrderNo = orderNo;
    verifiedChannelProductId = channelProductId;
    verifiedProductType = productType;
    return PaymentOrderVerifyResponseDto(
      orderNo: orderNo,
      orderStatus: orderStatus,
      channelOrderId: channelOrderId,
      paidAt: DateTime.now(),
    );
  }
}

ProductDetails _product(String id) {
  return ProductDetails(
    id: id,
    title: id,
    description: id,
    price: r'$2.99',
    rawPrice: 2.99,
    currencyCode: 'USD',
    currencySymbol: r'$',
  );
}

PurchaseDetails _purchase(String productId, PurchaseStatus status) {
  final details = PurchaseDetails(
    purchaseID: 'purchase-1',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'purchase-token',
      source: 'google_play',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
  );
  details.pendingCompletePurchase = true;
  return details;
}
