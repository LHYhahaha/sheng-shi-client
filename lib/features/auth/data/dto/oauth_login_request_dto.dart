class OAuthLoginRequestDto {
  const OAuthLoginRequestDto({
    required this.facebookToken,
  });

  final String facebookToken;

  Map<String, Object?> toJson() {
    return {
      'facebookToken': facebookToken,
    };
  }
}
