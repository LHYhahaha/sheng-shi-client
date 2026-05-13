enum WalletRecordType { transaction, consumption, coins }

enum WalletConsumptionStatus { spent, expired }

class WalletRecord {
  const WalletRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.dateLabel,
    required this.trailingLabel,
    this.showCoinIcon = false,
    this.posterAssetPath,
    this.subtitle,
    this.detailLabel,
    this.trailingSubtitle,
    this.consumptionStatus,
    this.rewardEnabled = false,
    this.rewardClaimed = false,
  });

  final String id;
  final WalletRecordType type;
  final String title;
  final String dateLabel;
  final String trailingLabel;
  final bool showCoinIcon;
  final String? posterAssetPath;
  final String? subtitle;
  final String? detailLabel;
  final String? trailingSubtitle;
  final WalletConsumptionStatus? consumptionStatus;
  final bool rewardEnabled;
  final bool rewardClaimed;

  WalletRecord copyWith({bool? rewardEnabled, bool? rewardClaimed}) {
    return WalletRecord(
      id: id,
      type: type,
      title: title,
      dateLabel: dateLabel,
      trailingLabel: trailingLabel,
      showCoinIcon: showCoinIcon,
      posterAssetPath: posterAssetPath,
      subtitle: subtitle,
      detailLabel: detailLabel,
      trailingSubtitle: trailingSubtitle,
      consumptionStatus: consumptionStatus,
      rewardEnabled: rewardEnabled ?? this.rewardEnabled,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }
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
