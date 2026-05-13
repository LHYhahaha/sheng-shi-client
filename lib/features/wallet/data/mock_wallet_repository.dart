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
          title: 'Unlock EP.12',
          dateLabel: '2026.04.25',
          trailingLabel: '-60',
          showCoinIcon: true,
        ),
        WalletRecord(
          id: 'unlock_ep_13',
          type: WalletRecordType.consumption,
          title: 'Unlock EP.13',
          dateLabel: '2026.04.25',
          trailingLabel: '-60',
          showCoinIcon: true,
        ),
        WalletRecord(
          id: 'unlock_ep_14',
          type: WalletRecordType.consumption,
          title: 'Unlock EP.14',
          dateLabel: '2026.04.26',
          trailingLabel: '-60',
          showCoinIcon: true,
        ),
      ],
      coinRecords: [
        WalletRecord(
          id: 'daily_bonus',
          type: WalletRecordType.coins,
          title: 'Daily bonus',
          dateLabel: '2026.04.24',
          trailingLabel: '+100',
          showCoinIcon: true,
        ),
        WalletRecord(
          id: 'purchase_bonus',
          type: WalletRecordType.coins,
          title: 'Recharge bonus',
          dateLabel: '2026.04.24',
          trailingLabel: '+300',
          showCoinIcon: true,
        ),
        WalletRecord(
          id: 'member_points',
          type: WalletRecordType.coins,
          title: 'Member points',
          dateLabel: '2026.04.25',
          trailingLabel: '+50',
          showCoinIcon: true,
        ),
      ],
    );
  }
}
