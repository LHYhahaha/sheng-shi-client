import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_cleanup_types.dart';

final guestSessionBootstrapProvider = Provider<GuestSessionBootstrap>((ref) {
  return const GuestSessionBootstrap();
});

/// logout / refresh 失败 / session expired 之后的游客 session 恢复入口。
///
/// 产品模型：App 始终处于某种有效 session（游客或正式用户），不是传统 logged-out 空态。
/// 真实阶段应调用服务端 guest bootstrap（如 `POST /auth/guest/session`），写入 guest
/// token，并驱动 AuthRepository / feature reload。本轮不接网络，仅保留 hook 与文档。
class GuestSessionBootstrap {
  const GuestSessionBootstrap();

  /// cleanup 完成后尝试恢复 guest session。
  ///
  /// 推荐策略（文档约定，待服务端确认）：logout / refreshFailed 后 **重新 bootstrap
  /// 新 guest session**（同一 deviceId），不保留已失效的 authenticated token。
  /// 客户端随后以 guest token 拉取 guest-safe 的 entitlement / feed 等数据。
  Future<void> bootstrapAfterSessionCleanup(SessionCleanupReason reason) async {
    // TODO(real-api): POST guest bootstrap via ApiClient (authPolicy=none); headers 含
    // Device-Id（[installIdProvider] 持久化 install id，非硬件 ID）、Lang、Platform、
    // App-Version。Body 可带 deviceId / platform / lang / appVersion；可选 prior guestId。
    // TODO(real-api): persist guest AuthTokenSnapshot (sessionKind=guest).
    // TODO(real-api): AuthController -> AuthSession.guest(sessionId, guestId).
    // TODO(real-api): reload entitlement / wallet / profile / my list / progress.
  }
}
