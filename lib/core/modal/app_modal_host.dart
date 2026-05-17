import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_root_navigator_key.dart';
import 'app_modal_controller.dart';
import 'app_modal_policy.dart';
import 'app_modal_provider.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';

/// 根级弹窗宿主：在 [MaterialApp] builder 中包裹路由子树，从 root overlay 展示弹窗。
///
/// 瞬态 toast 仍走 [AppToastService]（BotToast）；阻塞式业务弹窗走 [AppModalService]。
class AppModalHost extends ConsumerStatefulWidget {
  const AppModalHost({required this.child, super.key});

  final Widget? child;

  @override
  ConsumerState<AppModalHost> createState() => _AppModalHostState();
}

class _AppModalHostState extends ConsumerState<AppModalHost> {
  AppModalController? _controller;
  String? _presentingRequestId;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _bindController(AppModalController controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _controller?.removeListener(_onControllerChanged);
    _controller = controller;
    _controller!.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final presentation = _controller?.current;
    if (presentation == null) {
      _presentingRequestId = null;
      return;
    }
    if (_presentingRequestId == presentation.request.requestId) {
      return;
    }
    _presentingRequestId = presentation.request.requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _present(presentation);
    });
  }

  @override
  Widget build(BuildContext context) {
    _bindController(ref.read(appModalControllerProvider));
    return widget.child ?? const SizedBox.shrink();
  }

  Future<void> _present(AppModalPresentation presentation) async {
    final controller = ref.read(appModalControllerProvider);
    if (controller.current?.request.requestId !=
        presentation.request.requestId) {
      return;
    }

    final AppModalResult result;
    switch (presentation.request) {
      case ConfirmModalRequest confirm:
        result = await _showConfirmDialog(context, confirm);
      default:
        result = ConfirmResult.dismissed;
    }

    if (!mounted) {
      return;
    }
    if (controller.current?.request.requestId ==
        presentation.request.requestId) {
      controller.completeCurrent(result);
    }
  }

  Future<ConfirmResult> _showConfirmDialog(
    BuildContext context,
    ConfirmModalRequest request,
  ) async {
    final navContext = appRootNavigatorKey.currentContext ?? context;
    final policy = request.dismissPolicy;
    final barrierDismissible =
        policy.barrierDismissible && !policy.requiresExplicitChoice;

    final result = await showDialog<ConfirmResult>(
      context: navContext,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return PopScope(
          canPop: policy.backButtonAllowed && !policy.requiresExplicitChoice,
          onPopInvokedWithResult: (didPop, popResult) {
            if (didPop) {
              return;
            }
            if (policy.backButtonAllowed && !policy.requiresExplicitChoice) {
              Navigator.of(dialogContext).pop(ConfirmResult.dismissed);
            }
          },
          child: AlertDialog(
            key: ValueKey('app_modal_confirm_${request.requestId}'),
            title: Text(request.title),
            content: Text(request.message),
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
