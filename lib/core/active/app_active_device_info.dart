import 'dart:ui';

import 'package:flutter/services.dart';

import '../channel/channel_config_service.dart';

class AppActiveDeviceInfo {
  const AppActiveDeviceInfo({
    required this.channelSource,
    required this.region,
    required this.timezone,
  });

  final String channelSource;
  final String region;
  final String timezone;
}

abstract interface class AppActiveDeviceInfoReader {
  Future<AppActiveDeviceInfo> read();
}

class PlatformAppActiveDeviceInfoReader implements AppActiveDeviceInfoReader {
  PlatformAppActiveDeviceInfoReader({
    required ChannelConfigService channelConfigService,
  }) : _channelConfigService = channelConfigService;

  static const _systemInfoChannel = MethodChannel(
    'com.yushi.drama/system_info',
  );

  final ChannelConfigService _channelConfigService;

  @override
  Future<AppActiveDeviceInfo> read() async {
    final locale = PlatformDispatcher.instance.locale;
    final systemInfo = await _readSystemInfo();
    final channelConfig = await _channelConfigService.getChannelConfig();

    return AppActiveDeviceInfo(
      channelSource: _nonEmpty(channelConfig.channelFlag) ?? '',
      region:
          _nonEmpty(systemInfo['region']) ??
          _nonEmpty(locale.countryCode) ??
          'ZZ',
      timezone:
          _nonEmpty(systemInfo['timezone']) ??
          _nonEmpty(DateTime.now().timeZoneName) ??
          'UTC',
    );
  }

  Future<Map<Object?, Object?>> _readSystemInfo() async {
    try {
      return await _systemInfoChannel.invokeMethod<Map<Object?, Object?>>(
            'getSystemInfo',
          ) ??
          const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  static String? _nonEmpty(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
