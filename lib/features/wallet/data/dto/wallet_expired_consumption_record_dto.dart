class WalletExpiredConsumptionRecordDto {
  const WalletExpiredConsumptionRecordDto({
    required this.recordId,
    required this.expireAt,
    required this.expireCoin,
    required this.sourceName,
    required this.sourceType,
    required this.title,
  });

  final String recordId;
  final DateTime? expireAt;
  final String expireCoin;
  final String sourceName;
  final int sourceType;
  final String title;

  factory WalletExpiredConsumptionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletExpiredConsumptionRecordDto(
      recordId: _string(map['recordId']),
      expireAt: _date(map['expireAt']),
      expireCoin: _string(map['expireCoin']),
      sourceName: _string(map['sourceName']),
      sourceType: _int(map['sourceType']),
      title: _string(map['title']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
