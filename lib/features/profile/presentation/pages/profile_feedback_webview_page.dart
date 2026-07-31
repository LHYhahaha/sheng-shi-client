import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/account/account_ban_controller.dart';
import '../../../../core/auth/user_info_store.dart';
import '../../../../features/auth/application/auth_controller.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  late final AccountBanController _accountBanController;
  late final AuthController _authController;
  late final bool _openedForAccountBan;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _accountBanController = ref.read(accountBanControllerProvider.notifier);
    _authController = ref.read(authControllerProvider.notifier);
    _openedForAccountBan = ref
        .read(accountBanControllerProvider)
        .isViewingFeedback;
  }

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
    final userInfo = ref.watch(userInfoStoreProvider);
    final bridgeData = _ProfileFeedbackBridgeData(
      appName: context.l10n.appTitle,
      statusBarHeight: MediaQuery.paddingOf(context).top,
      safeAreaBottom: MediaQuery.paddingOf(context).bottom,
      // 这里使用后端返回后保存在 UserInfoStore 中的资料，不传本地默认头像。
      // 后端没有返回时按 H5 协议传空字符串。
      nickname: userInfo.nickname ?? '',
      avatarUrl: userInfo.avatar ?? '',
      i18n: AppLocalizations.remoteStrings ?? const <String, dynamic>{},
      headers: headers,
    );

    return PopScope(
      // H5 自行决定返回行为；只有它发出 closeWebView 时才关闭原生页面。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _notifyH5OfBackRequest();
        }
      },
      child: WebViewPage(
        url:
            // "http://192.168.1.55:5173/app/#/help",
            AppConfig.current
                .helpUrlForLanguage(context.l10n.locale.languageCode)
                .toString(),
        title: context.l10n.profileFeedback,
        showAppBar: false,
        feedbackColor: Colors.black,
        javaScriptMessageHandlers: {
          'DramaWaveBridge': _handleJavaScriptMessage,
        },
        // 在加载 URL 前完成 Android 文件选择器配置，避免延迟 JSBridge 注入。
        onControllerCreated: (controller) async {
          _webViewController = controller;
          await _configureImageFileSelector(controller);
        },
        onPageStarted: (controller, _) =>
            _injectJavaScriptBridge(controller, bridgeData),
        onPageFinished: (controller, _) =>
            _injectJavaScriptBridge(controller, bridgeData),
      ),
    );
  }

  Future<void> _notifyH5OfBackRequest() async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    try {
      await controller.runJavaScript('''
        window.dispatchEvent(new CustomEvent('appBack'));
      ''');
    } on Object catch (error) {
      debugPrint('[ProfileFeedbackH5] Failed to notify back request: $error');
    }
  }

  Future<void> _configureImageFileSelector(WebViewController controller) async {
    final platformController = controller.platform;
    if (platformController is! AndroidWebViewController) {
      return;
    }

    await platformController.setOnShowFileSelector(_selectImages);
  }

  Future<List<String>> _selectImages(FileSelectorParams params) async {
    debugPrint(
      '[ProfileFeedbackH5] Image selector requested: '
      'acceptTypes=${params.acceptTypes}, mode=${params.mode}',
    );

    if (params.mode == FileSelectorMode.openMultiple) {
      final images = await _imagePicker.pickMultiImage();
      return images.map((image) => Uri.file(image.path).toString()).toList();
    }

    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return const [];
    }
    return [Uri.file(image.path).toString()];
  }

  Future<void> _injectJavaScriptBridge(
    WebViewController controller,
    _ProfileFeedbackBridgeData bridgeData,
  ) async {
    if (!mounted) {
      return;
    }
    try {
      await controller.runJavaScript('''
        window.JSBridge = window.JSBridge || {};
        window.JSBridge.appName = ${jsonEncode(bridgeData.appName)};
        window.JSBridge.appBaseInfo = {
        appName:${jsonEncode(bridgeData.appName)},
        statusBarHeight:${bridgeData.statusBarHeight},
        safeAreaBottom:${bridgeData.safeAreaBottom}
        };

        window.JSBridge.userInfo = {
        nickname:${jsonEncode(bridgeData.nickname)},
        avatarUrl:${jsonEncode(bridgeData.avatarUrl)}
        };

        window.JSBridge.i18n = ${jsonEncode(bridgeData.i18n)};
        window.JSBridge.httpHeader = ${jsonEncode(bridgeData.headers)};
        window.JSBridge.postMessage = function ({ event, data, callback }) {
          window.DramaWaveBridge.postMessage(JSON.stringify({
            event: event,
            data: data,
            callback: callback,
          }));
        };

        // H5 uses this signal to wait until every JSBridge field, especially
        // postMessage, is ready before attempting to call the native bridge.
        window.dispatchEvent(new Event('jsBridgeReady'));
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
    if (_openedForAccountBan) {
      // 路由返回时当前组件正处于卸载阶段，延后恢复遮罩并重验账号，避免在
      // dispose 中更新 provider。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_accountBanController.beginRevalidation()) {
          return;
        }
        _reauthenticateAfterFeedback(
          accountBanController: _accountBanController,
          authController: _authController,
        );
      });
    }
    super.dispose();
  }
}

Future<void> _reauthenticateAfterFeedback({
  required AccountBanController accountBanController,
  required AuthController authController,
}) async {
  final isUnbanned = await authController.recoverAfterAccountBan();
  if (!isUnbanned) {
    accountBanController.completeRevalidationAsBanned();
  }
}

class _ProfileFeedbackBridgeData {
  const _ProfileFeedbackBridgeData({
    required this.appName,
    required this.statusBarHeight,
    required this.nickname,
    required this.avatarUrl,
    required this.i18n,
    required this.headers,
    required this.safeAreaBottom,
  });

  final String appName;
  final double statusBarHeight;
  final double safeAreaBottom;
  final String nickname;
  final String avatarUrl;
  final Map<String, dynamic> i18n;
  final Map<String, String> headers;
}
