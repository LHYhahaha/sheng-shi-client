import '../../../core/i18n/ui_text.dart';
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
    required UiText title,
    required this.dateLabel,
    required UiText trailingLabel,
    this.showCoinIcon = false,
    this.posterAssetPath,
    this.posterResource,
    UiText? subtitle,
    UiText? detailLabel,
    UiText? trailingSubtitle,
    this.sourceType,
    this.sourceOrderNo,
    this.rewardSourceType,
    this.consumptionStatus,
    this.rewardEnabled = false,
    this.rewardClaimed = false,
    this.productType,
    this.memberPeriodType,
    this.coin,
    this.bonusCoin,
    this.amountText,
  }) : titleText = title,
       trailingLabelText = trailingLabel,
       subtitleText = subtitle,
       detailLabelText = detailLabel,
       trailingSubtitleText = trailingSubtitle;

  WalletRecord.raw({
    required this.id,
    required this.type,
    required String title,
    required this.dateLabel,
    required String trailingLabel,
    this.showCoinIcon = false,
    this.posterAssetPath,
    this.posterResource,
    String? subtitle,
    String? detailLabel,
    String? trailingSubtitle,
    this.sourceType,
    this.sourceOrderNo,
    this.rewardSourceType,
    this.consumptionStatus,
    this.rewardEnabled = false,
    this.rewardClaimed = false,
    this.productType,
    this.memberPeriodType,
    this.coin,
    this.bonusCoin,
    this.amountText,
  }) : titleText = UiText.raw(title),
       trailingLabelText = UiText.raw(trailingLabel),
       subtitleText = subtitle == null ? null : UiText.raw(subtitle),
       detailLabelText = detailLabel == null ? null : UiText.raw(detailLabel),
       trailingSubtitleText = trailingSubtitle == null
           ? null
           : UiText.raw(trailingSubtitle);

  /// 记录 id。
  ///
  /// 用于领取奖励和列表 key，不能用标题或日期替代。
  final String id;

  /// 记录类型。
  final WalletRecordType type;

  /// 主标题。
  final UiText titleText;

  String get title => titleText.rawValue ?? titleText.fallbackEn;

  /// 日期展示文案。
  final String dateLabel;

  /// 右侧主文案，例如金额、状态或奖励按钮文案。
  final UiText trailingLabelText;

  String get trailingLabel =>
      trailingLabelText.rawValue ?? trailingLabelText.fallbackEn;

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
  final UiText? subtitleText;

  String? get subtitle => subtitleText?.rawValue ?? subtitleText?.fallbackEn;

  /// 详情文案。
  final UiText? detailLabelText;

  String? get detailLabel =>
      detailLabelText?.rawValue ?? detailLabelText?.fallbackEn;

  /// 右侧副文案。
  final UiText? trailingSubtitleText;

  String? get trailingSubtitle =>
      trailingSubtitleText?.rawValue ?? trailingSubtitleText?.fallbackEn;

  /// 消费来源类型。
  ///
  /// 用于 UI 层根据来源类型显示本地化文本。例如 'coins' 显示为本地化的 'Coins'。
  final String? sourceType;

  /// 奖励金币的来源业务单号。
  ///
  /// 仅 coins 类型有意义，可用于后续的订单详情或问题排查。
  final String? sourceOrderNo;

  /// 奖励金币来源类型。
  ///
  /// 对应服务端 `sourceType`：1 后台补发、2 签到、3 任务、4 充值、5 其他。
  /// 它与消费记录的字符串 [sourceType] 语义不同，因此单独保留。
  final int? rewardSourceType;

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

  /// 商品类型。
  ///
  /// 仅 transaction 类型有意义。用于判断是金币商品还是会员商品。
  /// 'ProductType_PRODUCT_TYPE_COIN': 金币商品
  /// 'ProductType_PRODUCT_TYPE_MEMBER': 会员商品
  final String? productType;

  /// 会员周期类型。
  ///
  /// 仅当 productType 为会员商品时有意义。
  /// 'MemberPeriodType_MEMBER_PERIOD_TYPE_WEEK': 周会员
  /// 'MemberPeriodType_MEMBER_PERIOD_TYPE_MONTH': 月会员
  /// 'MemberPeriodType_MEMBER_PERIOD_TYPE_QUARTER': 季度会员
  /// 'MemberPeriodType_MEMBER_PERIOD_TYPE_YEAR': 年会员
  final String? memberPeriodType;

  /// 充值金币数量。
  ///
  /// 仅当 productType 为金币商品时有意义。
  final int? coin;

  /// 赠送金币数量。
  ///
  /// 仅当 productType 为金币商品时有意义。
  final int? bonusCoin;

  /// 金额展示文本。
  ///
  /// 用于交易记录右侧显示的金额，已格式化为本地化字符串。
  final String? amountText;

  WalletRecord copyWith({
    bool? rewardEnabled,
    bool? rewardClaimed,
    String? sourceType,
    String? sourceOrderNo,
    int? rewardSourceType,
    String? productType,
    String? memberPeriodType,
    int? coin,
    int? bonusCoin,
    String? amountText,
  }) {
    return WalletRecord(
      id: id,
      type: type,
      title: titleText,
      dateLabel: dateLabel,
      trailingLabel: trailingLabelText,
      showCoinIcon: showCoinIcon,
      posterAssetPath: posterAssetPath,
      posterResource: posterResource,
      subtitle: subtitleText,
      detailLabel: detailLabelText,
      trailingSubtitle: trailingSubtitleText,
      sourceType: sourceType ?? this.sourceType,
      sourceOrderNo: sourceOrderNo ?? this.sourceOrderNo,
      rewardSourceType: rewardSourceType ?? this.rewardSourceType,
      consumptionStatus: consumptionStatus,
      rewardEnabled: rewardEnabled ?? this.rewardEnabled,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      productType: productType ?? this.productType,
      memberPeriodType: memberPeriodType ?? this.memberPeriodType,
      coin: coin ?? this.coin,
      bonusCoin: bonusCoin ?? this.bonusCoin,
      amountText: amountText ?? this.amountText,
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
