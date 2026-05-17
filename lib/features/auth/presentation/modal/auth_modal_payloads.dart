import '../../../../core/modal/app_modal_source.dart';
import 'auth_login_intent.dart';

/// Auth 登录弹窗 payload。
class AuthLoginModalPayload {
  const AuthLoginModalPayload({
    required this.intent,
    this.reason,
    this.triggerSource = AppModalSource.auth,
    this.message,
  });

  final AuthLoginIntent intent;
  final AuthLoginRequiredReason? reason;
  final AppModalSource triggerSource;
  final String? message;
}
