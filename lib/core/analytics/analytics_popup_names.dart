/// 弹框名称字典（腾讯埋点文档 tab=000007）。
///
/// 所有 `popup_show` / `popup_close` 调用均应使用这里的常量，避免名称拼写不一致。
abstract final class AnalyticsPopupNames {
  static const episodeSelector = 'episode_selector_popup';
  static const episodeUnlockConfirm = 'episode_unlock_confirm_popup';
  static const recharge = 'recharge_popup';
  static const payment = 'payment_popup';
  static const fixedCampaign = 'fixed_campaign_popup';
  static const dramaExitRecommend = 'drama_exit_recommend_popup';
  static const adUnlock = 'ad_unlock_popup';
  static const share = 'share_popup';
  static const memberPointsExchangeConfirm =
      'member_points_exchange_confirm_popup';
}
