import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/router/route_paths.dart';
import '../../shared/theme/app_colors.dart';

typedef WebViewPageLifecycleCallback =
    Future<void> Function(WebViewController controller, String url);
typedef WebViewPageControllerCallback =
    Future<void> Function(WebViewController controller);

class WebViewPage extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final bool showAppBar;
  final Color? feedbackColor;
  final Map<String, ValueChanged<String>> javaScriptMessageHandlers;
  final WebViewPageControllerCallback? onControllerCreated;
  final WebViewPageLifecycleCallback? onPageStarted;
  final WebViewPageLifecycleCallback? onPageFinished;

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
    this.showAppBar = true,
    this.javaScriptMessageHandlers = const {},
    this.onControllerCreated,
    this.onPageStarted,
    this.onPageFinished,
    this.feedbackColor,
  });

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasMainFrameError = false;
  _WebViewFailureKind _failureKind = _WebViewFailureKind.none;
  int _controllerGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeController());
  }

  Future<void> _initializeController() async {
    final uri = _parseH5Uri();
    if (uri == null) {
      _markFailed(_WebViewFailureKind.invalidUrl);
      return;
    }

    try {
      final controller = WebViewController();
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // Android WebView 默认白底会在 H5 首帧绘制前短暂露出。
        ..setBackgroundColor(widget.feedbackColor ?? AppColors.white)
        ..setNavigationDelegate(_navigationDelegate(controller));
      for (final entry in widget.javaScriptMessageHandlers.entries) {
        controller.addJavaScriptChannel(
          entry.key,
          onMessageReceived: (message) => entry.value(message.message),
        );
      }
      if (mounted) {
        setState(() {
          _controller = controller;
          _controllerGeneration++;
          _failureKind = _WebViewFailureKind.none;
          _hasMainFrameError = false;
          _isLoading = true;
        });
      }
      await widget.onControllerCreated?.call(controller);
      if (!mounted) {
        return;
      }
      try {
        await controller.loadRequest(uri);
      } catch (error) {
        debugPrint('[WebView] Page load failed: ${widget.url}, error=$error');
        _markFailed(_WebViewFailureKind.pageLoad);
      }
    } catch (error) {
      debugPrint(
        '[WebView] Initialization failed: ${widget.url}, error=$error',
      );
      _markFailed(_WebViewFailureKind.initialization);
      return;
    }
  }

  NavigationDelegate _navigationDelegate(WebViewController controller) {
    return NavigationDelegate(
      onPageStarted: (String url) {
        debugPrint('[WebView] Page started: $url');
        _failureKind = _WebViewFailureKind.none;
        _hasMainFrameError = false;
        _setLoading(true);
        widget.onPageStarted?.call(controller, url);
      },
      onPageFinished: _onPageFinished,
      onHttpError: (error) {
        debugPrint(
          '[WebView] HTTP error: '
          'url=${error.request?.uri}, '
          'statusCode=${error.response?.statusCode}, '
          'responseUrl=${error.response?.uri}',
        );
        _setLoading(false);
      },
      onWebResourceError: (error) {
        debugPrint(
          '[WebView] Resource error: '
          'url=${error.url}, '
          'code=${error.errorCode}, '
          'type=${error.errorType}, '
          'mainFrame=${error.isForMainFrame}, '
          'description=${error.description}',
        );
        if (error.isForMainFrame ?? true) {
          _markFailed(_WebViewFailureKind.pageLoad);
        }
      },
      onNavigationRequest: (request) {
        debugPrint('[WebView] Navigation request: ${request.url}');
        return NavigationDecision.navigate;
      },
    );
  }

  Uri? _parseH5Uri() {
    final uri = Uri.tryParse(widget.url.trim());
    return uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }

  void _markFailed(_WebViewFailureKind failureKind) {
    if (!mounted) {
      return;
    }
    setState(() {
      _failureKind = failureKind;
      _hasMainFrameError = true;
      _isLoading = false;
    });
  }

  void _retry() {
    switch (_failureKind) {
      case _WebViewFailureKind.initialization:
        unawaited(_initializeController());
        return;
      case _WebViewFailureKind.pageLoad:
        final controller = _controller;
        if (controller != null) {
          setState(() {
            _hasMainFrameError = false;
            _isLoading = true;
          });
          unawaited(controller.reload());
        }
        return;
      case _WebViewFailureKind.invalidUrl:
        unawaited(_retryInvalidUrl());
        return;
      case _WebViewFailureKind.none:
        return;
    }
  }

  Future<void> _retryInvalidUrl() async {
    setState(() {
      _hasMainFrameError = false;
      _isLoading = true;
    });
    // 无效地址不会真的发起导航；短暂加载态让点击有明确反馈，再显示失败页。
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _markFailed(_WebViewFailureKind.invalidUrl);
  }

  void _setLoading(bool isLoading) {
    if (!mounted || _isLoading == isLoading) {
      return;
    }
    setState(() => _isLoading = isLoading);
  }

  Future<void> _onPageFinished(String url) async {
    debugPrint('[WebView] Page finished: $url');
    _setLoading(false);
    final controller = _controller;
    if (controller != null) {
      await widget.onPageFinished?.call(controller, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: AppColors.black,
                leading: IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                      return;
                    }
                    context.go(RoutePaths.home);
                  },
                ),
                title: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    // fontSize: 18,
                    // fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
              )
            : null,
        body: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(
                key: ValueKey('webview_$_controllerGeneration'),
                controller: _controller!,
              ),
            if (_hasMainFrameError)
              Positioned.fill(
                child: ColoredBox(
                  color: widget.feedbackColor ?? AppColors.white,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 32),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isLoading)
              Positioned.fill(
                // Keep the native WebView's default white first frame hidden
                // until the H5 page has finished rendering.
                child: ColoredBox(
                  color: widget.feedbackColor ?? AppColors.white,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _WebViewFailureKind { none, initialization, pageLoad, invalidUrl }
