/// 剧集的解锁策略。
///
/// 这是内容/权益侧的业务策略，不是 UI 状态。播放器只能在 entitlement 判定允许后
/// 才能 open source；locked、会员、金币这些规则都不应写进 media session 控制器。
enum EpisodeUnlockType {
  /// 免费剧集，游客、会员、普通登录用户都可以直接播放。
  free,

  /// 会员剧集，只有已生效会员权益的账号可以播放。
  membership,

  /// 金币剧集，需要按单集价格解锁。
  ///
  /// 真实阶段扣费与解锁必须以后端为准，客户端本地扣金币只服务 mock 流程和测试。
  coins,
}
