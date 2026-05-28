import '../../../shared/media/media_resource.dart';

/// 钱包记录类型。
///
/// 三类记录有不同对账口径和 UI，不要混成一个列表再靠文案区分。
enum WalletRecordType { transaction, consumption, coins }

/// 消费记录状态。
///
/// 只适用于 consumption 类型记录。
enum WalletConsumptionStatus { spent, expired }

/// 钱包流水/奖励记录。
///
/// 该模型覆盖三类页面展示，因此部分字段只在特定 type 下有意义。使用前应先根据
/// `type` 选择对应 row，而不是假设所有字段都存在。
class WalletRecord {
  const WalletRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.dateLabel,
    required this.trailingLabel,
    this.showCoinIcon = false,
    this.posterAssetPath,
    this.posterResource,
    this.subtitle,
    this.detailLabel,
    this.trailingSubtitle,
    this.consumptionStatus,
    this.rewardEnabled = false,
    this.rewardClaimed = false,
  });

  /// 记录 id。
  ///
  /// 用于领取奖励和列表 key，不能用标题或日期替代。
  final String id;

  /// 记录类型。
  final WalletRecordType type;

  /// 主标题。
  final String title;

  /// 日期展示文案。
  final String dateLabel;

  /// 右侧主文案，例如金额、状态或奖励按钮文案。
  final String trailingLabel;

  /// 是否显示金币图标。
  ///
  /// 只影响视觉，不表示这条记录一定会改变余额。
  final bool showCoinIcon;

  /// 消费记录的剧封面。
  final String? posterAssetPath;

  /// 消费记录封面的统一资源身份。
  ///
  /// remote mapper 会把 coverUrl 映射为 network resource。当前 Wallet UI 仍使用
  /// posterAssetPath，后续做网络图时应优先读此字段，避免把 URL 伪装成 asset。
  final MediaResource? posterResource;

  /// 副标题。
  final String? subtitle;

  /// 详情文案。
  final String? detailLabel;

  /// 右侧副文案。
  final String? trailingSubtitle;

  /// 消费状态。
  ///
  /// 仅 consumption 类型有意义；transaction/coins 记录不要读取它做筛选。
  final WalletConsumptionStatus? consumptionStatus;

  /// 奖励是否可领取。
  ///
  /// 仅 coins 类型的任务记录使用。可领取不代表余额已增加。
  final bool rewardEnabled;

  /// 奖励是否已领取。
  ///
  /// mock 阶段仅改变按钮状态；真实发放需要服务端确认后刷新钱包。
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
      posterResource: posterResource,
      subtitle: subtitle,
      detailLabel: detailLabel,
      trailingSubtitle: trailingSubtitle,
      consumptionStatus: consumptionStatus,
      rewardEnabled: rewardEnabled ?? this.rewardEnabled,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }
}

/// 钱包页聚合数据。
///
/// 余额和三类记录同批返回，避免页面在刷新时出现余额和流水不同步。
class WalletData {
  const WalletData({
    required this.coins,
    required this.bonus,
    required this.totalCoin,
    required this.autoUnlockNextEpisode,
    required this.transactionRecords,
    required this.consumptionRecords,
    required this.coinRecords,
  });

  /// 可消费金币余额。
  final int coins;

  /// 赠币余额。
  final int bonus;

  /// 总金币余额。
  final int totalCoin;

  /// 服务端或 mock 返回的自动解锁偏好。
  final bool autoUnlockNextEpisode;

  /// 交易流水。
  final List<WalletRecord> transactionRecords;

  /// 消费流水。
  final List<WalletRecord> consumptionRecords;

  /// 金币奖励记录。
  final List<WalletRecord> coinRecords;
}
