import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_modal_context.dart';
import '../../app/app_root_navigator_key.dart';
import 'app_modal_controller.dart';
import 'app_modal_provider.dart';

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
      if (_presentingRequestId != null) {
        _popRootModalRouteIfOpen();
      }
      _presentingRequestId = null;
      return;
    }
    if (_presentingRequestId == presentation.request.requestId) {
      return;
    }
    _presentingRequestId = presentation.request.requestId;
    unawaited(_presentWhenReady(presentation));
  }

  void _popRootModalRouteIfOpen() {
    if (!mounted) {
      return;
    }
    final navigator = appRootNavigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    _bindController(ref.read(appModalControllerProvider));
    return widget.child ?? const SizedBox.shrink();
  }

  Future<void> _presentWhenReady(AppModalPresentation presentation) async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (!mounted) {
        return;
      }
      final navContext = resolveAppModalPresentationContext(context);
      if (navContext.mounted) {
        await _present(presentation, navContext);
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _present(
    AppModalPresentation presentation,
    BuildContext navContext,
  ) async {
    final controller = ref.read(appModalControllerProvider);
    if (controller.current?.request.requestId !=
        presentation.request.requestId) {
      return;
    }

    final registry = ref.read(appModalPresenterRegistryProvider);
    final requestId = presentation.request.requestId;
    controller.markPresented(requestId);

    final presenter = registry.resolve(presentation.request);
    if (presenter == null) {
      if (controller.current?.request.requestId == requestId) {
        controller.failCurrentPresentation();
      }
      return;
    }

    final result = await presenter.present(
      context: navContext,
      request: presentation.request,
    );

    if (!mounted) {
      return;
    }
    if (_presentingRequestId == requestId) {
      _presentingRequestId = null;
    }
    if (controller.current?.request.requestId == requestId) {
      controller.completeCurrent(result);
    }
  }
}
