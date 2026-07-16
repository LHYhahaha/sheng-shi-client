import '../../../../core/network/json_field_parser.dart';
import '../../domain/member_point_details.dart';

class MemberPointDetailsPageDto {
  const MemberPointDetailsPageDto({
    required this.list,
    required this.page,
    required this.pageSize,
    required this.totalNum,
  });

  final List<MemberPointDetailRecordDto> list;
  final int page;
  final int pageSize;
  final int totalNum;

  factory MemberPointDetailsPageDto.fromJson(Map<String, Object?> json) {
    return MemberPointDetailsPageDto(
      list:
          JsonFieldParser.requireList(
                json['list'],
                dtoName: 'MemberPointDetailsPageDto',
                field: 'list',
              )
              .map(
                (item) => MemberPointDetailRecordDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'MemberPointDetailRecordDto',
                  ),
                ),
              )
              .toList(growable: false),
      page: JsonFieldParser.requireInt(
        json,
        'page',
        dtoName: 'MemberPointDetailsPageDto',
      ),
      pageSize: _requireIntByKeys(json, const [
        'pageSize',
        'page_size',
      ], dtoName: 'MemberPointDetailsPageDto'),
      totalNum: _requireIntByKeys(json, const [
        'totalNum',
        'total_num',
      ], dtoName: 'MemberPointDetailsPageDto'),
    );
  }

  MemberPointDetailsPage toDomain() => MemberPointDetailsPage(
    list: list.map((item) => item.toDomain()).toList(growable: false),
    page: page,
    pageSize: pageSize,
    totalNum: totalNum,
  );
}

int _requireIntByKeys(
  Map<String, Object?> json,
  List<String> keys, {
  required String dtoName,
}) {
  for (final key in keys) {
    final value = JsonFieldParser.optionalInt(json, key);
    if (value != null) {
      return value;
    }
  }
  return JsonFieldParser.requireInt(json, keys.first, dtoName: dtoName);
}

class MemberPointDetailRecordDto {
  const MemberPointDetailRecordDto({
    required this.amount,
    required this.balanceAfter,
    required this.balanceBefore,
    required this.bizType,
    required this.createdAt,
    required this.direction,
    required this.flowNo,
    required this.remark,
  });

  final int amount;
  final int balanceAfter;
  final int balanceBefore;
  final int bizType;
  final DateTime createdAt;
  final int direction;
  final String flowNo;
  final String remark;

  factory MemberPointDetailRecordDto.fromJson(Map<String, Object?> json) {
    return MemberPointDetailRecordDto(
      amount: JsonFieldParser.requireInt(
        json,
        'amount',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      balanceAfter: JsonFieldParser.requireInt(
        json,
        'balanceAfter',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      balanceBefore: JsonFieldParser.requireInt(
        json,
        'balanceBefore',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      bizType: JsonFieldParser.requireInt(
        json,
        'bizType',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      createdAt: DateTime.parse(
        JsonFieldParser.requireString(
          json,
          'createdAt',
          dtoName: 'MemberPointDetailRecordDto',
        ),
      ),
      direction: JsonFieldParser.requireInt(
        json,
        'direction',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      flowNo: JsonFieldParser.requireString(
        json,
        'flowNo',
        dtoName: 'MemberPointDetailRecordDto',
      ),
      remark: JsonFieldParser.requireString(
        json,
        'remark',
        dtoName: 'MemberPointDetailRecordDto',
      ),
    );
  }

  MemberPointDetailRecord toDomain() => MemberPointDetailRecord(
    amount: amount,
    balanceAfter: balanceAfter,
    balanceBefore: balanceBefore,
    bizType: bizType,
    createdAt: createdAt,
    direction: direction,
    flowNo: flowNo,
    remark: remark,
  );
}
