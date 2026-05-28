import '../../../../core/network/json_field_parser.dart';

class MembershipProductDto {
  const MembershipProductDto({
    required this.productId,
    required this.productName,
    required this.channelProductId,
    required this.priceText,
    required this.originalPriceText,
    required this.periodType,
    required this.periodValue,
    required this.payChannel,
    required this.status,
    required this.sort,
    this.promotionText,
    this.promotionExpireSeconds,
    this.createdAt,
    this.updatedAt,
  });

  /// 商品 ID
  final int productId;

  /// 商品名称
  final String productName;

  /// 渠道商品 ID（对应 platformProductId）
  final String channelProductId;

  /// 展示价格
  final String priceText;

  /// 原价展示
  final String originalPriceText;

  /// 会员周期类型（0=周/1=月/2=年）
  final int periodType;

  /// 周期值
  final int periodValue;

  /// 支付渠道
  final int payChannel;

  /// 商品状态
  final int status;

  /// 排序
  final int sort;

  /// 促销文案
  final String? promotionText;

  /// 促销倒计时秒数
  final int? promotionExpireSeconds;

  /// 创建时间
  final String? createdAt;

  /// 更新时间
  final String? updatedAt;

  factory MembershipProductDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'MembershipProductDto',
    );
    const dtoName = 'MembershipProductDto';
    return MembershipProductDto(
      productId: JsonFieldParser.requireInt(
        map,
        'productId',
        dtoName: dtoName,
      ),
      productName: JsonFieldParser.requireString(
        map,
        'productName',
        dtoName: dtoName,
      ),
      channelProductId: JsonFieldParser.requireString(
        map,
        'channelProductId',
        dtoName: dtoName,
      ),
      priceText: JsonFieldParser.requireString(
        map,
        'priceText',
        dtoName: dtoName,
      ),
      originalPriceText: JsonFieldParser.requireString(
        map,
        'originalPriceText',
        dtoName: dtoName,
      ),
      periodType: JsonFieldParser.requireInt(
        map,
        'periodType',
        dtoName: dtoName,
      ),
      periodValue: JsonFieldParser.requireInt(
        map,
        'periodValue',
        dtoName: dtoName,
      ),
      payChannel: JsonFieldParser.requireInt(
        map,
        'payChannel',
        dtoName: dtoName,
      ),
      status: JsonFieldParser.requireInt(
        map,
        'status',
        dtoName: dtoName,
      ),
      sort: JsonFieldParser.requireInt(
        map,
        'sort',
        dtoName: dtoName,
      ),
      promotionText: JsonFieldParser.optionalString(map, 'promotionText'),
      promotionExpireSeconds: JsonFieldParser.optionalInt(
        map,
        'promotionExpireSeconds',
      ),
      createdAt: JsonFieldParser.optionalString(map, 'createdAt'),
      updatedAt: JsonFieldParser.optionalString(map, 'updatedAt'),
    );
  }
}
