import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_cleanup_types.dart';
import '../../auth/domain/auth_session.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

/// 我的页资料状态。
///
/// 这里保存会员卡、金币卡和语言入口等资料展示；登录身份由 AuthState 合成，不在
/// ProfileController 内部复制一份账号状态。
class ProfileState {
  const ProfileState({
    required this.isLoggedIn,
    required this.userId,
    required this.nickname,
    required this.avatarAssetPath,
    required this.membership,
    required this.coins,
    required this.language,
    this.needsSessionReload = false,
  });

  const ProfileState.mock()
    : isLoggedIn = false,
      userId = '15589299',
      nickname = null,
      avatarAssetPath = authDefaultAvatarAssetPath,
      membership = const ProfileMembershipState.mock(),
      coins = const ProfileCoinsState.mock(),
      language = const ProfileLanguageState.enabled(),
      needsSessionReload = false;

  /// 展示层登录态。
  ///
  /// ProfilePage 会用 AuthState 覆盖这个字段；ProfileController 自身不拥有登录真相。
  final bool isLoggedIn;

  /// 我的页展示用用户 id。
  ///
  /// mock 游客也有默认 id。已登录时由 AuthState.user 覆盖，避免 profile mock 残留旧账号。
  final String userId;

  /// 我的页展示昵称。
  ///
  /// null 时显示游客文案。不要把登录昵称写回 ProfileController，退出登录后会残留。
  final String? nickname;

  /// 头像资源路径。
  ///
  /// 当前使用本地 asset。后续远程头像也应通过 auth/profile 数据源统一转换，不要在 UI
  /// 层拼接 URL。
  final String avatarAssetPath;

  /// 会员卡展示数据。
  ///
  /// 只用于我的页卡片摘要，不作为播放器解锁依据。
  final ProfileMembershipState membership;

  /// 金币卡展示数据。
  ///
  /// 只用于我的页摘要和入口，不作为钱包真实余额来源。
  final ProfileCoinsState coins;

  /// 语言入口展示数据。
  ///
  /// 控制入口可用性；实际 Locale 由 AppLocaleController 管理。
  final ProfileLanguageState language;

  /// session cleanup 后标记需要重新拉取资料（真实 API 阶段由 repository reload）。
  final bool needsSessionReload;

  bool get canOpenMembership => membership.entryEnabled;

  bool get canOpenTopUp => coins.topUpEnabled;

  bool get canOpenLanguage => language.entryEnabled;

  ProfileState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? nickname,
    String? avatarAssetPath,
    bool? needsSessionReload,
  }) {
    return ProfileState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      nickname: nickname,
      avatarAssetPath: avatarAssetPath ?? this.avatarAssetPath,
      membership: membership,
      coins: coins,
      language: language,
      needsSessionReload: needsSessionReload ?? this.needsSessionReload,
    );
  }
}

/// 我的页会员卡展示状态。
///
/// 这是 profile 聚合后的展示数据，不是会员权益真实来源。真实权益仍应从 membership
/// feature 或服务端权益接口刷新。
class ProfileMembershipState {
  const ProfileMembershipState({
    required this.isActive,
    required this.entryEnabled,
    this.expiresAt,
  });

  const ProfileMembershipState.mock()
    : isActive = false,
      entryEnabled = true,
      expiresAt = null;

  /// 是否展示为已开通会员。
  ///
  /// 这是 profile 摘要态，不替代 membership feature 的权益状态。
  final bool isActive;

  /// 会员入口是否可点击。
  ///
  /// 用于后续灰度或地区限制；UI 不应直接根据套餐是否存在决定入口。
  final bool entryEnabled;

  /// 会员有效期展示。
  ///
  /// null 表示不展示有效期，不代表没有会员权益，真实权益以会员接口为准。
  final DateTime? expiresAt;
}

/// 我的页金币卡展示状态。
///
/// 金币展示用于入口和摘要，不能替代 WalletController 的钱包余额/流水来源。
class ProfileCoinsState {
  const ProfileCoinsState({
    required this.balance,
    required this.topUpEnabled,
    required this.walletEnabled,
  });

  const ProfileCoinsState.mock()
    : balance = 2000,
      topUpEnabled = true,
      walletEnabled = true;

  /// 我的页展示金币余额。
  ///
  /// 这是摘要值，可能滞后于钱包页真实刷新结果，不应用于扣费判断。
  final int balance;

  /// 充值入口是否可点击。
  ///
  /// 后续支付灰度或地区限制应改这个字段，而不是在 UI 隐式判断。
  final bool topUpEnabled;

  /// 钱包入口是否可点击。
  ///
  /// 控制是否允许进入流水页，和余额是否为 0 没有直接关系。
  final bool walletEnabled;
}

/// 语言入口展示状态。
///
/// 这里只控制入口是否可点和当前文案，不负责保存 Locale。
class ProfileLanguageState {
  const ProfileLanguageState({required this.entryEnabled});

  const ProfileLanguageState.enabled() : entryEnabled = true;

  /// 语言设置入口是否可点击。
  ///
  /// 未来如果某些包或地区锁定语言，可以通过这个字段控制入口，而不是删除页面路由。
  final bool entryEnabled;
}

/// Profile mock 控制器。
///
/// 当前返回静态资料。登录态在 ProfilePage 由 AuthState 覆盖展示，避免 logout/delete
/// 后 profile mock 数据把用户重新“显示成登录”。
class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState.mock();

  /// 回到 mock 游客资料摘要，并标记下次进入我的页应重新加载。
  void resetForSessionCleanup(SessionCleanupReason reason) {
    state = const ProfileState.mock().copyWith(needsSessionReload: true);
  }
}
