import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/router/route_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/url/external_url_launcher.dart';
import '../../shared/widgets/app_empty_state.dart';

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

  /// 设为 false 时，由外层页面全权处理系统返回。用于具备 H5 回退协议的页面，
  /// 避免本组件的默认 `go('/home')` 兜底与外层 PopScope 发生竞争。
  final bool handlesSystemBack;

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
    this.handlesSystemBack = true,
  });

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasMainFrameError = false;
  int _controllerGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeController());
  }

  Future<void> _initializeController() async {
    final uri = _parseH5Uri();
    if (uri == null) {
      _markFailed();
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
        _markFailed();
      }
    } catch (error) {
      debugPrint(
        '[WebView] Initialization failed: ${widget.url}, error=$error',
      );
      _markFailed();
      return;
    }
  }

  NavigationDelegate _navigationDelegate(WebViewController controller) {
    return NavigationDelegate(
      onPageStarted: (String url) {
        debugPrint('[WebView] Page started: $url');
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
          _markFailed();
        }
      },
      onNavigationRequest: (request) async {
        debugPrint('[WebView] Navigation request: ${request.url}');
        final uri = Uri.tryParse(request.url);
        // H5 页面可能尝试打开宿主 App 的自定义 scheme（例如 baiduboxapp://）。
        // 优先交由系统外部应用处理；无处理应用时保留当前 H5，不能让 WebView
        // 自己加载并回调 main-frame error。
        if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
          final opened = uri != null && uri.scheme.isNotEmpty
              ? await ref.read(externalUrlLauncherProvider).open(request.url)
              : false;
          debugPrint(
            opened
                ? '[WebView] Opened external navigation: ${request.url}'
                : '[WebView] Blocked unsupported navigation: ${request.url}',
          );
          // 外部跳转已由系统处理（或系统不支持），均禁止 WebView 内部继续导航。
          return NavigationDecision.prevent;
        }
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

  void _markFailed() {
    if (!mounted) {
      return;
    }
    setState(() {
      _hasMainFrameError = true;
      _isLoading = false;
    });
  }

  void _retry() {
    // 所有失败均从原始 URL 重新创建并加载，包含无效 URL。无效 URL 会立即回到
    // 空状态，不再以延时 loading 制造“正在重试”的假象。
    unawaited(_initializeController());
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
    final page = Scaffold(
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
      body:

      Stack(
        children: [
          if (_controller != null)
            WebViewWidget(
              key: ValueKey('webview_$_controllerGeneration'),
              controller: _controller!,
            ),
          if (_hasMainFrameError)
            Positioned.fill(
              child: Center(
                child: AppEmptyState(
                  message: context.l10n.categoryEmpty,
                  buttonLabel: context.l10n.retry,
                  onButtonPressed: _retry,
                ),
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              // 在 H5 首帧完成前保持与 WebView 相同的黑色背景。
              child: ColoredBox(
                color: AppColors.black,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
    if (!widget.handlesSystemBack) {
      return page;
    }
    final canPop = context.canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          context.go(RoutePaths.home);
        }
      },
      child: page,
    );
  }
}
