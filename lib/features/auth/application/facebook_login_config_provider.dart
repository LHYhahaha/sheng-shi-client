import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/json_field_parser.dart';

class LoginConfig {
  const LoginConfig({
    required this.facebookVisible,
    required this.phoneVisible,
  });
  final bool facebookVisible;
  final bool phoneVisible;
  factory LoginConfig.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'LoginConfigResponse',
    );
    return LoginConfig(
      facebookVisible: map['facebook_login_visible'] == true,
      phoneVisible: map['phone_login_visible'] == true,
    );
  }
}

final loginConfigProvider = FutureProvider<LoginConfig>((ref) async {
  try {
    return await ref
        .watch(apiClientProvider)
        .get<LoginConfig>(
          '/api/config/login-config',
          authPolicy: ApiAuthPolicy.required,
          decoder: LoginConfig.fromJson,
        );
  } catch (_) {
    return const LoginConfig(facebookVisible: false, phoneVisible: false);
  }
});

final facebookLoginEnabledProvider = FutureProvider<bool>(
  (ref) async => (await ref.watch(loginConfigProvider.future)).facebookVisible,
);
