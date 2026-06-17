import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../application/iap_purchase_service.dart';
import '../data/remote/pay_remote_data_source.dart';

/// IAP 购买服务 Provider
///
/// 提供统一的 IAP 购买服务，Store 和 Membership 页面都可以使用
final iapPurchaseServiceProvider = Provider<IapPurchaseService?>((ref) {
  // 正式环境或测试环境启用
  // if (kReleaseMode) {
  //   return IapPurchaseService();
  // }
  // debug 模式也启用，用于测试
  final service = IapPurchaseService();

  // 初始化远程数据源
  final apiClient = ref.watch(apiClientProvider);
  final payRemoteDataSource = PayRemoteDataSource(apiClient: apiClient);
  service.initialize(payRemoteDataSource: payRemoteDataSource);

  ref.onDispose(service.dispose);

  return service;
});
