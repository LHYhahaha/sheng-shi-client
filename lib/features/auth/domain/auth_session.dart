import '../../../shared/media/media_resource.dart';

/// 登录渠道类型。
///
/// 枚举值用于 UI loading 和 repository 分发，不应直接映射第三方 SDK 的原始字符串；
/// SDK 字段变化应在 auth repository 内部适配。
enum AuthProviderType { device, google, facebook }

/// 客户端感知的 session 种类（展示与流程分支，不含 token）。
///
/// - [guest]：游客账户 session（可有 guest access token，不是“无 session”）。
/// - [authenticated]：account link 后的正式用户。
/// - [recovering]：cleanup 之后、guest bootstrap 完成前的过渡态。
enum AuthSessionKind { guest, authenticated, recovering }

const authDefaultAvatarAssetPath =
    'assets/images/profile/profile_avatar_figma.png';

/// 已登录用户的最小资料。
///
/// 这里只放 Profile 页需要的稳定展示字段。token、refresh token 等敏感数据不要进入
/// 这个模型，避免被 UI 或日志无意暴露。
class AuthUser {
  const AuthUser({
    String? userId,
    @Deprecated('Use userId instead.') String? id,
    required this.nickname,
    required this.avatarAssetPath,
    required this.provider,
    this.avatarResource,
    this.showId,
    this.language,
    this.status,
    this.vipExpireAt,
    this.coin,
    this.bonusCoin,
    this.autoUnlock,
  }) : assert(userId != null || id != null),
       userId = userId ?? id ?? '';

  /// 服务端业务用户 ID（int64 数值字符串），仅用于后台请求、数据隔离和归因绑定。
  ///
  /// 不能用于 UI 展示；展示账号标识请使用 [showId]。
  final String userId;

  /// 兼容旧调用点；新代码必须使用 [userId]。
  @Deprecated('Use userId instead.')
  String get id => userId;

  final String nickname;
  final String avatarAssetPath;
  final MediaResource? avatarResource;
  final AuthProviderType provider;

  /// 用户可见的展示账号 ID，不可作为后台业务用户 ID。
  final String? showId;

  /// 用户语言设置
  final String? language;

  /// 用户状态
  final int? status;

  /// VIP 过期时间
  final String? vipExpireAt;

  /// 用户金币
  final int? coin;

  /// 用户奖励金币
  final int? bonusCoin;

  /// 自动解锁
  final int? autoUnlock;
}

/// 认证会话（UI / application 可见层）。
///
/// 产品模型：App 启动后默认 **游客 session**；主动登录是 guest → 正式账号的 **account
/// link**，不是从无用户变为有用户。logout / refresh 失败后应回到 guest bootstrap，
/// 而不是“完全空用户”。
///
/// 边界：
/// - [sessionId]：服务端 session 标识（游客或正式均可）。
/// - [guestId]：游客身份锚点，account link 时随登录请求带给服务端做数据合并。
/// - [deviceId]：由 [ApiRequestContext] 的 Device-Id header 承载，不在此重复存储。
/// - refresh/access token：仅在 [AuthTokenStore] / [AuthTokenSnapshot]，不进 UI。
class AuthSession {
  const AuthSession({required this.user, this.sessionId, this.guestId})
    : kind = AuthSessionKind.authenticated;

  const AuthSession.guest({this.sessionId, this.guestId})
    : user = null,
      kind = AuthSessionKind.guest;

  const AuthSession.recovering({this.sessionId, this.guestId})
    : user = null,
      kind = AuthSessionKind.recovering;

  final AuthUser? user;
  final AuthSessionKind kind;

  /// 服务端 session id（游客或正式用户）。
  final String? sessionId;

  /// 游客 id，account link 时传给服务端；正式登录后是否保留由服务端策略决定。
  final String? guestId;

  bool get isLoggedIn => kind == AuthSessionKind.authenticated && user != null;

  bool get isGuest => kind == AuthSessionKind.guest;

  bool get isRecovering => kind == AuthSessionKind.recovering;

  bool get hasLinkedAccount => isLoggedIn;
}
