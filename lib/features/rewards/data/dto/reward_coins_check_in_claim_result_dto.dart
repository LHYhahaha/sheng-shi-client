import '../../../../core/network/json_field_parser.dart';
import '../../domain/reward_coins_check_in_claim_result.dart';

class RewardCoinsCheckInClaimResultDto {
  const RewardCoinsCheckInClaimResultDto({
    required this.balance,
    required this.claimNo,
    required this.grantedAt,
    required this.rewardAmount,
    required this.rewardType,
    required this.status,
  });

  final int balance;
  final String claimNo;
  final String grantedAt;
  final int rewardAmount;
  final String rewardType;
  final String status;

  factory RewardCoinsCheckInClaimResultDto.fromJson(Map<String, Object?> json) {
    return RewardCoinsCheckInClaimResultDto(
      balance: JsonFieldParser.requireInt(
        json,
        'balance',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
      claimNo: JsonFieldParser.requireString(
        json,
        'claimNo',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
      grantedAt: JsonFieldParser.requireString(
        json,
        'grantedAt',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
      rewardAmount: JsonFieldParser.requireInt(
        json,
        'rewardAmount',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
      rewardType: JsonFieldParser.requireString(
        json,
        'rewardType',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
      status: JsonFieldParser.requireString(
        json,
        'status',
        dtoName: 'RewardCoinsCheckInClaimResultDto',
      ),
    );
  }

  RewardCoinsCheckInClaimResult toDomain() => RewardCoinsCheckInClaimResult(
    balance: balance,
    claimNo: claimNo,
    grantedAt: grantedAt,
    rewardAmount: rewardAmount,
    rewardType: rewardType,
    status: status,
  );
}
