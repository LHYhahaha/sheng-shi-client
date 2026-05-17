import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_modal_context.dart';
import 'app_modal_controller.dart';
import 'app_modal_provider.dart';
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
  String? _presentingCurrentRequestId;
  final Set<String> _presentingStackedRequestIds = {};

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
    final controller = _controller;
    if (controller == null) {
      return;
    }

    for (final presentation in controller.stackedPresentations) {
      final requestId = presentation.request.requestId;
      if (_presentingStackedRequestIds.contains(requestId)) {
        continue;
      }
      _presentingStackedRequestIds.add(requestId);
      unawaited(_presentStacked(presentation));
    }

    final presentation = controller.current;
    if (presentation == null) {
      _presentingCurrentRequestId = null;
      return;
    }

    final requestId = presentation.request.requestId;
    if (_presentingCurrentRequestId == requestId) {
      return;
    }
    _presentingCurrentRequestId = requestId;
    unawaited(_presentCurrent(presentation));
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

  Future<void> _presentCurrent(AppModalPresentation presentation) async {
    await _presentWhenReady(presentation);
    if (_presentingCurrentRequestId == presentation.request.requestId) {
      _presentingCurrentRequestId = null;
    }
  }

  Future<void> _presentStacked(AppModalPresentation presentation) async {
    await _presentWhenReady(presentation);
    _presentingStackedRequestIds.remove(presentation.request.requestId);
  }

  Future<void> _present(
    AppModalPresentation presentation,
    BuildContext navContext,
  ) async {
    final controller = ref.read(appModalControllerProvider);
    final requestId = presentation.request.requestId;
    if (!controller.containsPresentation(requestId)) {
      return;
    }

    final registry = ref.read(appModalPresenterRegistryProvider);
    controller.markPresented(requestId);

    final presenter = registry.resolve(presentation.request);
    if (presenter == null) {
      if (controller.containsPresentation(requestId)) {
        controller.completePresentation(
          requestId,
          const AppModalPresentFailedResult(),
        );
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
    if (controller.containsPresentation(requestId)) {
      controller.completePresentation(requestId, result);
    }
  }
}
