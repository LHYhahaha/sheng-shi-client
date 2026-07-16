import '../../../../core/network/json_field_parser.dart';
import '../../domain/member_point_exchange_options.dart';

class MemberPointExchangeOptionsDto {
  const MemberPointExchangeOptionsDto({
    required this.balance,
    required this.isMember,
    required this.list,
  });

  final int balance;
  final bool isMember;
  final List<MemberPointExchangeTierDto> list;

  factory MemberPointExchangeOptionsDto.fromJson(Map<String, Object?> json) {
    return MemberPointExchangeOptionsDto(
      balance: JsonFieldParser.requireInt(
        json,
        'balance',
        dtoName: 'MemberPointExchangeOptionsDto',
      ),
      isMember: JsonFieldParser.requireBool(
        json,
        'isMember',
        dtoName: 'MemberPointExchangeOptionsDto',
      ),
      list:
          JsonFieldParser.requireList(
                json['list'],
                dtoName: 'MemberPointExchangeOptionsDto',
                field: 'list',
              )
              .map(
                (item) => MemberPointExchangeTierDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'MemberPointExchangeTierDto',
                  ),
                ),
              )
              .toList(growable: false),
    );
  }

  MemberPointExchangeOptions toDomain() => MemberPointExchangeOptions(
    balance: balance,
    isMember: isMember,
    list: list.map((item) => item.toDomain()).toList(growable: false),
  );
}

class MemberPointExchangeTierDto {
  const MemberPointExchangeTierDto({
    required this.canExchange,
    required this.displayName,
    required this.exchangeStatus,
    required this.memberDays,
    required this.pointCost,
    required this.priority,
    required this.status,
    required this.tierId,
  });

  final bool canExchange;
  final String displayName;
  final String exchangeStatus;
  final int memberDays;
  final int pointCost;
  final int priority;
  final int status;
  final int tierId;

  factory MemberPointExchangeTierDto.fromJson(Map<String, Object?> json) {
    return MemberPointExchangeTierDto(
      canExchange: JsonFieldParser.requireBool(
        json,
        'canExchange',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      displayName: JsonFieldParser.requireString(
        json,
        'displayName',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      exchangeStatus: JsonFieldParser.requireString(
        json,
        'exchangeStatus',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      memberDays: JsonFieldParser.requireInt(
        json,
        'memberDays',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      pointCost: JsonFieldParser.requireInt(
        json,
        'pointCost',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      priority: JsonFieldParser.requireInt(
        json,
        'priority',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      status: JsonFieldParser.requireInt(
        json,
        'status',
        dtoName: 'MemberPointExchangeTierDto',
      ),
      tierId: JsonFieldParser.requireInt(
        json,
        'tierId',
        dtoName: 'MemberPointExchangeTierDto',
      ),
    );
  }

  MemberPointExchangeTier toDomain() => MemberPointExchangeTier(
    canExchange: canExchange,
    displayName: displayName,
    exchangeStatus: exchangeStatus,
    memberDays: memberDays,
    pointCost: pointCost,
    priority: priority,
    status: status,
    tierId: tierId,
  );
}
