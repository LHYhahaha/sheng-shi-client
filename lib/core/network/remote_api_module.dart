/// 可独立开关的远程 API 业务域（与 `USE_REMOTE_*` dart-define 一一对应）。
enum RemoteApiModule {
  drama,
  player,
  myList,
  profile,
  wallet,
  store,
  membership,
  entitlement,
  auth,
}

/// 联调风险分级（A8 guard 策略）。
enum RemoteApiRiskLevel {
  /// Home / Drama 只读内容。
  low,

  /// Player 内容、片单、Profile 等。
  medium,

  /// Auth、权益、钱包、商店、会员、支付。
  high,
}

extension RemoteApiModuleRisk on RemoteApiModule {
  RemoteApiRiskLevel get riskLevel => switch (this) {
    RemoteApiModule.drama => RemoteApiRiskLevel.low,
    RemoteApiModule.player ||
    RemoteApiModule.myList ||
    RemoteApiModule.profile => RemoteApiRiskLevel.medium,
    RemoteApiModule.wallet ||
    RemoteApiModule.store ||
    RemoteApiModule.membership ||
    RemoteApiModule.entitlement ||
    RemoteApiModule.auth => RemoteApiRiskLevel.high,
  };

  /// `USE_REMOTE_*` dart-define 名称（drama 另兼容 `USE_REMOTE_API`）。
  String get dartDefineKey => switch (this) {
    RemoteApiModule.drama => 'USE_REMOTE_DRAMA_API',
    RemoteApiModule.player => 'USE_REMOTE_PLAYER_API',
    RemoteApiModule.myList => 'USE_REMOTE_MY_LIST_API',
    RemoteApiModule.profile => 'USE_REMOTE_PROFILE_API',
    RemoteApiModule.wallet => 'USE_REMOTE_WALLET_API',
    RemoteApiModule.store => 'USE_REMOTE_STORE_API',
    RemoteApiModule.membership => 'USE_REMOTE_MEMBERSHIP_API',
    RemoteApiModule.entitlement => 'USE_REMOTE_ENTITLEMENT_API',
    RemoteApiModule.auth => 'USE_REMOTE_AUTH_API',
  };
}
