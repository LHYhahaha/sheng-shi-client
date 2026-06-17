import '../../../../core/network/json_field_parser.dart';

/// 会员产品DTO
/// 
/// 对应API返回的 `/api/payment/recharge/page` 中的 `memberProducts` 字段。
class MemberProductDto {
  const MemberProductDto({
    required this.productId,
    required this.channelProductId,
    required this.payChannel,
    required this.periodType,
    required this.periodValue,
    required this.priceText,
    this.originalPriceText,
    this.productName,
    this.promotionText,
    this.promotionExpireSeconds,
    required this.sort,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String productId;
  final String channelProductId;
  final String payChannel;
  final String periodType;
  final int periodValue;
  final String priceText;
  final String? originalPriceText;
  final String? productName;
  final String? promotionText;
  final String? promotionExpireSeconds;
  final int sort;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MemberProductDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'MemberProductDto',
    );
    const dtoName = 'MemberProductDto';
    
    return MemberProductDto(
      productId: JsonFieldParser.requireString(
        map,
        'productId',
        dtoName: dtoName,
      ),
      channelProductId: JsonFieldParser.requireString(
        map,
        'channelProductId',
        dtoName: dtoName,
      ),
      payChannel: JsonFieldParser.requireString(
        map,
        'payChannel',
        dtoName: dtoName,
      ),
      periodType: JsonFieldParser.requireString(
        map,
        'periodType',
        dtoName: dtoName,
      ),
      periodValue: JsonFieldParser.requireInt(
        map,
        'periodValue',
        dtoName: dtoName,
      ),
      priceText: JsonFieldParser.requireString(
        map,
        'priceText',
        dtoName: dtoName,
      ),
      originalPriceText: JsonFieldParser.optionalString(map, 'originalPriceText'),
      productName: JsonFieldParser.optionalString(map, 'productName'),
      promotionText: JsonFieldParser.optionalString(map, 'promotionText'),
      promotionExpireSeconds: JsonFieldParser.optionalString(map, 'promotionExpireSeconds'),
      sort: JsonFieldParser.requireInt(map, 'sort', dtoName: dtoName),
      status: JsonFieldParser.requireInt(map, 'status', dtoName: dtoName),
      createdAt: JsonFieldParser.requireDateTime(
        map,
        'createdAt',
        dtoName: dtoName,
      ),
      updatedAt: JsonFieldParser.requireDateTime(
        map,
        'updatedAt',
        dtoName: dtoName,
      ),
    );
  }
}
