import '../../../../core/network/json_field_parser.dart';

/// 金币产品DTO
///
/// 对应API返回的 `/api/payment/recharge/page` 中的 `coinProducts` 字段。
class CoinProductDto {
  const CoinProductDto({
    required this.productId,
    required this.coin,
    required this.bonusCoin,
    required this.bonusExpireEnabled,
    this.bonusExpireDays,
    required this.channelProductId,
    required this.currencySymbol,
    required this.payChannel,
    required this.priceText,
    this.productName,
    required this.sort,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String productId;
  final String coin;
  final String bonusCoin;
  final bool bonusExpireEnabled;
  final int? bonusExpireDays;
  final String channelProductId;
  final String currencySymbol;
  final String payChannel;
  final String priceText;
  final String? productName;
  final int sort;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CoinProductDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'CoinProductDto');
    const dtoName = 'CoinProductDto';

    return CoinProductDto(
      productId: JsonFieldParser.requireString(
        map,
        'productId',
        dtoName: dtoName,
      ),
      coin: JsonFieldParser.requireString(map, 'coin', dtoName: dtoName),
      bonusCoin: JsonFieldParser.requireString(
        map,
        'bonusCoin',
        dtoName: dtoName,
      ),
      bonusExpireEnabled: JsonFieldParser.requireBool(
        map,
        'bonusExpireEnabled',
        dtoName: dtoName,
      ),
      bonusExpireDays: JsonFieldParser.optionalInt(map, 'bonusExpireDays'),
      channelProductId: JsonFieldParser.requireString(
        map,
        'channelProductId',
        dtoName: dtoName,
      ),
      currencySymbol: JsonFieldParser.requireString(
        map,
        'currencySymbol',
        dtoName: dtoName,
      ),
      payChannel: JsonFieldParser.requireString(
        map,
        'payChannel',
        dtoName: dtoName,
      ),
      priceText: JsonFieldParser.requireString(
        map,
        'priceText',
        dtoName: dtoName,
      ),
      productName: JsonFieldParser.optionalString(map, 'productName'),
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
