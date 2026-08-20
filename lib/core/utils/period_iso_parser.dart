/// Utilities for ISO 8601 billing periods and localized commerce labels.
class PeriodIsoParser {
  PeriodIsoParser._();

  static Map<String, dynamic>? parse(String iso) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso.toUpperCase());
    if (match == null) return null;
    return {'value': int.parse(match.group(1)!), 'unit': match.group(2)};
  }

  static String toDisplayLabel(String iso, {String? languageCode}) {
    final parsed = parse(iso);
    if (parsed == null) return iso;
    final value = parsed['value'] as int;
    final unit = parsed['unit'] as String;
    if (_isEnglish(languageCode)) {
      return '$value ${_unitEnglish(unit, value)}';
    }
    return '$value${_unitChinese(unit)}';
  }

  static String toPeriodLabel(String? iso, {String? languageCode}) {
    if (iso == null) return _isEnglish(languageCode) ? '/month' : '/\u6708';
    final parsed = parse(iso);
    if (parsed == null) return _isEnglish(languageCode) ? '/month' : '/\u6708';
    final unit = parsed['unit'] as String;
    if (_isEnglish(languageCode)) {
      return '/${_unitEnglish(unit, 1)}';
    }
    return '/${_unitChinese(unit)}';
  }

  static String promoThenLabel({String? languageCode}) {
    return _isEnglish(languageCode) ? 'then' : '\u4e4b\u540e';
  }

  static String? buildPromoDescription({
    required String? promoPrice,
    required String? regularPrice,
    required String? promoPeriodIso,
    required String? regularPeriodIso,
    required String? languageCode,
    int promoCycles = 1,
    bool hasFreeTrial = false,
  }) {
    if (promoPrice == null ||
        regularPrice == null ||
        promoPeriodIso == null ||
        regularPeriodIso == null ||
        parse(promoPeriodIso) == null ||
        parse(regularPeriodIso) == null) {
      return null;
    }

    return IapPromoTextBuilder.build(
      promoPrice: promoPrice,
      promoPeriod: promoPeriodIso,
      promoCycles: promoCycles,
      regularPrice: regularPrice,
      regularPeriod: regularPeriodIso,
      hasFreeTrial: hasFreeTrial,
      languageCode: languageCode ?? 'zh',
    );
  }

  static String localizedMembershipTitle(
    String title, {
    String? periodIso,
    String? fallbackId,
    String? languageCode,
  }) {
    final period =
        _Period.fromIso(periodIso) ??
        _Period.fromText(title) ??
        _Period.fromText(fallbackId ?? '');
    if (period == null) {
      return title;
    }
    if (_isEnglish(languageCode)) {
      return '${_englishPlanName(period)} VIP';
    }
    return '${_chinesePlanName(period)}\u4f1a\u5458';
  }

  static String localizedDailyPriceLabel(String label, {String? languageCode}) {
    if (label.isEmpty) return label;
    if (_isEnglish(languageCode)) {
      return label
          .replaceAll(RegExp(r'/\s*\u5929'), '/day')
          .replaceAll(RegExp(r'/\s*\u65e5'), '/day');
    }
    return label
        .replaceAll(RegExp(r'/\s*days?', caseSensitive: false), '/\u5929')
        .replaceAll(RegExp(r'\s+per\s+days?', caseSensitive: false), '/\u5929');
  }

  static String _unitChinese(String unit) {
    return switch (unit) {
      'D' => '\u5929',
      'W' => '\u5468',
      'M' => '\u6708',
      'Y' => '\u5e74',
      _ => '\u6708',
    };
  }

  static String _unitEnglish(String unit, int value) {
    final plural = value != 1;
    return switch (unit) {
      'D' => plural ? 'days' : 'day',
      'W' => plural ? 'weeks' : 'week',
      'M' => plural ? 'months' : 'month',
      'Y' => plural ? 'years' : 'year',
      _ => plural ? 'months' : 'month',
    };
  }

  static bool _isEnglish(String? languageCode) => languageCode != 'zh';

  static String _englishPlanName(_Period period) {
    if (period.value == 1) {
      return switch (period.unit) {
        'D' => 'Daily',
        'W' => 'Weekly',
        'M' => 'Monthly',
        'Y' => 'Yearly',
        _ => 'VIP',
      };
    }
    if (period.unit == 'M' && period.value == 3) {
      return 'Quarterly';
    }
    return '${period.value} ${_unitEnglish(period.unit, period.value)}';
  }

  static String _chinesePlanName(_Period period) {
    if (period.value == 1) {
      return switch (period.unit) {
        'D' => '\u5929',
        'W' => '\u5468',
        'M' => '\u6708',
        'Y' => '\u5e74',
        _ => 'VIP',
      };
    }
    return '${period.value}${_unitChinese(period.unit)}';
  }
}

class IapPromoTextBuilder {
  const IapPromoTextBuilder._();

  /// Variables used by the remotely configured `vip.plan.intro_price` text.
  static Map<String, String> templateArguments({
    required String promoPrice,
    required String promoPeriod,
    required int promoCycles,
    required String regularPrice,
    required String languageCode,
  }) {
    final safeCycles = promoCycles <= 0 ? 1 : promoCycles;
    final promo = _PromoPeriod.fromIso(promoPeriod);
    final total = promo.value * safeCycles;
    return {
      'sale': promoPrice,
      'price': regularPrice,
      'num': '$total',
      'ordinal': promo.ordinalDuration(safeCycles),
      'unit': promo.unitText(languageCode),
    };
  }

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
    final safeCycles = promoCycles <= 0 ? 1 : promoCycles;
    final promo = _PromoPeriod.fromIso(promoPeriod);
    final regular = _PromoPeriod.fromIso(regularPeriod);

    if (isZh) {
      final duration = promo.durationText(
        safeCycles,
        languageCode: languageCode,
      );
      if (hasFreeTrial) {
        return '前$duration免费，之后 $regularPrice/${regular.unitText(languageCode)}。';
      }
      return '前$duration $promoPrice/${promo.unitText(languageCode)}，'
          '之后 $regularPrice/${regular.unitText(languageCode)}。';
    }

    if (hasFreeTrial) {
      return '${promo.durationText(safeCycles, languageCode: languageCode)} free, '
          'then $regularPrice/${regular.unitText(languageCode)}';
    }

    return '$promoPrice for ${promo.ordinalDuration(safeCycles)} '
        '${promo.unitText(languageCode)}, then $regularPrice '
        '${regular.unitText(languageCode)}';
  }
}

class _PromoPeriod {
  const _PromoPeriod(this.value, this.unit);

  final int value;
  final String unit;

  factory _PromoPeriod.fromIso(String iso) {
    final parsed = PeriodIsoParser.parse(iso);
    if (parsed == null) return const _PromoPeriod(1, 'M');
    return _PromoPeriod(parsed['value'] as int, parsed['unit'] as String);
  }

  String durationText(int cycles, {required String languageCode}) {
    final total = value * cycles;
    if (languageCode.toLowerCase().startsWith('zh')) {
      return '$total${PeriodIsoParser._unitChinese(unit)}';
    }
    return '$total ${PeriodIsoParser._unitEnglish(unit, total)}';
  }

  String ordinalDuration(int cycles) {
    final total = value * cycles;
    final suffix = switch (total) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
    return '$total$suffix';
  }

  String unitText(String languageCode) {
    if (languageCode.toLowerCase().startsWith('zh')) {
      return PeriodIsoParser._unitChinese(unit);
    }
    return PeriodIsoParser._unitEnglish(unit, 1);
  }
}

class _Period {
  const _Period(this.value, this.unit);

  final int value;
  final String unit;

  static _Period? fromIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = PeriodIsoParser.parse(iso);
    if (parsed == null) return null;
    return _Period(parsed['value'] as int, parsed['unit'] as String);
  }

  static _Period? fromText(String text) {
    final normalized = text.toLowerCase();
    final withValue = RegExp(
      r'(\d+)\s*(day|days|week|weeks|month|months|year|years)',
    ).firstMatch(normalized);
    if (withValue != null) {
      return _Period(
        int.parse(withValue.group(1)!),
        _unitFromWord(withValue.group(2)!),
      );
    }
    if (normalized.contains('quarter')) return const _Period(3, 'M');
    if (normalized.contains('year')) return const _Period(1, 'Y');
    if (normalized.contains('month')) return const _Period(1, 'M');
    if (normalized.contains('week')) return const _Period(1, 'W');
    if (normalized.contains('day') || normalized.contains('daily')) {
      return const _Period(1, 'D');
    }
    return null;
  }

  static String _unitFromWord(String word) {
    if (word.startsWith('day')) return 'D';
    if (word.startsWith('week')) return 'W';
    if (word.startsWith('month')) return 'M';
    if (word.startsWith('year')) return 'Y';
    return 'M';
  }
}
