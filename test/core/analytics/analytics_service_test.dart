import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_definition.dart';
import 'package:drama_client/core/analytics/analytics_event.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a snapshot without removed session fields', () async {
    final sink = _RecordingSink();
    final service = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'android',
        appVersion: '1.0.3',
        language: 'zh-CN',
        userId: 'user-1',
        pageName: 'home_page',
      ),
      eventSink: sink,
      eventIdGenerator: () => 'evt-1',
      clock: () => DateTime.utc(2026, 8, 4, 6, 0),
    );

    final payload = await service.track(
      const AnalyticsEvent(AnalyticsDefinitions.popupShow, {
        'popup_name': 'login_popup',
        'popup_target_type': 'page',
      }),
    );

    expect(payload, isNotNull);
    expect(sink.values, hasLength(1));
    final commonParams = payload!.commonParams.toJson();
    expect(commonParams['event_id'], 'evt-1');
    expect(commonParams['event_time'], 1785823200000);
    expect(commonParams['channel_id'], '');
    expect(commonParams['merchant_id'], '');
    expect(commonParams['region_code'], '');
    expect(commonParams['previous_page'], '');
    expect(commonParams['entry_source_type'], '');
    expect(commonParams['entry_source_id'], '');
    expect(commonParams['h5_visitor_id'], '');
    expect(commonParams.containsKey('session_id'), isFalse);
    expect(commonParams.containsKey('app_session_id'), isFalse);
    expect(payload.toJson().containsKey('event_id'), isFalse);
  });

  test('popup_close only accepts popup_name', () async {
    final errors = <AnalyticsValidationError>[];
    final service = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'ios',
        appVersion: '1.0.3',
        language: 'en',
      ),
      eventSink: _RecordingSink(),
      onValidationError: errors.add,
    );

    final rejected = await service.track(
      const AnalyticsEvent(AnalyticsDefinitions.popupClose, {
        'popup_name': 'login_popup',
        'close_method': 'mask',
      }),
    );
    final accepted = await service.track(
      const AnalyticsEvent(AnalyticsDefinitions.popupClose, {
        'popup_name': 'login_popup',
      }),
    );

    expect(rejected, isNull);
    expect(errors.single.parameterName, 'close_method');
    expect(accepted?.eventParams, {'popup_name': 'login_popup'});
  });

  test('does not enqueue invalid events', () async {
    final sink = _RecordingSink();
    final service = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'android',
        appVersion: '1.0.3',
        language: 'zh-CN',
      ),
      eventSink: sink,
    );

    final payload = await service.track(
      const AnalyticsEvent(AnalyticsDefinitions.appExit),
    );

    expect(payload, isNull);
    expect(sink.values, isEmpty);
  });

  test('payment start only accepts documented payment method types', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);
    const baseParams = {
      'payment_method_id': 'google_play',
      'order_id': 'order-1',
      'product_id': '358',
      'product_type': 'vip_subscription',
    };

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.paymentStart, {
          ...baseParams,
          'payment_method_type': 'google_play',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.paymentStart, {
          ...baseParams,
          'payment_method_type': 'PAY_CHANNEL_GOOGLE',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
  });

  test('share app open only accepts documented landing types', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.shareAppOpen, {
          'landing_type': 'normal_share',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.shareAppOpen, {
          'landing_type': 'unknown',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
  });

  test('vip product card requires the documented click action', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);
    const baseParams = {
      'element_name': 'vip_product_card',
      'product_id': '358',
      'product_type': 'vip_subscription',
      'position': 1,
    };

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.elementClick, {
          ...baseParams,
          'payment_click_action': 'select_product',
          'recharge_popup_type': 'with_coin',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.elementClick, baseParams),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.elementClick, {
          ...baseParams,
          'payment_click_action': 'choose',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
  });

  test('coin product card only accepts coin payment actions', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);
    const baseParams = {
      'element_name': 'coin_product_card',
      'product_id': '100',
      'product_type': 'coin',
      'position': 1,
    };

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.elementClick, {
          ...baseParams,
          'payment_click_action': 'open_payment_popup',
          'recharge_popup_type': 'with_coin',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.elementClick, {
          ...baseParams,
          'payment_click_action': 'select_product',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
  });

  test('requires conditional parameters only when their condition is met', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.loginFail, {
          'login_provider': 'google',
          'result_status': 'failed',
        }),
      ),
      throwsA(
        isA<AnalyticsValidationError>().having(
          (error) => error.parameterName,
          'parameterName',
          'login_fail_reason',
        ),
      ),
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.loginFail, {
          'login_provider': 'google',
          'result_status': 'cancelled',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.loginFail, {
          'login_provider': 'google',
          'result_status': 'failed',
          'login_fail_reason': 'network',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.loginFail, {
          'login_provider': 'google',
          'result_status': 'failed',
          'login_fail_reason': 'network_error',
        }),
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.loginFail, {
          'login_provider': 'device',
          'result_status': 'failed',
          'login_fail_reason': 'unknown_error',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
  });

  test('episode unlock request accepts documented auto coin parameters', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.episodeUnlockRequest, {
          'drama_id': '100',
          'episode_id': '200',
          'unlock_trigger_type': 'auto',
          'required_coin_amount': 60,
          'request_id': 'episode_unlock_100_200_1',
        }),
      ),
      returnsNormally,
    );
  });

  test('rejects unknown parameters and invalid launch values', () {
    final validator = AnalyticsEventValidator(AnalyticsDefinitions.events);

    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.popupClose, {
          'popup_name': 'login_popup',
          'close_method': 'mask',
        }),
      ),
      throwsA(isA<AnalyticsValidationError>()),
    );
    expect(
      () => validator.validate(
        const AnalyticsEvent(AnalyticsDefinitions.appLaunch, {
          'launch_type': 'warm',
        }),
      ),
      throwsA(
        isA<AnalyticsValidationError>().having(
          (error) => error.reason,
          'reason',
          '参数枚举值不合法',
        ),
      ),
    );
  });
}

class _RecordingSink implements AnalyticsEventSink {
  final values = <AnalyticsPayload>[];

  @override
  Future<void> enqueue(AnalyticsPayload payload) async {
    values.add(payload);
  }
}
