import 'package:drama_client/core/utils/compact_count_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats the shared compact count boundaries', () {
    expect(formatCompactCount(999), '999');
    expect(formatCompactCount(1000), '1.0K');
    expect(formatCompactCount(999949), '999.9K');
    expect(formatCompactCount(999950), '1.0M');
    expect(formatCompactCount(1000000), '1.0M');
    expect(formatCompactCount(156800), '156.8K');
  });

  test('supports existing presentation variants', () {
    expect(
      formatCompactCount(
        12000,
        spaceBeforeSuffix: true,
        omitFractionForTenOrMore: true,
      ),
      '12 K',
    );
    expect(formatCompactCount(1200, lowercaseSuffix: true), '1.2k');
    expect(formatCompactCount(0, emptyWhenNonPositive: true), '');
    expect(formatCompactCount(1000, omitFractionForWholeNumber: true), '1K');
  });
}
