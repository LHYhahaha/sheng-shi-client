/// Utilities for ISO 8601 billing periods and localized commerce labels.
class PeriodIsoParser {
  PeriodIsoParser._();

  static Map<String, dynamic>? parse(String iso) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso.toUpperCase());
    if (match == null) return null;
    return {
      'value': int.parse(match.group(1)!),
      'unit': match.group(2),
    };
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

  static String toPromoPrefix(String? iso, {String? languageCode}) {
    if (iso == null) return '';
    final parsed = parse(iso);
    if (parsed == null) return '';
    final value = parsed['value'] as int;
    final unit = parsed['unit'] as String;
    if (_isEnglish(languageCode)) {
      return 'for first $value ${_unitEnglish(unit, value)}';
    }
    return '\u524d$value${_unitChinese(unit)}';
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
  }) {
    if (promoPrice == null || regularPrice == null) return null;
    final promoPrefix = toPromoPrefix(
      promoPeriodIso,
      languageCode: languageCode,
    );
    if (promoPrefix.isEmpty) return null;

    final promoPeriodLabel = toPeriodLabel(
      promoPeriodIso,
      languageCode: languageCode,
    );
    final regularPeriodLabel = toPeriodLabel(
      regularPeriodIso,
      languageCode: languageCode,
    );
    final thenLabel = promoThenLabel(languageCode: languageCode);

    if (_isEnglish(languageCode)) {
      return '$promoPrice$promoPeriodLabel $promoPrefix, $thenLabel $regularPrice$regularPeriodLabel';
    }
    return '$promoPrefix $promoPrice$promoPeriodLabel\uff0c$thenLabel $regularPrice$regularPeriodLabel';
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

  static String localizedDailyPriceLabel(
    String label, {
    String? languageCode,
  }) {
    if (label.isEmpty) return label;
    if (_isEnglish(languageCode)) {
      return label
          .replaceAll(RegExp(r'/\s*\u5929'), '/day')
          .replaceAll(RegExp(r'/\s*\u65e5'), '/day');
    }
    return label
        .replaceAll(RegExp(r'/\s*days?', caseSensitive: false), '/\u5929')
        .replaceAll(
          RegExp(r'\s+per\s+days?', caseSensitive: false),
          '/\u5929',
        );
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
