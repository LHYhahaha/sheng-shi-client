import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/app_modal_controller.dart';
import '../../../core/modal/app_modal_policy.dart';
import '../../../core/modal/app_modal_provider.dart';
import '../../../core/modal/app_modal_request.dart';
import '../../../core/modal/app_modal_service.dart';
import '../../../core/modal/app_modal_source.dart';
import '../presentation/modal/auth_login_intent.dart';
import '../presentation/modal/auth_modal_channels.dart';
import '../presentation/modal/auth_modal_payloads.dart';
import '../presentation/modal/auth_modal_results.dart';
import 'auth_controller.dart';

/// Auth 登录弹窗编排（主动登录 / login required / session expired 提示）。
class AuthModalCoordinator {
  AuthModalCoordinator({
    required AppModalService modalService,
    required AppModalController modalController,
    required AuthState Function() readAuthState,
  }) : _modalService = modalService,
       _modalController = modalController,
       _readAuthState = readAuthState;

  final AppModalService _modalService;
  final AppModalController _modalController;
  final AuthState Function() _readAuthState;

  /// 用户主动登录（如 Profile 入口）。
  Future<AuthLoginModalResult> showLogin(BuildContext context) {
    return _present(
      context,
      const AuthLoginModalPayload(
        intent: AuthLoginIntent.userInitiated,
        triggerSource: AppModalSource.auth,
      ),
    );
  }

  /// 业务动作需要正式用户身份时调用。
  Future<AuthLoginModalResult> showLoginRequired(
    BuildContext context, {
    required AuthLoginRequiredReason reason,
    String? message,
  }) {
    return _present(
      context,
      AuthLoginModalPayload(
        intent: AuthLoginIntent.loginRequired,
        reason: reason,
        triggerSource: _sourceForReason(reason),
        message: message,
      ),
    );
  }

  /// 会话失效后由页面在用户操作时提示登录（不自动弹）。
  Future<AuthLoginModalResult> showSessionExpiredLogin(
    BuildContext context, {
    String? message,
  }) {
    return _present(
      context,
      AuthLoginModalPayload(
        intent: AuthLoginIntent.sessionExpiredPrompt,
        triggerSource: AppModalSource.system,
        message: message,
      ),
    );
  }

  void dismissAuthModals() {
    _modalService.dismissForSource(AppModalSource.auth);
  }

  Future<AuthLoginModalResult> _present(
    BuildContext context,
    AuthLoginModalPayload payload,
  ) async {
    final authState = _readAuthState();
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      return AuthLoginModalResult.success(
        provider: user.provider,
        user: user,
        accountLinked: authState.session.guestId != null,
      );
    }

    if (!context.mounted) {
      return const AuthLoginModalResult.dismissed();
    }

    final request = FeatureAppModalRequest(
      requestId: _modalController.nextRequestId(),
      source: payload.triggerSource,
      channel: AuthModalChannels.login,
      type: AppModalType.login,
      payload: payload,
      priority: AppModalPriority.high,
    );

    final result = await _modalService.show(request);
    return AuthLoginModalResult.fromAppModalResult(result);
  }

  AppModalSource _sourceForReason(AuthLoginRequiredReason reason) {
    return switch (reason) {
      AuthLoginRequiredReason.profile => AppModalSource.auth,
      AuthLoginRequiredReason.wallet => AppModalSource.wallet,
      AuthLoginRequiredReason.myList => AppModalSource.system,
      AuthLoginRequiredReason.store ||
      AuthLoginRequiredReason.storeRestore => AppModalSource.store,
      AuthLoginRequiredReason.player => AppModalSource.player,
      AuthLoginRequiredReason.orders => AppModalSource.system,
      AuthLoginRequiredReason.deleteAccount => AppModalSource.auth,
      AuthLoginRequiredReason.generic => AppModalSource.system,
    };
  }
}

final authModalCoordinatorProvider = Provider<AuthModalCoordinator>((ref) {
  return AuthModalCoordinator(
    modalService: ref.watch(appModalServiceProvider),
    modalController: ref.watch(appModalControllerProvider),
    readAuthState: () => ref.read(authControllerProvider),
  );
});
