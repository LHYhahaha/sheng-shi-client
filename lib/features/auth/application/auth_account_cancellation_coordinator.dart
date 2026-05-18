import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/app_modal_controller.dart';
import '../../../core/modal/app_modal_policy.dart';
import '../../../core/modal/app_modal_provider.dart';
import '../../../core/modal/app_modal_request.dart';
import '../../../core/modal/app_modal_result.dart';
import '../../../core/modal/app_modal_service.dart';
import '../../../core/modal/app_modal_source.dart';

/// 账号注销二次确认（AppModal confirm，不走页面内 showDialog）。
class AuthAccountCancellationCoordinator {
  const AuthAccountCancellationCoordinator({
    required AppModalService modalService,
    required AppModalController modalController,
  }) : _modalService = modalService,
       _modalController = modalController;

  final AppModalService _modalService;
  final AppModalController _modalController;

  Future<ConfirmResult> showDeleteConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) {
    return _modalService.showConfirm(
      ConfirmModalRequest(
        requestId: _modalController.nextRequestId(),
        source: AppModalSource.auth,
        priority: AppModalPriority.critical,
        dismissPolicy: AppModalDismissPolicy.standard,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }
}

final authAccountCancellationCoordinatorProvider =
    Provider<AuthAccountCancellationCoordinator>((ref) {
      return AuthAccountCancellationCoordinator(
        modalService: ref.watch(appModalServiceProvider),
        modalController: ref.watch(appModalControllerProvider),
      );
    }, name: 'authAccountCancellationCoordinator');
