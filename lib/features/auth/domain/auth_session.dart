enum AuthProviderType { device, google, facebook }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.nickname,
    required this.avatarAssetPath,
    required this.provider,
  });

  final String id;
  final String nickname;
  final String avatarAssetPath;
  final AuthProviderType provider;
}

class AuthSession {
  const AuthSession({required this.user});

  const AuthSession.guest() : user = null;

  final AuthUser? user;

  bool get isLoggedIn => user != null;
}
