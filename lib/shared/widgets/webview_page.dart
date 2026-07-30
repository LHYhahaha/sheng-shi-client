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
  });

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Android WebView 默认白底会在 H5 首帧绘制前短暂露出。
      ..setBackgroundColor(AppColors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[WebView] Page started: $url');
            widget.onPageStarted?.call(_controller, url);
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
              _setLoading(false);
            }
          },
          onNavigationRequest: (request) {
            debugPrint('[WebView] Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );

    for (final entry in widget.javaScriptMessageHandlers.entries) {
      _controller.addJavaScriptChannel(
        entry.key,
        onMessageReceived: (message) => entry.value(message.message),
      );
    }

    _initializeController();
  }

  Future<void> _initializeController() async {
    await widget.onControllerCreated?.call(_controller);
    if (!mounted) {
      return;
    }
    await _controller.loadRequest(Uri.parse(widget.url));
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
    await widget.onPageFinished?.call(_controller, url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  context.go(RoutePaths.profile);
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
