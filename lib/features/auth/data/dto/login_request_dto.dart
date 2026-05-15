class LoginRequestDto {
  const LoginRequestDto({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.lang,
  });

  final String deviceId;
  final String platform;
  final String appVersion;
  final String lang;

  Map<String, Object?> toJson() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
      'lang': lang,
    };
  }
}
