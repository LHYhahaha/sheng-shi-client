import '../../../../core/network/json_field_parser.dart';
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
    final map = JsonFieldParser.requireMap(json, dtoName: 'WalletDto');
    const dtoName = 'WalletDto';
    return WalletDto(
      coinBalance: JsonFieldParser.requireInt(
        map,
        'coinBalance',
        dtoName: dtoName,
      ),
      bonusBalance: JsonFieldParser.requireInt(
        map,
        'bonusBalance',
        dtoName: dtoName,
      ),
      autoUnlockEnabled: JsonFieldParser.requireBool(
        map,
        'autoUnlockEnabled',
        dtoName: dtoName,
      ),
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

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
