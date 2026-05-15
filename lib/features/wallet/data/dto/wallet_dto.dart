import 'wallet_consumption_record_dto.dart';
import 'wallet_reward_coin_record_dto.dart';
import 'wallet_transaction_record_dto.dart';

class WalletDto {
  const WalletDto({
    required this.coinBalance,
    required this.bonusBalance,
    required this.autoUnlockEnabled,
    required this.transactionRecords,
    required this.consumptionRecords,
    required this.rewardCoinRecords,
  });

  final int coinBalance;
  final int bonusBalance;
  final bool autoUnlockEnabled;
  final List<WalletTransactionRecordDto> transactionRecords;
  final List<WalletConsumptionRecordDto> consumptionRecords;
  final List<WalletRewardCoinRecordDto> rewardCoinRecords;

  factory WalletDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletDto(
      coinBalance: _int(map['coinBalance']),
      bonusBalance: _int(map['bonusBalance']),
      autoUnlockEnabled: map['autoUnlockEnabled'] == true,
      transactionRecords: _list(
        map['transactionRecords'],
        WalletTransactionRecordDto.fromJson,
      ),
      consumptionRecords: _list(
        map['consumptionRecords'],
        WalletConsumptionRecordDto.fromJson,
      ),
      rewardCoinRecords: _list(
        map['rewardCoinRecords'],
        WalletRewardCoinRecordDto.fromJson,
      ),
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) {
    return value.map(mapper).toList(growable: false);
  }
  return <T>[];
}
