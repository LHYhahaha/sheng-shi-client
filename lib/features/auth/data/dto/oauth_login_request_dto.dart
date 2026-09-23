class OAuthLoginRequestDto {
  const OAuthLoginRequestDto({required this.provider, required this.token});

  final String provider;
  final String token;

  Map<String, Object?> toJson() {
    return switch (provider) {
      'google' => {'googleToken': token},
      'facebook' => {'facebookToken': token},
      'apple' => {'identityToken': token},
      _ => throw ArgumentError.value(
        provider,
        'provider',
        'Unsupported OAuth provider',
      ),
    };
  }
}
