class WalletSettingDto {
  const WalletSettingDto({required this.autoUnlockEnabled});

  final bool autoUnlockEnabled;

  factory WalletSettingDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletSettingDto(
      autoUnlockEnabled: map['autoUnlockEnabled'] == true,
    );
  }
}
