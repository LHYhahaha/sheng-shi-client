import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/iap_price_service.dart';

/// IAP 价格查询服务 Provider
///
/// 提供公共的 IAP 价格查询功能，Store 和 Membership 页面都可以使用。
final iapPriceServiceProvider = Provider<IapPriceService>((ref) {
  final service = IapPriceService();
  
  // 清理资源
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
