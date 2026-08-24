class WalletSpentConsumptionRecordDto {
  const WalletSpentConsumptionRecordDto({
    required this.recordId,
    required this.amount,
    required this.consumedAt,
    required this.cover,
    required this.dramaId,
    required this.episodeId,
    required this.episodeNo,
    required this.shortTitle,
    required this.type,
  });

  final String recordId;
  final String amount;
  final DateTime? consumedAt;
  final String? cover;
  final String dramaId;
  final String episodeId;
  final int episodeNo;
  final String shortTitle;
  final int type;

  factory WalletSpentConsumptionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletSpentConsumptionRecordDto(
      recordId: _string(map['recordId']),
      amount: _string(map['amount']),
      consumedAt: _date(map['consumedAt']),
      cover: _nullableString(map['cover']),
      dramaId: _string(map['dramaId']),
      episodeId: _string(map['episodeId']),
      episodeNo: _int(map['episodeNo']),
      shortTitle: _string(map['shortTitle']),
      type: _int(map['type']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';
String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
