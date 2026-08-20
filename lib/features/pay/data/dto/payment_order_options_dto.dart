import 'package:drama_client/core/network/json_field_parser.dart';

import '../../domain/payment_method_options.dart';

/// `/api/payment/order/options` 返回的 data 对象。
class PaymentOrderOptionsDto {
  const PaymentOrderOptionsDto({
    required this.countryCode,
    required this.defaultMethodCode,
    required this.directPay,
    required this.options,
    required this.osType,
    required this.payScene,
    required this.productId,
    required this.productType,
    required this.ruleId,
    required this.ruleName,
    required this.showCashier,
  });

  final String countryCode;
  final String defaultMethodCode;
  final bool directPay;
  final List<PaymentMethodOptionDto> options;
  final String osType;
  final String payScene;
  final int productId;
  final String productType;
  final int ruleId;
  final String ruleName;
  final bool showCashier;

  factory PaymentOrderOptionsDto.fromJson(Object? json) {
    const dtoName = 'PaymentOrderOptionsDto';
    final map = JsonFieldParser.requireMap(json, dtoName: dtoName);
    final options = JsonFieldParser.requireList(
      map['options'],
      dtoName: dtoName,
      field: 'options',
    ).map(PaymentMethodOptionDto.fromJson).toList(growable: false);

    return PaymentOrderOptionsDto(
      countryCode: JsonFieldParser.requireString(
        map,
        'countryCode',
        dtoName: dtoName,
      ),
      defaultMethodCode: JsonFieldParser.requireString(
        map,
        'defaultMethodCode',
        dtoName: dtoName,
      ),
      directPay: JsonFieldParser.requireBool(
        map,
        'directPay',
        dtoName: dtoName,
      ),
      options: options,
      osType: JsonFieldParser.requireString(map, 'osType', dtoName: dtoName),
      payScene: JsonFieldParser.requireString(
        map,
        'payScene',
        dtoName: dtoName,
      ),
      productId: JsonFieldParser.requireInt(map, 'productId', dtoName: dtoName),
      productType: JsonFieldParser.requireString(
        map,
        'productType',
        dtoName: dtoName,
      ),
      ruleId: JsonFieldParser.requireInt(map, 'ruleId', dtoName: dtoName),
      ruleName: JsonFieldParser.requireString(
        map,
        'ruleName',
        dtoName: dtoName,
      ),
      showCashier: JsonFieldParser.requireBool(
        map,
        'showCashier',
        dtoName: dtoName,
      ),
    );
  }

  PaymentMethodOptions toDomain() => PaymentMethodOptions(
    countryCode: countryCode,
    defaultMethodCode: defaultMethodCode,
    directPay: directPay,
    options: options.map((option) => option.toDomain()).toList(growable: false),
    osType: osType,
    payScene: payScene,
    productId: productId,
    productType: productType,
    ruleId: ruleId,
    ruleName: ruleName,
    showCashier: showCashier,
  );
}

/// `/api/payment/order/options` 中的单个支付方式。
class PaymentMethodOptionDto {
  const PaymentMethodOptionDto({
    required this.actionType,
    required this.actionUrl,
    required this.amountMicros,
    required this.channelProductId,
    required this.currency,
    required this.methodCode,
    required this.methodName,
    required this.originalPriceText,
    required this.payChannel,
    required this.priceSource,
    required this.priceText,
    required this.productDependency,
    required this.promotionAmountMicros,
    required this.promotionPriceText,
    required this.promotionText,
    required this.sort,
    required this.supportRefund,
  });

  final String actionType;
  final String actionUrl;
  final int amountMicros;
  final String channelProductId;
  final String currency;
  final String methodCode;
  final String methodName;
  final String originalPriceText;
  final String payChannel;
  final int priceSource;
  final String priceText;
  final String productDependency;
  final int promotionAmountMicros;
  final String promotionPriceText;
  final String promotionText;
  final int sort;
  final bool supportRefund;

  factory PaymentMethodOptionDto.fromJson(Object? json) {
    const dtoName = 'PaymentMethodOptionDto';
    final map = JsonFieldParser.requireMap(json, dtoName: dtoName);
    return PaymentMethodOptionDto(
      actionType: JsonFieldParser.requireString(
        map,
        'actionType',
        dtoName: dtoName,
      ),
      actionUrl: JsonFieldParser.requireString(
        map,
        'actionUrl',
        dtoName: dtoName,
      ),
      amountMicros: JsonFieldParser.requireInt(
        map,
        'amountMicros',
        dtoName: dtoName,
      ),
      channelProductId: JsonFieldParser.requireString(
        map,
        'channelProductId',
        dtoName: dtoName,
      ),
      currency: JsonFieldParser.requireString(
        map,
        'currency',
        dtoName: dtoName,
      ),
      methodCode: JsonFieldParser.requireString(
        map,
        'methodCode',
        dtoName: dtoName,
      ),
      methodName: JsonFieldParser.requireString(
        map,
        'methodName',
        dtoName: dtoName,
      ),
      originalPriceText: JsonFieldParser.requireString(
        map,
        'originalPriceText',
        dtoName: dtoName,
      ),
      payChannel: JsonFieldParser.requireString(
        map,
        'payChannel',
        dtoName: dtoName,
      ),
      priceSource: JsonFieldParser.requireInt(
        map,
        'priceSource',
        dtoName: dtoName,
      ),
      priceText: JsonFieldParser.requireString(
        map,
        'priceText',
        dtoName: dtoName,
      ),
      productDependency: JsonFieldParser.requireString(
        map,
        'productDependency',
        dtoName: dtoName,
      ),
      promotionAmountMicros: JsonFieldParser.requireInt(
        map,
        'promotionAmountMicros',
        dtoName: dtoName,
      ),
      promotionPriceText: JsonFieldParser.requireString(
        map,
        'promotionPriceText',
        dtoName: dtoName,
      ),
      promotionText: JsonFieldParser.requireString(
        map,
        'promotionText',
        dtoName: dtoName,
      ),
      sort: JsonFieldParser.requireInt(map, 'sort', dtoName: dtoName),
      supportRefund: JsonFieldParser.requireBool(
        map,
        'supportRefund',
        dtoName: dtoName,
      ),
    );
  }

  PaymentMethodOption toDomain() => PaymentMethodOption(
    actionType: actionType,
    actionUrl: actionUrl,
    amountMicros: amountMicros,
    channelProductId: channelProductId,
    currency: currency,
    methodCode: methodCode,
    methodName: methodName,
    originalPriceText: originalPriceText,
    payChannel: payChannel,
    priceSource: priceSource,
    priceText: priceText,
    productDependency: productDependency,
    promotionAmountMicros: promotionAmountMicros,
    promotionPriceText: promotionPriceText,
    promotionText: promotionText,
    sort: sort,
    supportRefund: supportRefund,
  );
}
