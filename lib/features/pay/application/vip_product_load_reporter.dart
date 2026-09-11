import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../domain/vip_product_load_result.dart';

/// Report once after the completed attempt has reached the page's frame.
class VipProductLoadReporter {
  VipProductLoadResult? _scheduled;

  void reportAfterFrame({
    required VipProductLoadResult? attempt,
    required int productCount,
    required bool Function() isCurrent,
    required AnalyticsService Function() analytics,
    String? rechargePopupType,
  }) {
    if (attempt == null || identical(attempt, _scheduled)) return;
    _scheduled = attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCurrent()) {
        if (identical(_scheduled, attempt)) _scheduled = null;
        return;
      }
      final result = attempt.result == 'success' && productCount == 0
          ? 'empty'
          : attempt.result;
      unawaited(
        analytics().track(
          AnalyticsEvent(AnalyticsDefinitions.vipProductLoadResult, {
            'product_load_result': result,
            'product_count': result == 'success' ? productCount : 0,
            'recharge_popup_type': ?rechargePopupType,
          }),
        ),
      );
    });
  }
}
