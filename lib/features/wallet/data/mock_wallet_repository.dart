import '../data/dto/wallet_consumption_record_dto.dart';
import '../data/dto/wallet_reward_coin_record_dto.dart';
import '../data/dto/wallet_transaction_record_dto.dart';
import '../data/mapper/wallet_mapper.dart';
import '../domain/wallet_record.dart';
import '../domain/wallet_repository.dart';

class MockWalletRepository implements WalletRepository {
  const MockWalletRepository();

  static const _mapper = WalletMapper();

  @override
  Future<WalletData> fetchWallet() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return WalletData(
      coins: 4000,
      bonus: 4000,
      totalCoin: 8000,
      autoUnlockNextEpisode: true,
      transactionRecords: [
        WalletRecord.raw(
          id: 'membership_weekly',
          type: WalletRecordType.transaction,
          title: 'Membership (Weekly)',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
        ),
        WalletRecord.raw(
          id: 'coins_3000',
          type: WalletRecordType.transaction,
          title: '3000 Coins',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
          showCoinIcon: true,
        ),
        WalletRecord.raw(
          id: 'coins_3000_bonus',
          type: WalletRecordType.transaction,
          title: '3000 Coins + 300bonus',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
          showCoinIcon: true,
        ),
      ],
      consumptionRecords:  [
        WalletRecord.raw(
          id: 'unlock_ep_12',
          type: WalletRecordType.consumption,
          title: 'EP. 11',
          subtitle: 'Raja Iblis Hidup Kembali',
          dateLabel: '2026.04.24 14:23:11',
          trailingLabel: '-30',
          trailingSubtitle: 'Coins',
          posterAssetPath: 'assets/images/my_list/cover_1.png',
          consumptionStatus: WalletConsumptionStatus.spent,
        ),
        WalletRecord.raw(
          id: 'unlock_ep_13',
          type: WalletRecordType.consumption,
          title: 'EP. 11',
          subtitle: 'Raja Iblis Hidup Kembali',
          dateLabel: '2026.04.24 14:23:11',
          trailingLabel: 'AD',
          posterAssetPath: 'assets/images/my_list/cover_1.png',
          consumptionStatus: WalletConsumptionStatus.spent,
        ),
        WalletRecord.raw(
          id: 'unlock_ep_14',
          type: WalletRecordType.consumption,
          title: 'EP. 10',
          subtitle: 'Pulang Malam Mengejutkan',
          dateLabel: '2026.04.20 09:10:08',
          trailingLabel: '-20',
          trailingSubtitle: 'Coins',
          posterAssetPath: 'assets/images/my_list/cover_2.png',
          consumptionStatus: WalletConsumptionStatus.expired,
        ),
      ],
      coinRecords:  [
        WalletRecord.raw(
          id: 'daily_bonus',
          type: WalletRecordType.coins,
          title: '10 Reward Coins',
          dateLabel: '2026.04.23 - 2026.05.23',
          trailingLabel: 'Check in',
          showCoinIcon: true,
          rewardEnabled: true,
        ),
        WalletRecord.raw(
          id: 'purchase_bonus',
          type: WalletRecordType.coins,
          title: '20 Reward Coins',
          dateLabel: '2026.04.23 - 2026.05.23',
          trailingLabel: 'Check in',
          showCoinIcon: true,
          rewardClaimed: true,
        ),
        WalletRecord.raw(
          id: 'member_points',
          type: WalletRecordType.coins,
          title: '10 Reward Coins',
          dateLabel: '2026.04.23 - 2026.05.23',
          trailingLabel: 'Check in',
          showCoinIcon: true,
          rewardEnabled: true,
        ),
      ],
    );
  }

  @override
  Future<WalletRecordPage> fetchTransactionRecords({
    String? pageToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    const mockDtos = [
      WalletTransactionRecordDto(
        id: 'membership_weekly',
        type: 'transaction',
        coinAmount: 0,
        bonusAmount: 0,
        price: 1999000,
        currency: 'USD',
        platform: 'iOS',
        createdAt: null,
        status: 'success',
        title: 'Membership (Weekly)',
      ),
      WalletTransactionRecordDto(
        id: 'coins_3000',
        type: 'transaction',
        coinAmount: 3000,
        bonusAmount: 0,
        price: 1999000,
        currency: 'USD',
        platform: 'iOS',
        createdAt: null,
        status: 'success',
        title: '3000 Coins',
      ),
      WalletTransactionRecordDto(
        id: 'coins_3000_bonus',
        type: 'transaction',
        coinAmount: 3000,
        bonusAmount: 300,
        price: 1999000,
        currency: 'USD',
        platform: 'iOS',
        createdAt: null,
        status: 'success',
        title: '3000 Coins + 300bonus',
      ),
    ];

    return WalletRecordPage(
      items: mockDtos.map(_mapper.mapTransaction).toList(growable: false),
      nextPageToken: null,
    );
  }

  @override
  Future<WalletRecordPage> fetchConsumptionRecords({
    required String status,
    String? pageToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    const mockDtos = [
      WalletConsumptionRecordDto(
        id: 'unlock_ep_12',
        dramaId: 'drama_1',
        episodeId: 'ep_11',
        episodeNumber: 11,
        title: 'Raja Iblis Hidup Kembali',
        amountCoins: 30,
        sourceType: 'coins',
        status: 'spent',
        createdAt: null,
        coverUrl: null,
      ),
      WalletConsumptionRecordDto(
        id: 'unlock_ep_13',
        dramaId: 'drama_1',
        episodeId: 'ep_11',
        episodeNumber: 11,
        title: 'Raja Iblis Hidup Kembali',
        amountCoins: 0,
        sourceType: 'ad',
        status: 'spent',
        createdAt: null,
        coverUrl: null,
      ),
      WalletConsumptionRecordDto(
        id: 'unlock_ep_14',
        dramaId: 'drama_1',
        episodeId: 'ep_10',
        episodeNumber: 10,
        title: 'Pulang Malam Mengejutkan',
        amountCoins: 20,
        sourceType: 'coins',
        status: 'expired',
        createdAt: null,
        coverUrl: null,
      ),
    ];

    return WalletRecordPage(
      items: mockDtos.map(_mapper.mapConsumption).toList(growable: false),
      nextPageToken: null,
    );
  }

  @override
  Future<WalletRecordPage> fetchRewardCoins({String? pageToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    const mockDtos = [
      WalletRewardCoinRecordDto(
        recordId: 1,
        bonusCoin: 10,
        remainBonusCoin: 10,
        sourceName: 'Daily Bonus',
        sourceType: 2,
        sourceOrderNo: 'daily_bonus_1',
        status: 0,
        startAt: null,
        expireAt: null,
        permanent: false,
      ),
      WalletRewardCoinRecordDto(
        recordId: 2,
        bonusCoin: 20,
        remainBonusCoin: 0,
        sourceName: 'Purchase Bonus',
        sourceType: 4,
        sourceOrderNo: 'purchase_bonus_2',
        status: 1,
        startAt: null,
        expireAt: null,
        permanent: false,
      ),
      WalletRewardCoinRecordDto(
        recordId: 3,
        bonusCoin: 10,
        remainBonusCoin: 10,
        sourceName: 'Member Points',
        sourceType: 3,
        sourceOrderNo: 'member_points_3',
        status: 0,
        startAt: null,
        expireAt: null,
        permanent: false,
      ),
    ];

    return WalletRecordPage(
      items: mockDtos.map(_mapper.mapReward).toList(growable: false),
      nextPageToken: null,
    );
  }
}
