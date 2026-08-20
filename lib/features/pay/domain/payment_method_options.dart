/// 商品在当前支付场景下可用的支付方式。
class PaymentMethodOptions {
  const PaymentMethodOptions({
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
  final List<PaymentMethodOption> options;
  final String osType;
  final String payScene;
  final int productId;
  final String productType;
  final int ruleId;
  final String ruleName;
  final bool showCashier;
}

/// 单个支付方式及其展示价格。
class PaymentMethodOption {
  const PaymentMethodOption({
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
}
