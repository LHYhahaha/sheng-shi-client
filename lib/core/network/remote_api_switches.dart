import 'remote_api_module.dart';

/// 编译期 remote API 开关集合（统一读取入口）。
///
/// 默认全部为 `false`。`drama` 另兼容早期 `USE_REMOTE_API`。
class RemoteApiSwitches {
  const RemoteApiSwitches({
    this.drama = false,
    this.player = false,
    this.myList = false,
    this.profile = false,
    this.wallet = false,
    this.store = false,
    this.membership = false,
    this.entitlement = false,
    this.auth = false,
    this.legacyUseRemoteApi = false,
  });

  /// 全部为 false（默认安全态）。
  static const RemoteApiSwitches allDisabled = RemoteApiSwitches();

  final bool drama;
  final bool player;
  final bool myList;
  final bool profile;
  final bool wallet;
  final bool store;
  final bool membership;
  final bool entitlement;
  final bool auth;

  /// Phase A 早期通用开关；仅映射到 [drama]。
  final bool legacyUseRemoteApi;

  /// Home/Drama：scoped 或 legacy。
  bool get dramaEnabled => drama || legacyUseRemoteApi;

  /// 从 `--dart-define=USE_REMOTE_*` 读取（编译期常量）。
  static RemoteApiSwitches fromEnvironment() {
    return RemoteApiSwitches(
      drama: _envBool('USE_REMOTE_DRAMA_API'),
      player: _envBool('USE_REMOTE_PLAYER_API'),
      myList: _envBool('USE_REMOTE_MY_LIST_API'),
      profile: _envBool('USE_REMOTE_PROFILE_API'),
      wallet: _envBool('USE_REMOTE_WALLET_API'),
      store: _envBool('USE_REMOTE_STORE_API'),
      membership: _envBool('USE_REMOTE_MEMBERSHIP_API'),
      entitlement: _envBool('USE_REMOTE_ENTITLEMENT_API'),
      auth: _envBool('USE_REMOTE_AUTH_API'),
      legacyUseRemoteApi: _envBool('USE_REMOTE_API'),
    );
  }

  bool isEnabled(RemoteApiModule module) => switch (module) {
    RemoteApiModule.drama => dramaEnabled,
    RemoteApiModule.player => player,
    RemoteApiModule.myList => myList,
    RemoteApiModule.profile => profile,
    RemoteApiModule.wallet => wallet,
    RemoteApiModule.store => store,
    RemoteApiModule.membership => membership,
    RemoteApiModule.entitlement => entitlement,
    RemoteApiModule.auth => auth,
  };

  bool get anyEnabled => RemoteApiModule.values.any(isEnabled);

  Iterable<RemoteApiModule> get enabledModules =>
      RemoteApiModule.values.where(isEnabled);

  RemoteApiSwitches withModule(RemoteApiModule module, bool enabled) {
    return switch (module) {
      RemoteApiModule.drama => copyWith(
        drama: enabled,
        legacyUseRemoteApi: false,
      ),
      RemoteApiModule.player => copyWith(player: enabled),
      RemoteApiModule.myList => copyWith(myList: enabled),
      RemoteApiModule.profile => copyWith(profile: enabled),
      RemoteApiModule.wallet => copyWith(wallet: enabled),
      RemoteApiModule.store => copyWith(store: enabled),
      RemoteApiModule.membership => copyWith(membership: enabled),
      RemoteApiModule.entitlement => copyWith(entitlement: enabled),
      RemoteApiModule.auth => copyWith(auth: enabled),
    };
  }

  RemoteApiSwitches copyWith({
    bool? drama,
    bool? player,
    bool? myList,
    bool? profile,
    bool? wallet,
    bool? store,
    bool? membership,
    bool? entitlement,
    bool? auth,
    bool? legacyUseRemoteApi,
  }) {
    return RemoteApiSwitches(
      drama: drama ?? this.drama,
      player: player ?? this.player,
      myList: myList ?? this.myList,
      profile: profile ?? this.profile,
      wallet: wallet ?? this.wallet,
      store: store ?? this.store,
      membership: membership ?? this.membership,
      entitlement: entitlement ?? this.entitlement,
      auth: auth ?? this.auth,
      legacyUseRemoteApi: legacyUseRemoteApi ?? this.legacyUseRemoteApi,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RemoteApiSwitches &&
        other.drama == drama &&
        other.player == player &&
        other.myList == myList &&
        other.profile == profile &&
        other.wallet == wallet &&
        other.store == store &&
        other.membership == membership &&
        other.entitlement == entitlement &&
        other.auth == auth &&
        other.legacyUseRemoteApi == legacyUseRemoteApi;
  }

  @override
  int get hashCode => Object.hash(
    drama,
    player,
    myList,
    profile,
    wallet,
    store,
    membership,
    entitlement,
    auth,
    legacyUseRemoteApi,
  );
}

bool _envBool(String key) => bool.fromEnvironment(key);
