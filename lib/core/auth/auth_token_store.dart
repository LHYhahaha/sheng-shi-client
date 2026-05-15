import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth token 的内存快照。
///
/// 这是网络层读取 Authorization 的唯一 token 来源。token 不进入
/// presentation/application，也不放进 AuthSession。真实阶段替换为 secure storage 时，
/// 仍应保持这个快照边界，让 ApiRequestContext 只读取脱敏后的当前状态。
class AuthTokenSnapshot {
  const AuthTokenSnapshot({
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.refreshExpiresAt,
  });

  const AuthTokenSnapshot.empty()
    : accessToken = null,
      refreshToken = null,
      tokenType = 'Bearer',
      expiresAt = null,
      refreshExpiresAt = null;

  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;
}

final authTokenStoreProvider =
    NotifierProvider<AuthTokenStore, AuthTokenSnapshot>(AuthTokenStore.new);

/// Token storage skeleton。
///
/// 当前只做 in-memory store，满足远程骨架和测试。后续接 secure storage 时应在这里
/// hydrate/persist/clear，不要让 feature repository 或 UI 自己保存 token。
class AuthTokenStore extends Notifier<AuthTokenSnapshot> {
  @override
  AuthTokenSnapshot build() => const AuthTokenSnapshot.empty();

  Future<void> save(AuthTokenSnapshot token) async {
    state = token;
  }

  Future<void> clear() async {
    state = const AuthTokenSnapshot.empty();
  }
}
