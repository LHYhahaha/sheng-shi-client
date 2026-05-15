class RefreshTokenRequestDto {
  const RefreshTokenRequestDto({required this.refreshToken});

  final String refreshToken;

  Map<String, Object?> toJson() => {'refreshToken': refreshToken};
}
