import '../../../../core/network/json_field_parser.dart';
import '../../domain/member_point_claim_result.dart';

class MemberPointClaimResultDto {
  const MemberPointClaimResultDto({
    required this.claimNo,
    required this.grantedAt,
    required this.pointBalance,
    required this.rewardAmount,
    required this.status,
  });

  final String claimNo;
  final String grantedAt;
  final int pointBalance;
  final int rewardAmount;
  final String status;

  factory MemberPointClaimResultDto.fromJson(Map<String, Object?> json) {
    return MemberPointClaimResultDto(
      claimNo: JsonFieldParser.requireString(
        json,
        'claimNo',
        dtoName: 'MemberPointClaimResultDto',
      ),
      grantedAt: JsonFieldParser.requireString(
        json,
        'grantedAt',
        dtoName: 'MemberPointClaimResultDto',
      ),
      pointBalance: JsonFieldParser.requireInt(
        json,
        'pointBalance',
        dtoName: 'MemberPointClaimResultDto',
      ),
      rewardAmount: JsonFieldParser.requireInt(
        json,
        'rewardAmount',
        dtoName: 'MemberPointClaimResultDto',
      ),
      status: JsonFieldParser.requireString(
        json,
        'status',
        dtoName: 'MemberPointClaimResultDto',
      ),
    );
  }

  MemberPointClaimResult toDomain() => MemberPointClaimResult(
    claimNo: claimNo,
    grantedAt: grantedAt,
    pointBalance: pointBalance,
    rewardAmount: rewardAmount,
    status: status,
  );
}
