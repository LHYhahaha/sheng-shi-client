import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 渠道配置服务
///
/// 从Android原生层读取渠道配置信息
class ChannelConfigService {
  static const _channel = MethodChannel('com.yushi.drama/channel_config');
  
  ChannelConfig? _cachedConfig;

  /// 获取渠道配置
  ///
  /// 返回包含以下字段的Map：
  /// - channel_flag: 渠道标识（test、huawei等）
  /// - merchant_id: 商户ID
  /// - vest_pkg_id: 包ID
  ///
  /// 如果无法获取或不存在，对应字段为null
  Future<ChannelConfig> getChannelConfig() async {
    // 如果已经缓存，直接返回
    if (_cachedConfig != null) {
      print('[ChannelConfigService] 使用缓存的配置: $_cachedConfig');
      return _cachedConfig!;
    }

    try {
      print('[ChannelConfigService] 开始读取渠道配置...');
      print('[ChannelConfigService] MethodChannel 名称: com.yushi.drama/channel_config');
      
      final result = await _channel.invokeMethod<Map>('getChannelConfig');
      
      print('[ChannelConfigService] MethodChannel 返回原始结果: $result');
      print('[ChannelConfigService] 返回结果类型: ${result.runtimeType}');
      
      if (result != null) {
        print('[ChannelConfigService] result 包含的键: ${result.keys.toList()}');
        result.forEach((key, value) {
          print('[ChannelConfigService]   $key = $value (类型: ${value.runtimeType})');
        });
      }
      
      final channelFlag = result?['channel_flag'] as String?;
      final merchantId = result?['merchant_id'] as String?;
      final vestPkgId = result?['vest_pkg_id'] as String?;
      
      print('[ChannelConfigService] 解析结果:');
      print('[ChannelConfigService]   channel_flag = $channelFlag');
      print('[ChannelConfigService]   merchant_id = $merchantId');
      print('[ChannelConfigService]   vest_pkg_id = $vestPkgId');
      
      _cachedConfig = ChannelConfig(
        channelFlag: channelFlag,
        merchantId: merchantId,
        vestPkgId: vestPkgId,
      );
      
      print('[ChannelConfigService] 解析后的配置: $_cachedConfig');
      print('[ChannelConfigService] hasConfig: ${_cachedConfig!.hasConfig}');
      
      return _cachedConfig!;
    } catch (e, stackTrace) {
      // 如果获取失败（比如在非Android平台或没有配置），返回空配置
      print('[ChannelConfigService] 读取渠道配置失败: $e');
      print('[ChannelConfigService] 堆栈: $stackTrace');
      _cachedConfig = const ChannelConfig();
      return _cachedConfig!;
    }
  }

  /// 获取缓存的渠道配置（同步）
  ///
  /// 如果还没有加载，返回null
  ChannelConfig? get cachedConfig => _cachedConfig;
}

/// 渠道配置数据类
class ChannelConfig {
  final String? channelFlag;
  final String? merchantId;
  final String? vestPkgId;

  const ChannelConfig({
    this.channelFlag,
    this.merchantId,
    this.vestPkgId,
  });

  /// 是否有渠道配置
  bool get hasConfig =>
      channelFlag != null || merchantId != null || vestPkgId != null;

  /// 转换为请求头Map
  Map<String, String> toHeaders() {
    final headers = <String, String>{};
    
    if (channelFlag != null && channelFlag!.isNotEmpty) {
      headers['Channel-Flag'] = channelFlag!;
    }
    
    if (merchantId != null && merchantId!.isNotEmpty) {
      headers['Merchant-Id'] = merchantId!;
    }
    
    if (vestPkgId != null && vestPkgId!.isNotEmpty) {
      headers['Vest-Pkg-Id'] = vestPkgId!;
    }
    
    return headers;
  }

  @override
  String toString() {
    return 'ChannelConfig(channelFlag: $channelFlag, merchantId: $merchantId, vestPkgId: $vestPkgId)';
  }
}

/// Provider for ChannelConfigService
final channelConfigServiceProvider = Provider<ChannelConfigService>((ref) {
  return ChannelConfigService();
});
