import 'analytics_event.dart';

/// 参数的运行时校验类型。
enum AnalyticsParameterType { string, number }

typedef AnalyticsRequiredWhen = bool Function(Map<String, Object?> params);
typedef AnalyticsAllowedValuesWhen =
    Set<Object>? Function(Map<String, Object?> params);

class AnalyticsParameterRule {
  const AnalyticsParameterRule({
    required this.type,
    this.required = false,
    this.requiredWhen,
    this.allowedValues,
    this.allowedValuesWhen,
  });

  final AnalyticsParameterType type;
  final bool required;
  final AnalyticsRequiredWhen? requiredWhen;
  final Set<Object>? allowedValues;
  final AnalyticsAllowedValuesWhen? allowedValuesWhen;

  bool isRequired(Map<String, Object?> params) =>
      required || (requiredWhen?.call(params) ?? false);

  Set<Object>? allowedValuesFor(Map<String, Object?> params) =>
      allowedValuesWhen?.call(params) ?? allowedValues;
}

/// 单个事件的本地定义。事件与参数名必须与埋点表完全一致。
class AnalyticsEventDefinition {
  const AnalyticsEventDefinition({
    required this.name,
    this.parameters = const {},
    this.allowAdditionalParameters = false,
  });

  final String name;
  final Map<String, AnalyticsParameterRule> parameters;
  final bool allowAdditionalParameters;
}

/// 事件定义校验失败。
class AnalyticsValidationError implements Exception {
  const AnalyticsValidationError({
    required this.eventName,
    required this.reason,
    this.parameterName,
  });

  final String eventName;
  final String reason;
  final String? parameterName;

  @override
  String toString() {
    final parameter = parameterName == null ? '' : ' ($parameterName)';
    return 'AnalyticsValidationError: $eventName$parameter: $reason';
  }
}

/// 当前客户端埋点表已确认的事件与参数定义。
///
/// `session_start`、公共参数 `session_id` 与 `app_session_id` 已按当前需求移除。
abstract final class AnalyticsDefinitions {
  static const appFirstOpen = 'app_first_open';
  static const appLaunch = 'app_launch';
  static const appExit = 'app_exit';
  static const pageView = 'page_view';
  static const pageLeave = 'page_leave';
  static const popupShow = 'popup_show';
  static const popupClose = 'popup_close';
  static const elementClick = 'element_click';
  static const userLogout = 'user_logout';

  static const dramaPlayStart = 'drama_play_start';
  static const dramaPlayEnd = 'drama_play_end';
  static const searchSubmit = 'search_submit';
  static const searchResultClick = 'search_result_click';
  static const paymentStart = 'payment_start';
  static const loginFail = 'login_fail';
  static const episodeUnlockRequest = 'episode_unlock_request';
  static const pushPermissionResult = 'push_permission_result';
  static const pushNotificationOpen = 'push_notification_open';
  static const homeBannerExposure = 'home_banner_exposure';
  static const dynamicTabExposure = 'dynamic_tab_exposure';
  static const dramaCardExposure = 'drama_card_exposure';
  static const adUnlockEntryExposure = 'ad_unlock_entry_exposure';
  static const adViewStart = 'ad_view_start';
  static const adViewEnd = 'ad_view_end';
  static const shareAppOpen = 'share_app_open';

  static const _string = AnalyticsParameterRule(
    type: AnalyticsParameterType.string,
  );
  static const _requiredString = AnalyticsParameterRule(
    type: AnalyticsParameterType.string,
    required: true,
  );
  static const _number = AnalyticsParameterRule(
    type: AnalyticsParameterType.number,
  );
  static const _requiredNumber = AnalyticsParameterRule(
    type: AnalyticsParameterType.number,
    required: true,
  );

  static final Map<String, AnalyticsEventDefinition> events = Map.unmodifiable({
    appFirstOpen: const AnalyticsEventDefinition(name: appFirstOpen),
    appLaunch: AnalyticsEventDefinition(
      name: appLaunch,
      parameters: {
        'launch_type': const AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          required: true,
          allowedValues: {'cold', 'hot'},
        ),
      },
    ),
    appExit: AnalyticsEventDefinition(
      name: appExit,
      parameters: {'foreground_duration_ms': _requiredNumber},
    ),
    pageView: const AnalyticsEventDefinition(name: pageView),
    pageLeave: AnalyticsEventDefinition(
      name: pageLeave,
      parameters: {'stay_duration_ms': _requiredNumber},
    ),
    dramaCardExposure: AnalyticsEventDefinition(
      name: dramaCardExposure,
      parameters: {
        'drama_id': _requiredString,
        'position': _requiredNumber,
        'category_id': _string,
        'card_scene': _string,
        'search_keyword': _string,
      },
    ),
    popupShow: AnalyticsEventDefinition(
      name: popupShow,
      parameters: {
        'popup_name': _requiredString,
        'popup_config_id': _string,
        // 仅 /api/popup 返回的运营弹框携带该字段；本地业务弹框不传。
        'popup_target_type': _string,
        'target_drama_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) => params['popup_target_type'] == 'drama',
        ),
      },
      // 弹框名称字典中，不同弹框还会携带短剧、剧集、商品等业务字段。
      allowAdditionalParameters: true,
    ),
    // 当前口径：关闭弹窗只允许上报 popup_name。
    popupClose: AnalyticsEventDefinition(
      name: popupClose,
      parameters: {'popup_name': _requiredString},
    ),
    elementClick: AnalyticsEventDefinition(
      name: elementClick,
      parameters: {
        'element_name': _requiredString,
        'position': AnalyticsParameterRule(
          type: AnalyticsParameterType.number,
          requiredWhen: (params) =>
              params['element_name'] == 'payment_method_item' ||
              params['element_name'] == 'home_category_tab' ||
              params['element_name'] == 'vip_product_card' ||
              params['element_name'] == 'coin_product_card' ||
              params['element_name'] == 'drama_card',
        ),
        'category_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'home_category_tab',
        ),
        'favorite_tab': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) => params['element_name'] == 'favorite_tab',
          allowedValues: {'watching', 'history'},
        ),
        'check_in_day': AnalyticsParameterRule(
          type: AnalyticsParameterType.number,
          requiredWhen: (params) =>
              params['element_name'] == 'check_in_claim_button',
        ),
        'task_code': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'task_action_button',
        ),
        'task_action': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'task_action_button',
          allowedValues: {'go_complete', 'claim'},
        ),
        'popup_config_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'campaign_content',
        ),
        'popup_target_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'campaign_content',
          allowedValues: {'close', 'h5', 'page', 'drama'},
        ),
        'target_drama_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'campaign_content' &&
              params['popup_target_type'] == 'drama',
        ),
        'drama_recommend_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'campaign_content' &&
              params['popup_target_type'] == 'drama',
          allowedValues: {'specified', 'auto'},
        ),
        'product_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'vip_product_card' ||
              params['element_name'] == 'coin_product_card',
        ),
        'product_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'vip_product_card' ||
              params['element_name'] == 'coin_product_card',
          allowedValuesWhen: (params) => switch (params['element_name']) {
            'coin_product_card' => {'coin'},
            'vip_product_card' => {'vip_once', 'vip_subscription'},
            _ => null,
          },
        ),
        'payment_click_action': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'vip_product_card' ||
              params['element_name'] == 'coin_product_card',
          allowedValuesWhen: (params) => switch (params['element_name']) {
            'coin_product_card' => {'open_payment_popup', 'start_payment'},
            'vip_product_card' => {
              'select_product',
              'open_payment_popup',
              'start_payment',
            },
            _ => null,
          },
        ),
        'recharge_popup_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          allowedValues: {'with_coin', 'vip_only'},
        ),
        'payment_method_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'payment_method_item',
        ),
        'payment_method_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'payment_method_item',
          allowedValues: {'apple_iap', 'google_play', 'third_party_h5'},
        ),
        'drama_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'episode_unlock_button' ||
              params['element_name'] == 'drama_card',
        ),
        'episode_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'episode_unlock_button',
        ),
        'unlock_button_action': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) =>
              params['element_name'] == 'episode_unlock_button',
          allowedValues: {
            'open_recharge_with_coin',
            'open_recharge_vip_only',
            'confirm_unlock',
          },
        ),
      },
      // 元素字典后续会为不同 element_name 注入短剧、商品等附加字段。
      allowAdditionalParameters: true,
    ),
    userLogout: const AnalyticsEventDefinition(name: userLogout),
    dramaPlayStart: AnalyticsEventDefinition(
      name: dramaPlayStart,
      parameters: {
        'drama_id': _requiredString,
        'episode_id': _requiredString,
        'episode_no': _number,
        'subtitle_language': _requiredString,
        'viewing_entitlement_type': _string,
      },
    ),
    dramaPlayEnd: AnalyticsEventDefinition(
      name: dramaPlayEnd,
      parameters: {
        'drama_id': _requiredString,
        'episode_id': _requiredString,
        'episode_no': _number,
        'play_duration_ms': _requiredNumber,
        'play_progress_ms': _number,
        'play_end_reason': _requiredString,
        'subtitle_language': _string,
        'viewing_entitlement_type': _string,
      },
    ),
    searchSubmit: AnalyticsEventDefinition(
      name: searchSubmit,
      parameters: {'search_keyword': _requiredString},
    ),
    searchResultClick: AnalyticsEventDefinition(
      name: searchResultClick,
      parameters: {
        'drama_id': _requiredString,
        'search_keyword': _requiredString,
        'position': _requiredNumber,
      },
    ),
    paymentStart: AnalyticsEventDefinition(
      name: paymentStart,
      parameters: {
        'payment_method_id': _requiredString,
        'payment_method_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          required: true,
          allowedValues: {'apple_iap', 'google_play', 'third_party_h5'},
        ),
        'order_id': _requiredString,
        'product_id': _requiredString,
        'product_type': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          required: true,
          allowedValues: {'coin', 'vip_once', 'vip_subscription'},
        ),
      },
    ),
    loginFail: AnalyticsEventDefinition(
      name: loginFail,
      parameters: {
        'login_provider': _requiredString,
        'result_status': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          required: true,
          allowedValues: {'failed', 'cancelled'},
        ),
        'login_fail_reason': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) => params['result_status'] == 'failed',
        ),
      },
    ),
    episodeUnlockRequest: AnalyticsEventDefinition(
      name: episodeUnlockRequest,
      parameters: {
        'drama_id': _requiredString,
        'episode_id': _requiredString,
        'unlock_type': _requiredString,
        'unlock_trigger_type': _requiredString,
        'required_coin_amount': _requiredNumber,
        'request_id': _requiredString,
      },
    ),
    pushPermissionResult: AnalyticsEventDefinition(
      name: pushPermissionResult,
      parameters: {'permission_status': _requiredString},
    ),
    pushNotificationOpen: AnalyticsEventDefinition(
      name: pushNotificationOpen,
      parameters: {
        'push_id': _requiredString,
        'push_target_type': _requiredString,
        'drama_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) => params['push_target_type'] == 'drama',
        ),
      },
    ),
    homeBannerExposure: AnalyticsEventDefinition(
      name: homeBannerExposure,
      parameters: {
        'banner_id': _requiredString,
        'banner_target_type': _requiredString,
        'target_drama_id': AnalyticsParameterRule(
          type: AnalyticsParameterType.string,
          requiredWhen: (params) => params['banner_target_type'] == 'drama',
        ),
      },
    ),
    dynamicTabExposure: AnalyticsEventDefinition(
      name: dynamicTabExposure,
      parameters: {
        'tab_config_id': _requiredString,
        'replace_tab_key': _requiredString,
      },
    ),
    adUnlockEntryExposure: AnalyticsEventDefinition(
      name: adUnlockEntryExposure,
      parameters: {
        'drama_id': _requiredString,
        'episode_id': _requiredString,
        'drama_access_type': _requiredString,
        'ad_material_id': _requiredString,
      },
    ),
    adViewStart: AnalyticsEventDefinition(
      name: adViewStart,
      parameters: {
        'ad_session_id': _requiredString,
        'ad_material_id': _requiredString,
        'drama_id': _string,
        'episode_id': _string,
      },
    ),
    adViewEnd: AnalyticsEventDefinition(
      name: adViewEnd,
      parameters: {
        'ad_session_id': _requiredString,
        'ad_material_id': _requiredString,
        'drama_id': _string,
        'episode_id': _string,
        'ad_view_duration_ms': _requiredNumber,
        'ad_view_result': _requiredString,
      },
    ),
    shareAppOpen: AnalyticsEventDefinition(
      name: shareAppOpen,
      parameters: {'landing_type': _requiredString},
    ),
  });
}

/// 基于已登记事件定义进行校验。
class AnalyticsEventValidator {
  AnalyticsEventValidator(this._definitions);

  final Map<String, AnalyticsEventDefinition> _definitions;

  void validate(AnalyticsEvent event) {
    final definition = _definitions[event.name];
    if (definition == null) {
      throw AnalyticsValidationError(eventName: event.name, reason: '事件未登记');
    }

    for (final entry in definition.parameters.entries) {
      final value = event.parameters[entry.key];
      final rule = entry.value;
      if (value == null || (value is String && value.isEmpty)) {
        if (rule.isRequired(event.parameters)) {
          throw AnalyticsValidationError(
            eventName: event.name,
            parameterName: entry.key,
            reason: '缺少必传参数',
          );
        }
        continue;
      }
      if (!_matchesType(value, rule.type)) {
        throw AnalyticsValidationError(
          eventName: event.name,
          parameterName: entry.key,
          reason: '参数类型不正确',
        );
      }
      final allowedValues = rule.allowedValuesFor(event.parameters);
      if (allowedValues != null && !allowedValues.contains(value)) {
        throw AnalyticsValidationError(
          eventName: event.name,
          parameterName: entry.key,
          reason: '参数枚举值不合法',
        );
      }
    }

    if (!definition.allowAdditionalParameters) {
      for (final parameterName in event.parameters.keys) {
        if (!definition.parameters.containsKey(parameterName)) {
          throw AnalyticsValidationError(
            eventName: event.name,
            parameterName: parameterName,
            reason: '该事件不允许此参数',
          );
        }
      }
    }
  }

  bool _matchesType(Object value, AnalyticsParameterType type) {
    return switch (type) {
      AnalyticsParameterType.string => value is String,
      AnalyticsParameterType.number => value is num,
    };
  }
}
