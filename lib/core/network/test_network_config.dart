import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_environment.dart';
import 'system_proxy_config.dart';

abstract final class TestNetworkTools {
  static const _appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// prod 包无条件关闭，不能通过运行时配置重新开启。
  static const compiledIn =
      _appEnvironment != 'prod' &&
      bool.fromEnvironment('TEST_NETWORK_TOOLS', defaultValue: true);

  /// 开发 Debug 和测试 Release 包均可使用；Flutter 自动化测试不弹启动框。
  static bool get enabled =>
      compiledIn && Platform.environment['FLUTTER_TEST'] != 'true';
}

class TestNetworkConfigService {
  TestNetworkConfigService._(this._preferences) {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    if (TestNetworkTools.enabled) {
      proxyHost = preferences.getString(_proxyHostKey) ?? '';
      proxyPort = preferences.getInt(_proxyPortKey);
      useProductionEnvironment =
          preferences.getBool(_useProductionEnvironmentKey) ?? false;
    }
  }

  static const _proxyHostKey = 'test_network.proxy_host';
  static const _proxyPortKey = 'test_network.proxy_port';
  static const _useProductionEnvironmentKey =
      'test_network.use_production_environment';

  final SharedPreferences? _preferences;

  String proxyHost = '';
  int? proxyPort;
  bool useProductionEnvironment = false;

  static TestNetworkConfigService create(SharedPreferences preferences) {
    return TestNetworkConfigService._(preferences);
  }

  static TestNetworkConfigService memory() => TestNetworkConfigService._(null);

  SystemProxyConfig? get proxy {
    if (!TestNetworkTools.enabled ||
        proxyHost.trim().isEmpty ||
        proxyPort == null) {
      return null;
    }
    return SystemProxyConfig(
      host: proxyHost.trim(),
      port: proxyPort!,
      source: 'tester_input',
    );
  }

  String get apiBaseUrl {
    if (!TestNetworkTools.enabled) {
      return AppConfig.current.apiBaseUrl.toString();
    }
    final environment = useProductionEnvironment
        ? AppEnvironment.prod
        : AppEnvironment.dev;
    return AppConfig.forEnvironment(environment).apiBaseUrl.toString();
  }

  Future<void> save({
    required String host,
    required int? port,
    required bool useProduction,
  }) async {
    if (!TestNetworkTools.enabled) {
      return;
    }

    proxyHost = host.trim();
    proxyPort = proxyHost.isEmpty ? null : port;
    useProductionEnvironment = useProduction;

    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    if (proxyHost.isEmpty) {
      await preferences.remove(_proxyHostKey);
      await preferences.remove(_proxyPortKey);
    } else {
      await preferences.setString(_proxyHostKey, proxyHost);
      await preferences.setInt(_proxyPortKey, proxyPort!);
    }
    await preferences.setBool(
      _useProductionEnvironmentKey,
      useProductionEnvironment,
    );
  }

  Future<void> clearProxy() =>
      save(host: '', port: null, useProduction: useProductionEnvironment);
}

final testNetworkConfigProvider = Provider<TestNetworkConfigService>((ref) {
  return TestNetworkConfigService.memory();
});
