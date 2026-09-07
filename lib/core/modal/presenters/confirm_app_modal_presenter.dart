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
          child:
              (request.style == ConfirmModalStyle.searchHistoryClear ||
                  request.style == ConfirmModalStyle.compact)
              ? _CompactConfirmDialog(
                  request: request,
                  onCancel: () =>
                      Navigator.of(dialogContext).pop(ConfirmResult.cancelled),
                  onConfirm: () =>
                      Navigator.of(dialogContext).pop(ConfirmResult.confirmed),
                )
              : AlertDialog(
                  key: ValueKey('app_modal_confirm_${request.requestId}'),
                  title: request.title.isEmpty ? null : Text(request.title),
                  content: request.message.isEmpty
                      ? null
                      : Text(request.message),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop(ConfirmResult.cancelled);
                      },
                      child: Text(request.cancelLabel),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop(ConfirmResult.confirmed);
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

class _CompactConfirmDialog extends StatelessWidget {
  const _CompactConfirmDialog({
    required this.request,
    required this.onCancel,
    required this.onConfirm,
  });

  final ConfirmModalRequest request;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF363636);
    Color dividerColor = Color(0xFFFFFFFF).withValues(alpha: 0.2);

    return Dialog(
      key: ValueKey('app_modal_confirm_${request.requestId}'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 46),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(32, 32, 32, 24),
                child: Text(
                  request.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          overlayColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          request.cancelLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: onConfirm,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4D5A),
                          overlayColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          request.confirmLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
