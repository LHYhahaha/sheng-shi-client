import '../../../shared/media/media_resource.dart';

/// 登录渠道类型。
///
/// 枚举值用于 UI loading 和 repository 分发，不应直接映射第三方 SDK 的原始字符串；
/// SDK 字段变化应在 auth repository 内部适配。
enum AuthProviderType { device, google, facebook }

const authDefaultAvatarAssetPath =
    'assets/images/profile/profile_avatar_figma.png';

/// 已登录用户的最小资料。
///
/// 这里只放 Profile 页需要的稳定展示字段。token、refresh token 等敏感数据不要进入
/// 这个模型，避免被 UI 或日志无意暴露。
class AuthUser {
  const AuthUser({
    required this.id,
    required this.nickname,
    required this.avatarAssetPath,
    required this.provider,
    this.avatarResource,
  });

  /// 用户 id。
  ///
  /// 用于展示和账号页识别，不应承载 token 或设备标识。
  final String id;

  /// 用户昵称。
  ///
  /// ProfilePage 展示时从 AuthState 合成，不写回 ProfileState。
  final String nickname;

  /// 头像 asset 路径。
  ///
  /// 当前为 mock 本地资源；远程头像接入时仍应保持 UI 只读这个归一化字段。
  final String avatarAssetPath;

  /// 头像统一资源身份。
  ///
  /// 远程 profile/auth 会把 avatarUrl 映射为 network resource；当前 UI 仍使用
  /// avatarAssetPath，后续切网络头像时优先读此字段，不要把 URL 伪装成 asset path。
  final MediaResource? avatarResource;

  /// 登录来源渠道。
  ///
  /// 用于账号信息和排查登录问题，不用于权限判断。
  final AuthProviderType provider;
}

/// 认证会话。
///
/// guest 和 logged-in 都用同一模型表达，便于 logout/delete 后原子切回游客态。页面
/// 不要自行用 nullable user 推断全部账号状态，应通过 AuthState/AuthSession 读取。
class AuthSession {
  const AuthSession({required this.user});

  const AuthSession.guest() : user = null;

  /// 当前用户。
  ///
  /// null 表示游客 session，而不是“尚未加载”；是否加载中由 AuthState.isLoading 表达。
  final AuthUser? user;

  bool get isLoggedIn => user != null;
}
