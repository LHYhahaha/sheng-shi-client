import '../domain/wallet_record.dart';
import '../domain/wallet_repository.dart';

class MockWalletRepository implements WalletRepository {
  const MockWalletRepository();

  @override
  Future<WalletData> fetchWallet() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return const WalletData(
      coins: 4000,
      bonus: 4000,
      autoUnlockNextEpisode: true,
      transactionRecords: [
        WalletRecord(
          id: 'membership_weekly',
          type: WalletRecordType.transaction,
          title: 'Membership (Weekly)',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
        ),
        WalletRecord(
          id: 'coins_3000',
          type: WalletRecordType.transaction,
          title: '3000 Coins',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
          showCoinIcon: true,
        ),
        WalletRecord(
          id: 'coins_3000_bonus',
          type: WalletRecordType.transaction,
          title: '3000 Coins + 300bonus',
          dateLabel: '2026.04.24',
          trailingLabel: r'$19.99',
          showCoinIcon: true,
        ),
      ],
      consumptionRecords: [
        WalletRecord(
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
        WalletRecord(
          id: 'unlock_ep_13',
          type: WalletRecordType.consumption,
          title: 'EP. 11',
          subtitle: 'Raja Iblis Hidup Kembali',
          dateLabel: '2026.04.24 14:23:11',
          trailingLabel: 'AD',
          posterAssetPath: 'assets/images/my_list/cover_1.png',
          consumptionStatus: WalletConsumptionStatus.spent,
        ),
        WalletRecord(
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
      coinRecords: [
        WalletRecord(
          id: 'daily_bonus',
          type: WalletRecordType.coins,
          title: '10 Reward Coins',
          dateLabel: '2026.04.23 - 2026.05.23',
          trailingLabel: 'Check in',
          showCoinIcon: true,
          rewardEnabled: true,
        ),
        WalletRecord(
          id: 'purchase_bonus',
          type: WalletRecordType.coins,
          title: '20 Reward Coins',
          dateLabel: '2026.04.23 - 2026.05.23',
          trailingLabel: 'Check in',
          showCoinIcon: true,
          rewardClaimed: true,
        ),
        WalletRecord(
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
}
