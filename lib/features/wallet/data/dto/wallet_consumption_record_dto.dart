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
    this.bonusCoin,
    this.coin,
    this.rechargeCoin,
    this.recordId,
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

  // 新 API 格式的额外字段
  final int? bonusCoin;
  final int? coin;
  final int? rechargeCoin;
  final int? recordId;

  factory WalletConsumptionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};

    // 适配两种格式：
    // 1. Mock 格式：id, dramaId, episodeId, episodeNumber, title, coverUrl, amountCoins, sourceType, createdAt, status
    // 2. 新 API 格式：recordId, shortId, episodeId, episodeNo, shortTitle, cover, coin, bonusCoin, rechargeCoin, consumedAt

    final isMockFormat = map.containsKey('id') && map.containsKey('dramaId');
    return WalletConsumptionRecordDto(
      id: isMockFormat ? _string(map['id']) : _string(map['recordId']),
      dramaId: _string(map['dramaId']),
      episodeId: _string(map['episodeId']),
      episodeNumber: isMockFormat
          ? _int(map['episodeNumber'])
          : _int(map['episodeNo']),
      title: isMockFormat ? _string(map['title']) : _string(map['shortTitle']),
      coverUrl: isMockFormat
          ? _nullableString(map['coverUrl'])
          : _nullableString(map['cover']),
      amountCoins: _int(map['coin']),
      sourceType: _string(map['sourceType'], fallback: 'coins'),
      createdAt: isMockFormat
          ? _date(map['createdAt'])
          : _date(map['consumedAt']),
      status: _string(map['status'], fallback: 'spent'),
      bonusCoin: _nullableInt(map['bonusCoin']),
      coin: _nullableInt(map['coin']),
      rechargeCoin: _nullableInt(map['rechargeCoin']),
      recordId: _nullableInt(map['recordId']),
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
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    final hasExplicitOffset = RegExp(
      r'(?:Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return hasExplicitOffset
        ? parsed.toUtc()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
  }
  return null;
}
