/// Apple 服务端登录请求。
///
/// [identityToken] 必填；其余字段只会在 Apple 首次授权时可用。
class AppleLoginRequestDto {
  const AppleLoginRequestDto({
    required this.identityToken,
    this.authorizationCode,
    this.email,
    this.fullName,
  });

  final String identityToken;
  final String? authorizationCode;
  final String? email;
  final String? fullName;

  Map<String, Object?> toJson() => {
    'identityToken': identityToken,
    if (authorizationCode != null) 'authorizationCode': authorizationCode,
    if (email != null) 'email': email,
    if (fullName != null) 'fullName': fullName,
  };
}
