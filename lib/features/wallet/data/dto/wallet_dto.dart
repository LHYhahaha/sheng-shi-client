import '../../../../core/network/json_field_parser.dart';
import 'wallet_consumption_record_dto.dart';
import 'wallet_reward_coin_record_dto.dart';
import 'wallet_transaction_record_dto.dart';

class WalletDto {
  const WalletDto({
    required this.coinBalance,
    required this.bonusBalance,
    required this.totalCoin,
    required this.autoUnlockEnabled,
    required this.transactionRecords,
    required this.consumptionRecords,
    required this.rewardCoinRecords,
  });

  final int coinBalance;
  final int bonusBalance;
  final int totalCoin;
  final bool autoUnlockEnabled;
  final List<WalletTransactionRecordDto> transactionRecords;
  final List<WalletConsumptionRecordDto> consumptionRecords;
  final List<WalletRewardCoinRecordDto> rewardCoinRecords;

  factory WalletDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'WalletDto');
    return WalletDto(
      // 适配当前 API 返回格式：coin -> coinBalance, bonusCoin -> bonusBalance
      coinBalance: JsonFieldParser.optionalInt(map, 'coin') ??
          JsonFieldParser.optionalInt(map, 'coinBalance') ??
          0,
      bonusBalance: JsonFieldParser.optionalInt(map, 'bonusCoin') ??
          JsonFieldParser.optionalInt(map, 'bonusBalance') ??
          0,
      totalCoin: JsonFieldParser.optionalInt(map, 'totalCoin') ?? 0,
      autoUnlockEnabled:
          JsonFieldParser.optionalBool(map, 'autoUnlockEnabled') ?? false,
      // 记录字段可能不在钱包余额接口中返回，使用空列表作为默认值
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
