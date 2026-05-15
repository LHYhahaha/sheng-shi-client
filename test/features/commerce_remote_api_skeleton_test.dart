import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/entitlement/data/dto/unlock_episode_response_dto.dart';
import 'package:drama_client/features/entitlement/data/dto/user_entitlement_state_dto.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mapper/entitlement_mapper.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/entitlement/data/remote/entitlement_remote_data_source.dart';
import 'package:drama_client/features/entitlement/data/remote_entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/episode_access_decision.dart';
import 'package:drama_client/features/membership/data/dto/membership_data_dto.dart';
import 'package:drama_client/features/membership/data/mapper/membership_mapper.dart';
import 'package:drama_client/features/membership/data/membership_repository_provider.dart';
import 'package:drama_client/features/membership/data/mock_membership_repository.dart';
import 'package:drama_client/features/membership/data/remote/membership_remote_data_source.dart';
import 'package:drama_client/features/membership/data/remote_membership_repository.dart';
import 'package:drama_client/features/membership/domain/membership_plan.dart';
import 'package:drama_client/features/store/data/dto/order_create_request_dto.dart';
import 'package:drama_client/features/store/data/dto/store_recharge_product_dto.dart';
import 'package:drama_client/features/store/data/mapper/store_mapper.dart';
import 'package:drama_client/features/store/data/mock_store_repository.dart';
import 'package:drama_client/features/store/data/remote/store_remote_data_source.dart';
import 'package:drama_client/features/store/data/remote_store_repository.dart';
import 'package:drama_client/features/store/data/store_repository_provider.dart';
import 'package:drama_client/features/wallet/data/dto/wallet_dto.dart';
import 'package:drama_client/features/wallet/data/mapper/wallet_mapper.dart';
import 'package:drama_client/features/wallet/data/mock_wallet_repository.dart';
import 'package:drama_client/features/wallet/data/remote/wallet_remote_data_source.dart';
import 'package:drama_client/features/wallet/data/remote_wallet_repository.dart';
import 'package:drama_client/features/wallet/data/wallet_repository_provider.dart';
import 'package:drama_client/features/wallet/domain/wallet_record.dart';
import 'package:drama_client/shared/media/media_resource.dart';

void main() {
  group('wallet remote skeleton', () {
    test('wallet dto and mapper keep balance, records, and network cover', () {
      final dto = WalletDto.fromJson(_walletJson);
      final data = const WalletMapper().mapWallet(dto);

      expect(dto.coinBalance, 1200);
      expect(dto.bonusBalance, 300);
      expect(data.coins, 1200);
      expect(data.bonus, 300);
      expect(data.autoUnlockNextEpisode, isTrue);
      expect(data.transactionRecords.single.trailingLabel, r'$9.99');
      expect(
        data.consumptionRecords.single.posterResource?.type,
        MediaResourceType.network,
      );
      expect(
        data.consumptionRecords.single.consumptionStatus,
        WalletConsumptionStatus.spent,
      );
      expect(data.coinRecords.single.rewardEnabled, isTrue);
    });

    test('wallet endpoints use required auth policy', () async {
      final adapter = _FakeHttpClientAdapter(responseData: _ok(_walletJson));
      final apiClient = _apiClient(adapter);
      final dataSource = WalletRemoteDataSource(apiClient: apiClient);

      await dataSource.getWallet();
      await dataSource.setAutoUnlockEnabled(enabled: true);

      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer test-token',
      );
      expect(adapter.requests.last.method, 'PATCH');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test('wallet provider defaults to mock and can be switched to remote', () {
      final mockContainer = ProviderContainer();
      addTearDown(mockContainer.dispose);

      expect(
        mockContainer.read(walletRepositoryProvider),
        isA<MockWalletRepository>(),
      );

      final remoteContainer = ProviderContainer(
        overrides: [useRemoteWalletApiProvider.overrideWithValue(true)],
      );
      addTearDown(remoteContainer.dispose);

      expect(
        remoteContainer.read(walletRepositoryProvider),
        isA<RemoteWalletRepository>(),
      );
    });
  });

  group('store remote skeleton', () {
    test('recharge product dto maps raw price and bonus fields', () {
      final dto = StoreRechargeProductDto.fromJson(_coinProductJson);
      final package = const StoreMapper().mapProduct(dto);

      expect(dto.priceMicros, 9990000);
      expect(package.baseCoins, 1000);
      expect(package.bonusCoins, 200);
      expect(package.totalCoins, 1200);
      expect(package.priceMicros, 9990000);
      expect(package.currencyCode, 'USD');
      expect(package.badgeLabel, '+17%');
    });

    test(
      'order creation uses required auth while product list is public',
      () async {
        final productAdapter = _FakeHttpClientAdapter(
          responseData: _ok({
            'balance': 0,
            'coinProducts': [_coinProductJson],
            'vipProducts': [],
            'tips': [],
          }),
        );
        final productSource = StoreRemoteDataSource(
          apiClient: _apiClient(productAdapter),
        );
        await productSource.listRechargeProducts(
          platform: 'android',
          locale: 'en',
        );
        expect(productAdapter.lastOptions?.headers['Authorization'], isNull);

        final orderAdapter = _FakeHttpClientAdapter(
          responseData: _ok({
            'orderId': 'order-1',
            'productId': 'coins-1',
            'status': 'created',
            'amountMicros': 9990000,
            'currencyCode': 'USD',
          }),
        );
        final orderSource = StoreRemoteDataSource(
          apiClient: _apiClient(orderAdapter),
        );
        await orderSource.createOrder(
          const OrderCreateRequestDto(
            productId: 'coins-1',
            kind: 'coins',
            platform: 'android',
          ),
        );
        expect(
          orderAdapter.lastOptions?.headers['Authorization'],
          'Bearer test-token',
        );
      },
    );

    test('store provider defaults to mock and can be switched to remote', () {
      final mockContainer = ProviderContainer();
      addTearDown(mockContainer.dispose);
      expect(
        mockContainer.read(storeRepositoryProvider),
        isA<MockStoreRepository>(),
      );

      final remoteContainer = ProviderContainer(
        overrides: [useRemoteStoreApiProvider.overrideWithValue(true)],
      );
      addTearDown(remoteContainer.dispose);
      expect(
        remoteContainer.read(storeRepositoryProvider),
        isA<RemoteStoreRepository>(),
      );
    });
  });

  group('membership remote skeleton', () {
    test('membership product and status map promotion and benefits', () {
      final dto = MembershipDataDto.fromJson({
        'status': _membershipStatusJson,
        'products': [_membershipProductJson],
        'benefits': [
          {'icon': 'download', 'title': 'Download'},
        ],
        'heroTitle': 'Join Membership',
        'heroSubtitle': 'Upgrade now',
        'subscriptionNote': 'Auto renew · Cancel anytime',
        'tips': ['Tip A'],
      });
      final data = const MembershipMapper().mapData(dto);

      expect(data.isActive, isTrue);
      expect(data.plans.single.priceMicros, 12990000);
      expect(data.plans.single.originalPriceMicros, 24990000);
      expect(data.plans.single.badgeLabel, 'Limited offer');
      expect(data.benefits.single.icon, MembershipBenefitIcon.download);
    });

    test('membership status uses required auth', () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: _ok(_membershipStatusJson),
      );
      final source = MembershipRemoteDataSource(apiClient: _apiClient(adapter));

      await source.getStatus();

      expect(
        adapter.lastOptions?.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test(
      'membership provider defaults to mock and can be switched to remote',
      () {
        final mockContainer = ProviderContainer();
        addTearDown(mockContainer.dispose);
        expect(
          mockContainer.read(membershipRepositoryProvider),
          isA<MockMembershipRepository>(),
        );

        final remoteContainer = ProviderContainer(
          overrides: [useRemoteMembershipApiProvider.overrideWithValue(true)],
        );
        addTearDown(remoteContainer.dispose);
        expect(
          remoteContainer.read(membershipRepositoryProvider),
          isA<RemoteMembershipRepository>(),
        );
      },
    );
  });

  group('entitlement remote skeleton', () {
    test('entitlement state dto maps shared entitlement fields', () {
      final dto = UserEntitlementStateDto.fromJson(_entitlementJson);
      final state = const EntitlementMapper().mapState(dto);

      expect(state.isMember, isTrue);
      expect(state.coinBalance, 900);
      expect(state.bonusBalance, 100);
      expect(state.autoUnlockEnabled, isTrue);
      expect(state.unlockedEpisodeIds, contains('ep-1'));
      expect(state.refreshReason, 'login');
    });

    test(
      'unlock result maps insufficient/member/already/unavailable decisions',
      () {
        final mapper = const EntitlementMapper();

        expect(
          mapper
              .mapUnlockResultDecision(
                dto: UnlockEpisodeResponseDto.fromJson({
                  'result': 'insufficientCoins',
                }),
                dramaId: 'drama',
                episodeId: 'ep',
                price: 30,
                operationId: 'op',
              )
              .type,
          EpisodeAccessDecisionType.showRechargeDialog,
        );
        expect(
          mapper
              .mapUnlockResultDecision(
                dto: UnlockEpisodeResponseDto.fromJson({
                  'result': 'membershipRequired',
                }),
                dramaId: 'drama',
                episodeId: 'ep',
                price: 30,
                operationId: 'op',
              )
              .type,
          EpisodeAccessDecisionType.goMembership,
        );
        expect(
          mapper
              .mapUnlockResultDecision(
                dto: UnlockEpisodeResponseDto.fromJson({
                  'result': 'alreadyUnlocked',
                }),
                dramaId: 'drama',
                episodeId: 'ep',
                price: 30,
                operationId: 'op',
              )
              .type,
          EpisodeAccessDecisionType.allowPlay,
        );
        expect(
          mapper
              .mapUnlockResultDecision(
                dto: UnlockEpisodeResponseDto.fromJson({
                  'result': 'unavailable',
                }),
                dramaId: 'drama',
                episodeId: 'ep',
                price: 30,
                operationId: 'op',
              )
              .type,
          EpisodeAccessDecisionType.waitUnlock,
        );
      },
    );

    test(
      'entitlement unlock and setting endpoints use required auth',
      () async {
        final adapter = _FakeHttpClientAdapter(
          responseData: _ok(_entitlementJson),
        );
        final source = EntitlementRemoteDataSource(
          apiClient: _apiClient(adapter),
        );

        await source.fetchEntitlements();
        await source.setAutoUnlockEnabled(true);

        expect(
          adapter.requests.first.headers['Authorization'],
          'Bearer test-token',
        );
        expect(adapter.requests.last.method, 'PATCH');
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer test-token',
        );
      },
    );

    test(
      'entitlement provider defaults to mock and can be switched to remote',
      () {
        final mockContainer = ProviderContainer();
        addTearDown(mockContainer.dispose);
        expect(
          mockContainer.read(entitlementRepositoryProvider),
          isA<MockEntitlementRepository>(),
        );

        final remoteContainer = ProviderContainer(
          overrides: [useRemoteEntitlementApiProvider.overrideWithValue(true)],
        );
        addTearDown(remoteContainer.dispose);
        expect(
          remoteContainer.read(entitlementRepositoryProvider),
          isA<RemoteEntitlementRepository>(),
        );
      },
    );
  });

  test('commerce envelope non-zero preserves businessCode', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {
        'code': 4001,
        'message': 'insufficient coins',
        'data': null,
      },
    );
    final source = EntitlementRemoteDataSource(apiClient: _apiClient(adapter));

    await expectLater(
      source.fetchEntitlements(),
      throwsA(
        isA<ApiException>().having((e) => e.businessCode, 'businessCode', 4001),
      ),
    );
  });
}

Map<String, Object?> _ok(Object? data) => {
  'code': 0,
  'message': 'success',
  'data': data,
};

const _coinProductJson = {
  'productId': 'coins-1',
  'platformProductId': 'google.coins.1',
  'kind': 'coins',
  'title': '1000',
  'baseCoins': 1000,
  'bonusCoins': 200,
  'totalCoins': 1200,
  'priceMicros': 9990000,
  'currencyCode': 'USD',
  'localizedPrice': r'$9.99',
  'originalPriceMicros': 12990000,
  'localizedOriginalPrice': r'$12.99',
  'sortOrder': 1,
  'enabled': true,
};

const _membershipProductJson = {
  'productId': 'weekly-vip',
  'platformProductId': 'google.weekly.vip',
  'period': 'weekly',
  'title': 'Weekly VIP',
  'priceMicros': 12990000,
  'currencyCode': 'USD',
  'localizedPrice': r'$12.99',
  'originalPriceMicros': 24990000,
  'localizedOriginalPrice': r'$24.99',
  'promotionId': 'intro',
  'promotionExpiresAt': '2026-05-15T10:00:00Z',
  'benefits': [
    {'icon': 'download', 'title': 'Download'},
  ],
  'tips': ['Auto renew'],
  'enabled': true,
  'dailyPriceLabel': r'$1.78/day',
};

const _membershipStatusJson = {
  'isActive': true,
  'planId': 'weekly-vip',
  'expiresAt': '2026-06-15T10:00:00Z',
  'renewsAt': '2026-06-15T10:00:00Z',
  'autoRenewEnabled': true,
  'source': 'google',
  'benefits': [
    {'icon': 'download', 'title': 'Download'},
  ],
};

const _walletJson = {
  'coinBalance': 1200,
  'bonusBalance': 300,
  'autoUnlockEnabled': true,
  'transactionRecords': [
    {
      'id': 'txn-1',
      'type': 'coins',
      'amount': 1000,
      'bonusAmount': 200,
      'price': 9990000,
      'currency': 'USD',
      'platform': 'google',
      'createdAt': '2026-05-15T01:00:00Z',
      'status': 'success',
    },
  ],
  'consumptionRecords': [
    {
      'id': 'consume-1',
      'dramaId': 'drama-1',
      'episodeId': 'ep-4',
      'episodeNumber': 4,
      'title': 'Found You',
      'coverUrl': 'https://cdn.example.com/poster.jpg',
      'amountCoins': 30,
      'sourceType': 'coins',
      'createdAt': '2026-05-15T02:00:00Z',
      'status': 'spent',
    },
  ],
  'rewardCoinRecords': [
    {
      'id': 'reward-1',
      'title': 'Daily check in',
      'amountCoins': 10,
      'expiresAt': '2026-06-15T00:00:00Z',
      'claimable': true,
      'claimed': false,
    },
  ],
};

const _entitlementJson = {
  'isGuest': false,
  'isMember': true,
  'membershipExpiresAt': '2026-06-15T10:00:00Z',
  'coinBalance': 900,
  'bonusBalance': 100,
  'autoUnlockEnabled': true,
  'unlockedEpisodeIds': ['ep-1'],
  'pendingOperationId': 'op-1',
  'serverTime': '2026-05-15T10:00:00Z',
  'refreshReason': 'login',
};

ApiClient _apiClient(_FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext(
      deviceId: 'device',
      lang: 'en',
      platform: 'android',
      appVersion: '1.0.0',
      accessToken: 'test-token',
    ),
  );
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;
  final requests = <RequestOptions>[];
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
