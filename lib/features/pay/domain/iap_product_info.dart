import 'package:in_app_purchase/in_app_purchase.dart';

class IapProductInfo {
  const IapProductInfo({
    required this.productDetails,
    this.hasPromo = false,
    this.hasFreeTrial = false,
    this.promoPrice,
    this.promoPriceMicros,
    this.promoPeriod,
    this.promoCycles,
    this.regularPrice,
    this.regularPriceMicros,
    this.regularPeriod,
    this.regularCycles,
    this.offerToken,
    this.basePlanId,
    this.offerId,
    this.offerTags = const [],
  });

  /// 必须保留这个对象。
  ///
  /// 页面展示和购买时必须使用同一个 ProductDetails。
  final ProductDetails productDetails;

  final bool hasPromo;

  /// 首期是否为免费试用
  final bool hasFreeTrial;

  /// 促销格式化价格，例如 S$1.99
  final String? promoPrice;

  final int? promoPriceMicros;

  /// 单个促销计费周期，例如 P1M
  final String? promoPeriod;

  /// 促销周期执行次数，例如3
  final int? promoCycles;

  /// 正常续费价格，例如 S$9.99
  final String? regularPrice;

  final int? regularPriceMicros;

  /// 正常续费周期，例如 P1M
  final String? regularPeriod;

  final int? regularCycles;

  /// Android购买这个优惠必须传入
  final String? offerToken;

  final String? basePlanId;
  final String? offerId;
  final List<String> offerTags;

  String get displayPrice {
    if (hasPromo && promoPrice != null) {
      return promoPrice!;
    }
    return productDetails.price;
  }

  String? get displayOriginalPrice {
    if (hasPromo && regularPrice != null) {
      return regularPrice;
    }
    return null;
  }

  bool get canUseGoogleOffer =>
      offerToken != null && offerToken!.trim().isNotEmpty;

  @override
  String toString() {
    return 'IapProductInfo('
        'id: ${productDetails.id}, '
        'hasPromo: $hasPromo, '
        'promoPrice: $promoPrice, '
        'promoPeriod: $promoPeriod, '
        'promoCycles: $promoCycles, '
        'regularPrice: $regularPrice, '
        'regularPeriod: $regularPeriod, '
        'basePlanId: $basePlanId, '
        'offerId: $offerId'
        ')';
  }

  String? promoDescription({String languageCode = 'zh'}) {
    if (!hasPromo ||
        promoPrice == null ||
        regularPrice == null ||
        promoPeriod == null ||
        regularPeriod == null) {
      return null;
    }

    return IapPromoTextBuilder.build(
      promoPrice: promoPrice!,
      promoPeriod: promoPeriod!,
      promoCycles: promoCycles ?? 1,
      regularPrice: regularPrice!,
      regularPeriod: regularPeriod!,
      hasFreeTrial: hasFreeTrial,
      languageCode: languageCode,
    );
  }
}

class IapPromoTextBuilder {
  const IapPromoTextBuilder._();

  static String build({
    required String promoPrice,
    required String promoPeriod,
    required int promoCycles,
    required String regularPrice,
    required String regularPeriod,
    required bool hasFreeTrial,
    required String languageCode,
  }) {
    final isZh = languageCode.toLowerCase().startsWith('zh');

    final promoUnit = _periodUnit(promoPeriod, languageCode: languageCode);

    final regularUnit = _periodUnit(regularPeriod, languageCode: languageCode);

    final safeCycles = promoCycles <= 0 ? 1 : promoCycles;

    if (isZh) {
      if (hasFreeTrial) {
        final trialDuration = _durationText(
          promoPeriod,
          safeCycles,
          languageCode: languageCode,
        );

        return '前$trialDuration免费，之后 $regularPrice/$regularUnit。';
      }

      final duration = _durationText(
        promoPeriod,
        safeCycles,
        languageCode: languageCode,
      );

      return '前$duration $promoPrice/$promoUnit，'
          '之后 $regularPrice/$regularUnit。';
    }

    if (hasFreeTrial) {
      final duration = _durationText(
        promoPeriod,
        safeCycles,
        languageCode: languageCode,
      );

      return '$duration free, then $regularPrice/$regularUnit';
    }

    final duration = _durationText(
      promoPeriod,
      safeCycles,
      languageCode: languageCode,
    );

    return '$promoPrice/$promoUnit for first $duration, '
        'then $regularPrice/$regularUnit';
  }

  static String _durationText(
    String isoPeriod,
    int cycles, {
    required String languageCode,
  }) {
    final isZh = languageCode.toLowerCase().startsWith('zh');

    final parsed = _parsePeriod(isoPeriod);
    final total = parsed.value * cycles;

    if (isZh) {
      switch (parsed.unit) {
        case _PeriodUnit.day:
          return '$total天';
        case _PeriodUnit.week:
          return '$total周';
        case _PeriodUnit.month:
          return '$total个月';
        case _PeriodUnit.year:
          return '$total年';
      }
    }

    final unit = switch (parsed.unit) {
      _PeriodUnit.day => total == 1 ? 'day' : 'days',
      _PeriodUnit.week => total == 1 ? 'week' : 'weeks',
      _PeriodUnit.month => total == 1 ? 'month' : 'months',
      _PeriodUnit.year => total == 1 ? 'year' : 'years',
    };

    return '$total $unit';
  }

  static String _periodUnit(String isoPeriod, {required String languageCode}) {
    final isZh = languageCode.toLowerCase().startsWith('zh');
    final parsed = _parsePeriod(isoPeriod);

    if (isZh) {
      return switch (parsed.unit) {
        _PeriodUnit.day => '天',
        _PeriodUnit.week => '周',
        _PeriodUnit.month => '月',
        _PeriodUnit.year => '年',
      };
    }

    return switch (parsed.unit) {
      _PeriodUnit.day => 'day',
      _PeriodUnit.week => 'week',
      _PeriodUnit.month => 'month',
      _PeriodUnit.year => 'year',
    };
  }

  static _ParsedPeriod _parsePeriod(String value) {
    final normalized = value.trim().toUpperCase();

    final match = RegExp(r'^P(\d+)(D|W|M|Y)$').firstMatch(normalized);

    if (match == null) {
      return const _ParsedPeriod(value: 1, unit: _PeriodUnit.month);
    }

    final count = int.tryParse(match.group(1) ?? '') ?? 1;
    final unitText = match.group(2);

    final unit = switch (unitText) {
      'D' => _PeriodUnit.day,
      'W' => _PeriodUnit.week,
      'Y' => _PeriodUnit.year,
      _ => _PeriodUnit.month,
    };

    return _ParsedPeriod(value: count, unit: unit);
  }
}

enum _PeriodUnit { day, week, month, year }

class _ParsedPeriod {
  const _ParsedPeriod({required this.value, required this.unit});

  final int value;
  final _PeriodUnit unit;
}
