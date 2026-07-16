import '../../../../core/network/json_field_parser.dart';
import '../../domain/member_point_exchange_result.dart';

class MemberPointExchangeResultDto {
  const MemberPointExchangeResultDto({
    required this.exchangeNo,
    required this.memberDays,
    required this.pointBalance,
    required this.status,
  });

  final String exchangeNo;
  final int memberDays;
  final int pointBalance;
  final String status;

  factory MemberPointExchangeResultDto.fromJson(Map<String, Object?> json) {
    return MemberPointExchangeResultDto(
      exchangeNo: JsonFieldParser.requireString(
        json,
        'exchangeNo',
        dtoName: 'MemberPointExchangeResultDto',
      ),
      memberDays: JsonFieldParser.requireInt(
        json,
        'memberDays',
        dtoName: 'MemberPointExchangeResultDto',
      ),
      pointBalance: JsonFieldParser.requireInt(
        json,
        'pointBalance',
        dtoName: 'MemberPointExchangeResultDto',
      ),
      status: JsonFieldParser.requireString(
        json,
        'status',
        dtoName: 'MemberPointExchangeResultDto',
      ),
    );
  }

  MemberPointExchangeResult toDomain() => MemberPointExchangeResult(
    exchangeNo: exchangeNo,
    memberDays: memberDays,
    pointBalance: pointBalance,
    status: status,
  );
}
