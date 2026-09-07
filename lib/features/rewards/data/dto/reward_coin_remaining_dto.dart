import '../../../../core/network/json_field_parser.dart';
import '../../domain/reward_coin_remaining.dart';

class RewardCoinRemainingDto {
  const RewardCoinRemainingDto({required this.remainingCoin});

  final String remainingCoin;

  factory RewardCoinRemainingDto.fromJson(Map<String, Object?> json) {
    return RewardCoinRemainingDto(
      remainingCoin: JsonFieldParser.requireString(
        json,
        'remainingCoin',
        dtoName: 'RewardCoinRemainingDto',
      ),
    );
  }

  RewardCoinRemaining toDomain() => RewardCoinRemaining(value: remainingCoin);
}
