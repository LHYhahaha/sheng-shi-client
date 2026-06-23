import 'auth_session.dart';

/// 账号注销结果。
///
/// 包含注销后的 session 和是否需要退出App的标识。
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.session,
    required this.shouldExitApp,
  });

  /// 注销后的认证会话。
  final AuthSession session;

  /// 是否需要退出App。
  ///
  /// - `true`：注销的是当前设备账号或游客账号，需要清掉数据后直接退出App
  /// - `false`：注销的是三方登录账号，退出三方登录后返回me页面
  final bool shouldExitApp;
}
