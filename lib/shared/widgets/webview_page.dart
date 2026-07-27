import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/router/route_paths.dart';
import '../../shared/theme/app_colors.dart';

class WebViewPage extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final bool showAppBar;
  final Map<String, ValueChanged<String>> javaScriptMessageHandlers;

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
    this.showAppBar = true,
    this.javaScriptMessageHandlers = const {},
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    for (final entry in widget.javaScriptMessageHandlers.entries) {
      _controller.addJavaScriptChannel(
        entry.key,
        onMessageReceived: (message) => entry.value(message.message),
      );
    }

    _controller.loadRequest(Uri.parse(widget.url));
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
