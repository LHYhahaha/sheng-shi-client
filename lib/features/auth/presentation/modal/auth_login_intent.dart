/// 登录弹窗触发意图。
enum AuthLoginIntent {
  /// 用户主动点击登录入口。
  userInitiated,

  /// 业务动作要求正式用户身份。
  loginRequired,

  /// 会话失效后由页面在用户操作时提示登录（不自动弹）。
  sessionExpiredPrompt,
}

/// 需要登录的原因（用于文案与 analytics source）。
enum AuthLoginRequiredReason {
  profile,
  wallet,
  myList,
  store,
  storeRestore,
  player,
  orders,
  deleteAccount,
  generic,
}
