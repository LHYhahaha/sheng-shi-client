import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/webview_page.dart';

/// 问题与帮助 H5 页面及其 JSBridge 通信协议。
class ProfileFeedbackWebViewPage extends ConsumerStatefulWidget {
  const ProfileFeedbackWebViewPage({super.key});

  @override
  ConsumerState<ProfileFeedbackWebViewPage> createState() =>
      _ProfileFeedbackWebViewPageState();
}

class _ProfileFeedbackWebViewPageState
    extends ConsumerState<ProfileFeedbackWebViewPage> {
  CancelFunc? _loadingCancel;

  @override
  Widget build(BuildContext context) {
    final requestContext = ref.read(apiRequestContextProvider);
    final headers = <String, String>{
      ...requestContext.toBaseHeaders(),
      ...?ref.read(channelConfigProvider).asData?.value.toHeaders(),
    };
    final accessToken = requestContext.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return WebViewPage(
      url: AppConfig.current
          .helpUrlForLanguage(context.l10n.locale.languageCode)
          .toString(),
      title: context.l10n.profileFeedback,
      showAppBar: false,
      javaScriptMessageHandlers: {'DramaWaveBridge': _handleJavaScriptMessage},
      onPageStarted: (controller, _) =>
          _injectJavaScriptBridge(controller, headers),
      onPageFinished: (controller, _) =>
          _injectJavaScriptBridge(controller, headers),
    );
  }

  Future<void> _injectJavaScriptBridge(
    WebViewController controller,
    Map<String, String> headers,
  ) async {
    if (!mounted) {
      return;
    }
    final appName = context.l10n.appTitle;
    final i18n = AppLocalizations.remoteStrings ?? const <String, dynamic>{};

    try {
      await controller.runJavaScript('''
        window.JSBridge = window.JSBridge || {};
        window.JSBridge.appName = ${jsonEncode(appName)};
        window.JSBridge.appBaseInfo = {
        appName:${jsonEncode(appName)},
        statusBarHeight:${MediaQuery.paddingOf(context).top}
        };

        window.JSBridge.i18n = ${jsonEncode(i18n)};
        window.JSBridge.httpHeader = ${jsonEncode(headers)};
        window.JSBridge.postMessage = function ({ event, data, callback }) {
          window.DramaWaveBridge.postMessage(JSON.stringify({
            event: event,
            data: data,
            callback: callback,
          }));
        };
      ''');
      debugPrint('[ProfileFeedbackH5] JSBridge injected');
    } on Object catch (error) {
      debugPrint('[ProfileFeedbackH5] Failed to inject JSBridge: $error');
    }
  }

  void _handleJavaScriptMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      debugPrint('[ProfileFeedbackH5] $decoded');
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      switch (decoded['event']) {
        case 'showLoading':
          _loadingCancel ??= BotToast.showLoading(
            allowClick: false,
            clickClose: false,
            crossPage: false,
          );
        case 'hideLoading':
          _loadingCancel?.call();
          _loadingCancel = null;
        case 'showSuccessToast':
          _showH5Toast(decoded, isSuccess: true);
        case 'showFailToast':
          _showH5Toast(decoded, isSuccess: false);
        case 'closeWebView':
          _closeWebView();
      }
    } on FormatException {
      debugPrint('[ProfileFeedbackH5] $message');
    }
  }

  void _showH5Toast(Map<String, dynamic> event, {required bool isSuccess}) {
    if (!mounted) {
      return;
    }

    final data = event['data'];
    final message = data is Map<String, dynamic> ? data['message'] : null;
    if (message is! String || message.isEmpty) {
      return;
    }

    final toast = ref.read(appToastProvider);
    if (isSuccess) {
      toast.success(message);
    } else {
      toast.error(message);
    }
  }

  void _closeWebView() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.profile);
    }
  }

  @override
  void dispose() {
    _loadingCancel?.call();
    super.dispose();
  }
}
