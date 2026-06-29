import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';

final class SystemProxyConfig {
  const SystemProxyConfig({
    required this.host,
    required this.port,
    required this.source,
  });

  final String host;
  final int port;
  final String source;

  String get address => '$host:$port';

  static SystemProxyConfig? fromMethodChannelValue(Object? value) {
    if (value is! Map) {
      return null;
    }

    final host = value['host'];
    final port = value['port'];
    final source = value['source'];
    if (host is! String || host.isEmpty || port is! int || port <= 0) {
      return null;
    }

    return SystemProxyConfig(
      host: host,
      port: port,
      source: source is String ? source : 'unknown',
    );
  }
}

final class SystemProxyConfigService {
  SystemProxyConfigService._();

  static const _channel = MethodChannel('com.yushi.drama/system_proxy');

  static SystemProxyConfig? _cachedConfig;

  static SystemProxyConfig? get cachedConfig => _cachedConfig;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) {
      _cachedConfig = null;
      return;
    }

    try {
      final value = await _channel.invokeMethod<Object?>('getSystemProxy');
      _cachedConfig = SystemProxyConfig.fromMethodChannelValue(value);
      final config = _cachedConfig;
      if (config != null) {
        print(
          '[SystemProxy] Android system proxy enabled: '
          '${config.address} (${config.source})',
        );
      }
    } on MissingPluginException {
      _cachedConfig = null;
    } catch (error) {
      _cachedConfig = null;
      print('[SystemProxy] Failed to read Android system proxy: $error');
    }
  }
}

void configureDioWithSystemProxy(Dio dio) {
  final config = SystemProxyConfigService.cachedConfig;
  if (config == null) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (_) => 'PROXY ${config.address}';
      return client;
    },
  );
}
