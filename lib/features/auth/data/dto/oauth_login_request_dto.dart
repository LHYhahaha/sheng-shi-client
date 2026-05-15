class OAuthLoginRequestDto {
  const OAuthLoginRequestDto({
    required this.provider,
    this.idToken,
    this.accessToken,
    this.nonce,
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.lang,
  });

  final String provider;
  final String? idToken;
  final String? accessToken;
  final String? nonce;
  final String deviceId;
  final String platform;
  final String appVersion;
  final String lang;

  Map<String, Object?> toJson() {
    return {
      'provider': provider,
      if (idToken != null) 'idToken': idToken,
      if (accessToken != null) 'accessToken': accessToken,
      if (nonce != null) 'nonce': nonce,
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
      'lang': lang,
    };
  }
}
