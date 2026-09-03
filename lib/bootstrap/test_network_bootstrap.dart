import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/presentation/widgets/novashort_splash_page.dart';
import '../core/network/test_network_config.dart';
import '../core/network/test_network_config_dialog.dart';
import '../core/runtime/startup_loading_timing.dart';
import '../l10n/app_localizations.dart';

/// 测试网络启动闸门。
///
/// 在代理和域名确认前不创建业务 App，确保登录、首页、活跃上报等 HTTP 请求都使用
/// 已确认的网络配置。prod 包和 Flutter 自动化测试会直接返回 [child]。
class TestNetworkBootstrap extends ConsumerStatefulWidget {
  const TestNetworkBootstrap({required this.child, this.onReady, super.key});

  final Widget child;
  final VoidCallback? onReady;

  @override
  ConsumerState<TestNetworkBootstrap> createState() =>
      _TestNetworkBootstrapState();
}

class _TestNetworkBootstrapState extends ConsumerState<TestNetworkBootstrap> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _ready = !TestNetworkTools.enabled;
  bool _dialogScheduled = false;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    if (_ready) {
      startupLoadingTiming.start();
      _notifyReadyAfterFirstFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }

    if (!_dialogScheduled) {
      _dialogScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _configureNetwork());
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const NovaShortSplashPage(),
    );
  }

  Future<void> _configureNetwork() async {
    if (!mounted) {
      return;
    }
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      _dialogScheduled = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    await showTestNetworkConfigDialog(
      navigatorContext,
      ref,
      sessionBootstrapFollows: true,
    );
    if (mounted) {
      startupLoadingTiming.start();
      setState(() => _ready = true);
      _notifyReadyAfterFirstFrame();
    }
  }

  void _notifyReadyAfterFirstFrame() {
    if (_readyNotified) {
      return;
    }
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReady?.call();
      }
    });
  }
}
