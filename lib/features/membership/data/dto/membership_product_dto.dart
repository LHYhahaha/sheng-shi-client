import '../../../../core/network/json_field_parser.dart';

/// 会员商品 DTO
///
/// 后端返回字段说明：
/// - productName: 可能为空字符串
/// - payChannel: 可能是字符串枚举（如 "PAY_CHANNEL_GOOGLE"）或 int
/// - periodType: 可能是字符串枚举（如 "MEMBER_PERIOD_TYPE_MONTH"）或 int
class MembershipProductDto {
  const MembershipProductDto({
    required this.productId,
    required this.productName,
    required this.channelProductId,
    required this.currencySymbol,
    required this.memberType,
    required this.priceText,
    required this.originalPriceText,
    required this.periodType,
    required this.periodValue,
    required this.payChannel,
    required this.status,
    required this.sort,
    this.promotionText,
    this.promotionExpireSeconds,
    this.iapPriceText,
    this.iapRegularPriceText,
    this.iapHasPromo,
    this.iapPromoPeriod,
    this.iapRegularPeriod,
    this.createdAt,
    this.updatedAt,
  });

  final int productId;
  final String productName;
  final String channelProductId;
  final String currencySymbol;
  final String memberType;
  final String priceText;
  final String originalPriceText;
  final String periodType;
  final int periodValue;
  final String payChannel;
  final int status;
  final int sort;
  final String? promotionText;
  final int? promotionExpireSeconds;
  final String? iapPriceText;
  final String? iapRegularPriceText;
  final bool? iapHasPromo;
  final String? iapPromoPeriod;
  final String? iapRegularPeriod;
  final String? createdAt;
  final String? updatedAt;

  /// 完全容错的 JSON 解析
  ///
  /// 支持以下情况：
  /// - 字段为 null
  /// - 字段为空字符串
  /// - 数字字段可能是 int 或 string
  /// - 枚举字段可能是 string（如 "MEMBER_PERIOD_TYPE_MONTH"）
  factory MembershipProductDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'MembershipProductDto',
    );

    // 辅助方法：解析数字字段（支持 int/num/string）
    int parseInt(Object? value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        // 尝试解析数字字符串
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
        // 是枚举字符串，返回默认值
        // TODO: 根据后端实际枚举值映射到 int
        return fallback;
      }
      return fallback;
    }

    // 辅助方法：解析字符串字段（容错）
    String parseString(Object? value, {String fallback = ''}) {
      if (value == null) return fallback;
      if (value is String) return value; // 允许空字符串
      return fallback;
    }

    return MembershipProductDto(
      productId: parseInt(map['productId']),
      productName: parseString(map['productName'], fallback: 'Membership'),
      channelProductId: parseString(map['channelProductId']),
      currencySymbol: parseString(map['currencySymbol']),
      memberType: parseString(map['memberType']),
      priceText: parseString(map['priceText']),
      originalPriceText: parseString(map['originalPriceText']),
      periodType: parseString(map['periodType']),
      periodValue: parseInt(map['periodValue']),
      payChannel: parseString(map['payChannel']),
      status: parseInt(map['status']),
      sort: parseInt(map['sort']),
      promotionText: parseString(map['promotionText']),
      promotionExpireSeconds: parseInt(map['promotionExpireSeconds']),
      iapPriceText: null, // IAP 字段不从后端解析，由 IAP 查询填充
      iapRegularPriceText: null,
      iapHasPromo: null,
      iapPromoPeriod: null,
      iapRegularPeriod: null,
      createdAt: parseString(map['createdAt']),
      updatedAt: parseString(map['updatedAt']),
    );
  }
}
