class WalletConsumptionRecordDto {
  const WalletConsumptionRecordDto({
    required this.id,
    required this.dramaId,
    required this.episodeId,
    required this.episodeNumber,
    required this.title,
    required this.coverUrl,
    required this.amountCoins,
    required this.sourceType,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String dramaId;
  final String episodeId;
  final int episodeNumber;
  final String title;
  final String? coverUrl;
  final int amountCoins;
  final String sourceType;
  final DateTime? createdAt;
  final String status;

  factory WalletConsumptionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletConsumptionRecordDto(
      id: _string(map['id']),
      dramaId: _string(map['dramaId']),
      episodeId: _string(map['episodeId']),
      episodeNumber: _int(map['episodeNumber']),
      title: _string(map['title']),
      coverUrl: _nullableString(map['coverUrl']),
      amountCoins: _int(map['amountCoins']),
      sourceType: _string(map['sourceType'], fallback: 'coins'),
      createdAt: _date(map['createdAt']),
      status: _string(map['status'], fallback: 'spent'),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
