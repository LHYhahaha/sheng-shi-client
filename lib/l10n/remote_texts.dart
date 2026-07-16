import '../core/i18n/ui_text.dart';

/// Remote i18n JSON text specification.
///
/// Each entry keeps the server key and local fallbacks together, so feature
/// code can reference one stable catalog item instead of repeating strings.
class RemoteTextSpec {
  const RemoteTextSpec({
    required this.key,
    required this.fallbackEn,
    required this.fallbackZh,
  });

  final String key;
  final String fallbackEn;
  final String fallbackZh;

  UiText uiText([Map<String, Object?> args = const {}]) {
    return UiText.key(
      key,
      fallbackEn: fallbackEn,
      fallbackZh: fallbackZh,
      args: args,
    );
  }
}

abstract final class RemoteTexts {
  // ── 通用操作 Common actions ─────────────────────────────────────
  static const commonActionClaim = RemoteTextSpec(
    key: 'common.action.claim',
    fallbackEn: 'Claim',
    fallbackZh: '领取',
  );

  static const commonActionGoComplete = RemoteTextSpec(
    key: 'common.action.go_complete',
    fallbackEn: 'Go',
    fallbackZh: '去完成',
  );

  static const commonActionOk = RemoteTextSpec(
    key: 'common.action.ok',
    fallbackEn: 'OK',
    fallbackZh: '好的',
  );

  static const commonStatusClaimed = RemoteTextSpec(
    key: 'common.status.claimed',
    fallbackEn: 'Claimed',
    fallbackZh: '已领取',
  );

  // ── 通用单位 Common units ─────────────────────────────────────
  static const appCommonUnitCoin = RemoteTextSpec(
    key: 'app.common.unit.coin',
    fallbackEn: 'Coins',
    fallbackZh: '金币',
  );

  static const consumptionHistoryEpisodeIndex = RemoteTextSpec(
    key: 'consumption_history.item.episode_index',
    fallbackEn: 'Episode {index}',
    fallbackZh: '第 {index} 集',
  );

  static const consumptionHistoryCoins = RemoteTextSpec(
    key: 'consumption_history.unit.coins',
    fallbackEn: 'Coins',
    fallbackZh: '金币',
  );

  static const transactionHistoryTitle = RemoteTextSpec(
    key: 'transaction_history.title',
    fallbackEn: 'Transaction',
    fallbackZh: '交易',
  );

  static const walletRecordSourceAd = RemoteTextSpec(
    key: 'wallet.record.source.ad',
    fallbackEn: 'AD',
    fallbackZh: '广告',
  );

  static const walletRecordRewardCoins = RemoteTextSpec(
    key: 'wallet.record.reward_coins',
    fallbackEn: '{count} Reward Coins',
    fallbackZh: '{count} 奖励金币',
  );

  static const walletRecordTransactionCoinsBonus = RemoteTextSpec(
    key: 'wallet.record.transaction.coins_bonus',
    fallbackEn: '{coins} Coins + {bonus} bonus',
    fallbackZh: '{coins} 金币 + {bonus} 赠送',
  );

  // ── 会员积分 Member points ─────────────────────────────────────
  static const memberPointsTitle = RemoteTextSpec(
    key: 'member_points.title',
    fallbackEn: 'VIP Points',
    fallbackZh: '会员积分',
  );

  static const memberPointsLockedDailyReward = RemoteTextSpec(
    key: 'member_points.status.locked_daily_reward',
    fallbackEn: 'Subscribe to unlock daily rewards',
    fallbackZh: '订阅即可解锁每日奖励',
  );

  static const memberPointsDailyRewardTitle = RemoteTextSpec(
    key: 'member_points.daily_reward.title',
    fallbackEn: 'Daily Rewards',
    fallbackZh: '每日奖励',
  );

  static const memberPointsDailyPoints = RemoteTextSpec(
    key: 'member_points.daily_points',
    fallbackEn: 'Daily Points',
    fallbackZh: '每日积分',
  );

  static const memberPointsFreeMembership = RemoteTextSpec(
    key: 'member_points.free_membership',
    fallbackEn: 'Free Membership',
    fallbackZh: '免费会员',
  );

  static const memberPointsPaidMemberOnly = RemoteTextSpec(
    key: 'member_points.paid_member_only',
    fallbackEn: 'Only paid members can earn points',
    fallbackZh: '仅付费会员可享有积分',
  );

  static const memberPointsMemberDayCount = RemoteTextSpec(
    key: 'member_points.member_day_count',
    fallbackEn: 'Today is Day {day} of your membership',
    fallbackZh: '今天是会员第{day}天',
  );

  static const memberPointsDailyLottery = RemoteTextSpec(
    key: 'member_points.daily_lottery',
    fallbackEn: 'Daily Lottery',
    fallbackZh: '每日抽奖',
  );

  static const memberPointsPlayReward = RemoteTextSpec(
    key: 'member_points.play_reward',
    fallbackEn: 'Watch Reward',
    fallbackZh: '播放奖励',
  );

  static const memberPointsWatchOver30Min = RemoteTextSpec(
    key: 'member_points.watch_over_30min',
    fallbackEn: '(＞ 30 min)',
    fallbackZh: '(＞ 30 分钟)',
  );

  static const memberPointsRuleTitle = RemoteTextSpec(
    key: 'member_points.rule.title',
    fallbackEn: 'Points Rules',
    fallbackZh: '积分规则',
  );

  static const memberPointsRuleContent = RemoteTextSpec(
    key: 'member_points.rule.content',
    fallbackEn:
        '1. The final interpretation of this campaign belongs to {appname}.\n2. Paid members of {appname} can claim a random amount of member points once per day. Only paid members can claim points; non-members and free members cannot claim points.\n3. Member points can only be used to redeem items in the points store.\n4. You can view point changes in Points Details.\n5. Member point benefits refresh every day at 00:00 India Standard Time.\n6. Tap Official Rules to view detailed instructions.',
    fallbackZh:
        '1.活动最终解释权属于{appname}。\n2.{appname}付费会员用户每日可领取1天随机数量的会员积分。仅付费会员可领取积分，非会员与免费会员无法领取积分\n3.会员积分只可用于在积分商城兑换商品\n4.你可以在积分明细中检视积分的变动\n5.会员积分福利将于每天当地时间早上6点刷新\n6.检视详细说明请点选官方规则',
  );

  static const memberPointsRule = RemoteTextSpec(
    key: 'member_points.rule.official',
    fallbackEn: 'Rules',
    fallbackZh: '规则',
  );

  static const memberPointsDetailTitle = RemoteTextSpec(
    key: 'member_points.detail.title',
    fallbackEn: 'Points History',
    fallbackZh: '积分明细',
  );

  static const memberPointsDetailEmpty = RemoteTextSpec(
    key: 'member_points.detail.empty',
    fallbackEn: 'No records',
    fallbackZh: '没有相关记录',
  );

  static const memberPointsDetailTypeDaily = RemoteTextSpec(
    key: 'member_points.detail.type.daily',
    fallbackEn: 'Daily VIP Points',
    fallbackZh: '每日会员积分',
  );

  static const memberPointsDetailTypePush = RemoteTextSpec(
    key: 'member_points.detail.type.push',
    fallbackEn: 'Enable notifications',
    fallbackZh: '打开通知',
  );

  static const memberPointsDetailTypeWatch = RemoteTextSpec(
    key: 'member_points.detail.type.watch',
    fallbackEn: 'Watch Reward',
    fallbackZh: '播放奖励',
  );

  static const memberPointsDetailTypeExchange = RemoteTextSpec(
    key: 'member_points.detail.type.exchange',
    fallbackEn: 'Redeem {days}-day VIP',
    fallbackZh: '兑换{days}日会员',
  );

  static const memberCenterButtonExchange = RemoteTextSpec(
    key: 'member_center.button.exchange',
    fallbackEn: 'Redeem',
    fallbackZh: '兑换',
  );

  static const memberCenterToastExchangeSuccess = RemoteTextSpec(
    key: 'member_center.toast.exchange_success',
    fallbackEn: 'Redeemed successfully',
    fallbackZh: '兑换成功',
  );

  static const memberCenterModalExchangeInsufficientPoints = RemoteTextSpec(
    key: 'member_center.modal.exchange.insufficient_points',
    fallbackEn: 'Insufficient points',
    fallbackZh: '积分不足',
  );

  static const memberCenterModalExchangeDaysMember = RemoteTextSpec(
    key: 'member_center.modal.exchange.days_member',
    fallbackEn: '{days}-Day Membership',
    fallbackZh: '{days}日会员',
  );

  static const memberCenterModalExchangePointsCost = RemoteTextSpec(
    key: 'member_center.modal.exchange.points_cost',
    fallbackEn: '{points} Member Points',
    fallbackZh: '{points} 会员积分',
  );

  static const memberCenterModalExchangeRules = RemoteTextSpec(
    key: 'member_center.modal.exchange.rules',
    fallbackEn:
        '1. After redemption, your current membership will be extended by {days} day(s).\n2. The redeemed membership duration will take effect after your store membership ends.\n3. Redeemed items are non-refundable.',
    fallbackZh: '1.兑换后，你当前的会员会被延长 {days} 天\n2.兑换的会员时长将在商店会员结束后开始生效\n3.商品兑换无法退款',
  );

  static const memberCenterModalExchangeConfirmButton = RemoteTextSpec(
    key: 'member_center.modal.exchange.confirm_button',
    fallbackEn: 'Confirm',
    fallbackZh: '确认',
  );

  static const memberCenterSectionVipDramas = RemoteTextSpec(
    key: 'member_center.section.vip_dramas',
    fallbackEn: 'VIP-exclusive Dramas',
    fallbackZh: '会员专享剧',
  );

  static const memberPointsSuccessTitle = RemoteTextSpec(
    key: 'member_points.success.title',
    fallbackEn: 'Claimed Successfully',
    fallbackZh: '领取成功',
  );
}
