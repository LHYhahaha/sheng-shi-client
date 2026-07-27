class WalletRewardCoinRecordDto {
  const WalletRewardCoinRecordDto({
    required this.recordId,
    required this.bonusCoin,
    required this.remainBonusCoin,
    required this.sourceName,
    required this.sourceType,
    required this.sourceOrderNo,
    required this.status,
    required this.startAt,
    required this.expireAt,
    required this.permanent,
  });

  final int recordId;
  final int bonusCoin;
  final int remainBonusCoin;
  final String sourceName;
  final int sourceType;
  final String sourceOrderNo;
  final int status;
  final DateTime? startAt;
  final DateTime? expireAt;
  final bool permanent;

  factory WalletRewardCoinRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletRewardCoinRecordDto(
      recordId: _int(map['recordId']),
      bonusCoin: _int(map['bonusCoin']),
      remainBonusCoin: _int(map['remainBonusCoin']),
      sourceName: _string(map['sourceName']),
      sourceType: _int(map['sourceType']),
      sourceOrderNo: _string(map['sourceOrderNo']),
      status: _int(map['status']),
      startAt: _date(map['startAt']),
      expireAt: _date(map['expireAt']),
      permanent: _bool(map['permanent']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _bool(Object? value) => value == true;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
