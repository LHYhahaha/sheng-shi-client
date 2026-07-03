import 'package:flutter/material.dart';

import '../app_modal_dismiss.dart';
import '../app_modal_presenter.dart';
import '../app_modal_request.dart';
import '../app_modal_result.dart';

class ConfirmAppModalPresenter implements AppModalPresenter {
  @override
  bool handles(AppModalRequest request) => request is ConfirmModalRequest;

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) {
    return _showConfirmDialog(context, request as ConfirmModalRequest);
  }

  Future<ConfirmResult> _showConfirmDialog(
    BuildContext context,
    ConfirmModalRequest request,
  ) async {
    final policy = request.dismissPolicy;
    final barrierDismissible = appModalBarrierDismissible(policy);
    final backAllowed = appModalBackButtonAllowed(policy);

    final result = await showDialog<ConfirmResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return PopScope(
          canPop: backAllowed,
          onPopInvokedWithResult: (didPop, popResult) {
            if (didPop) {
              return;
            }
            if (backAllowed) {
              Navigator.of(dialogContext).pop(ConfirmResult.dismissed);
            }
          },
          child: AlertDialog(
            key: ValueKey('app_modal_confirm_${request.requestId}'),
            title: request.title.isEmpty ? null : Text(request.title),
            content: request.message.isEmpty ? null : Text(request.message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(ConfirmResult.cancelled);
                },
                child: Text(request.cancelLabel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(ConfirmResult.confirmed);
                },
                child: Text(request.confirmLabel),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      return result;
    }
    return barrierDismissible
        ? ConfirmResult.dismissed
        : ConfirmResult.cancelled;
  }
}
