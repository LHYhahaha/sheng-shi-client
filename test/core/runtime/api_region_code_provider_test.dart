import 'dart:ui';

import 'package:drama_client/core/runtime/api_region_code_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses uppercase device locale country code', () {
    expect(apiRegionCodeFromLocale(const Locale('en', 'sg')), 'SG');
  });

  test('returns empty string when locale has no country code', () {
    expect(apiRegionCodeFromLocale(const Locale('en')), '');
  });
}
