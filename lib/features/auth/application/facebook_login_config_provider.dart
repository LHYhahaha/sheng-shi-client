import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/json_field_parser.dart';

const facebookLoginConfigCode = 'facebook_login_config';

/// 是否展示 Facebook 登录按钮。
///
/// 所有非明确的 `enabled: true` 情况（接口异常、配置缺失或 content 非法）均关闭，
/// 避免在服务端未配置时暴露不可用的三方登录入口。
final facebookLoginEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref
        .watch(apiClientProvider)
        .get<bool>(
          '/api/config/param',
          queryParameters: const {'code': facebookLoginConfigCode},
          authPolicy: ApiAuthPolicy.none,
          decoder: (data) {
            final config = JsonFieldParser.requireMap(
              data,
              dtoName: 'ParamConfig',
            );
            if (config['code'] != facebookLoginConfigCode) {
              return false;
            }
            final content = JsonFieldParser.optionalString(config, 'content');
            if (content == null) {
              return false;
            }
            final parsed = jsonDecode(content);
            return parsed is Map && parsed['enabled'] == true;
          },
        );
  } catch (_) {
    return false;
  }
});
