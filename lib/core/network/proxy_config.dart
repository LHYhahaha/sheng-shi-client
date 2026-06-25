import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 代理配置状态
class ProxyConfigState {
  final String? proxyAddress; // 格式: host:port
  final bool isEnabled;

  const ProxyConfigState({this.proxyAddress, this.isEnabled = false});

  ProxyConfigState copyWith({String? proxyAddress, bool? isEnabled}) {
    return ProxyConfigState(
      proxyAddress: proxyAddress ?? this.proxyAddress,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// 代理配置 Notifier (Riverpod 3.x)
class ProxyConfigNotifier extends Notifier<ProxyConfigState> {
  static const _kProxyEnabled = 'proxy_enabled';
  static const _kProxyAddress = 'proxy_address';

  @override
  ProxyConfigState build() {
    // 同步加载配置，避免初始状态闪烁
    return const ProxyConfigState();
  }

  /// 同步加载配置（在 build 中调用）
  void _loadProxyConfigSync() {
    SharedPreferences.getInstance().then((prefs) {
      final enabled = prefs.getBool(_kProxyEnabled) ?? false;
      final address = prefs.getString(_kProxyAddress);
      state = ProxyConfigState(proxyAddress: address, isEnabled: enabled);
    });
  }

  Future<void> setProxy(String? address) async {
    final prefs = await SharedPreferences.getInstance();
    if (address == null || address.isEmpty) {
      await prefs.setBool(_kProxyEnabled, false);
      await prefs.remove(_kProxyAddress);
      state = const ProxyConfigState();
    } else {
      await prefs.setBool(_kProxyEnabled, true);
      await prefs.setString(_kProxyAddress, address);
      state = ProxyConfigState(proxyAddress: address, isEnabled: true);
    }
  }

  Future<void> clearProxy() async {
    await setProxy(null);
  }
}

/// 代理配置 Provider (Riverpod 3.x)
final proxyConfigProvider =
    NotifierProvider<ProxyConfigNotifier, ProxyConfigState>(
  () => ProxyConfigNotifier(),
);

/// 配置 Dio 代理
void configureDioProxy(Dio dio, String? proxyAddress) {
  // Disabled for release readiness. Keep the stub so old debug UI code can
  // compile without ever applying a Charles proxy or trusting bad certs.
  return;
}

/// 显示代理配置弹窗
Future<void> showProxyConfigDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final currentProxy = ref.read(proxyConfigProvider).proxyAddress ?? '';
  controller.text = currentProxy;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('代理配置 (Charles抓包)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请输入 Charles 代理地址 (IP:端口):',
              style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '例如: 192.168.1.100:8888',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          const Text('提示: Charles 默认端口为 8888',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(proxyConfigProvider.notifier).clearProxy();
            Navigator.of(context).pop();
          },
          child: const Text('清除代理'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final address = controller.text.trim();
            if (address.isNotEmpty) {
              ref.read(proxyConfigProvider.notifier).setProxy(address);
            }
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
