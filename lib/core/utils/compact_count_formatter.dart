/// Formats integer counters using compact K/M suffixes.
///
/// The rounding boundary is shared across the app so values such as 999,950
/// consistently roll over to 1.0M instead of rendering as 1000.0K.
String formatCompactCount(
  int? count, {
  bool emptyWhenNonPositive = false,
  bool lowercaseSuffix = false,
  bool spaceBeforeSuffix = false,
  bool omitFractionForTenOrMore = false,
  bool omitFractionForWholeNumber = false,
}) {
  final value = count ?? 0;
  if (emptyWhenNonPositive && value <= 0) return '';

  final suffixSeparator = spaceBeforeSuffix ? ' ' : '';
  final thousandSuffix = lowercaseSuffix ? 'k' : 'K';
  final millionSuffix = lowercaseSuffix ? 'm' : 'M';

  if (value >= 1000000) {
    return _formatScaled(
      value / 1000000,
      suffix: millionSuffix,
      suffixSeparator: suffixSeparator,
      omitFractionForTenOrMore: omitFractionForTenOrMore,
      omitFractionForWholeNumber: omitFractionForWholeNumber,
    );
  }

  if (value >= 1000) {
    final thousands = value / 1000;
    if (thousands >= 999.95) {
      return '1.0$suffixSeparator$millionSuffix';
    }
    return _formatScaled(
      thousands,
      suffix: thousandSuffix,
      suffixSeparator: suffixSeparator,
      omitFractionForTenOrMore: omitFractionForTenOrMore,
      omitFractionForWholeNumber: omitFractionForWholeNumber,
    );
  }

  return '$value';
}

String _formatScaled(
  double value, {
  required String suffix,
  required String suffixSeparator,
  required bool omitFractionForTenOrMore,
  required bool omitFractionForWholeNumber,
}) {
  final omitFraction =
      (omitFractionForTenOrMore && value >= 10) ||
      (omitFractionForWholeNumber && value % 1 == 0);
  final number = omitFraction
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$number$suffixSeparator$suffix';
}
