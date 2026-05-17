import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_modal_context.dart';
import '../../../../core/modal/app_modal_presenter.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_root_sheet.dart';
import 'auth_login_intent.dart';
import 'auth_login_modal_sheet.dart';
import 'auth_modal_channels.dart';
import 'auth_modal_payloads.dart';

/// Auth 登录弹窗 presenter：root bottom sheet + [AuthLoginModalSheet]。
class AuthAppModalPresenter implements AppModalPresenter {
  const AuthAppModalPresenter();

  @override
  bool handles(AppModalRequest request) {
    return request is FeatureAppModalRequest &&
        request.channel == AuthModalChannels.login;
  }

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) async {
    final featureRequest = request as FeatureAppModalRequest;
    final payload =
        featureRequest.payload as AuthLoginModalPayload? ??
        const AuthLoginModalPayload(intent: AuthLoginIntent.userInitiated);

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);

    final sheetResult = await showAppModalRootBottomSheet<LoginModalResult?>(
      context: modalContext,
      isScrollControlled: true,
      isDismissible: featureRequest.dismissPolicy.barrierDismissible,
      enableDrag: featureRequest.dismissPolicy.barrierDismissible,
      builder: (sheetContext) {
        return UncontrolledProviderScope(
          container: container,
          child: AuthLoginModalSheet(payload: payload),
        );
      },
    );

    return sheetResult ??
        (featureRequest.dismissPolicy.barrierDismissible
            ? const LoginModalResult.dismissed()
            : const LoginModalResult.cancelled());
  }
}
