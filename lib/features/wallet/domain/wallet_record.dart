enum WalletRecordType { transaction, consumption, coins }

class WalletRecord {
  const WalletRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.dateLabel,
    required this.trailingLabel,
    this.showCoinIcon = false,
  });

  final String id;
  final WalletRecordType type;
  final String title;
  final String dateLabel;
  final String trailingLabel;
  final bool showCoinIcon;
}

class WalletData {
  const WalletData({
    required this.coins,
    required this.bonus,
    required this.autoUnlockNextEpisode,
    required this.transactionRecords,
    required this.consumptionRecords,
    required this.coinRecords,
  });

  final int coins;
  final int bonus;
  final bool autoUnlockNextEpisode;
  final List<WalletRecord> transactionRecords;
  final List<WalletRecord> consumptionRecords;
  final List<WalletRecord> coinRecords;
}
