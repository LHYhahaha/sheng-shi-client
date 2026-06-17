import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import '../data/remote/pay_remote_data_source.dart';
import '../data/repository/remote_pay_repository.dart';
import '../data/repository/mock_pay_repository.dart';
import '../domain/pay_repository.dart';

/// 支付远程数据源Provider
final payRemoteDataSourceProvider = Provider<PayRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PayRemoteDataSource(apiClient: apiClient);
});

/// 支付仓库Provider
///
/// 根据环境选择远程或模拟实现
final payRepositoryProvider = Provider<PayRepository>((ref) {
  // TODO: 根据环境配置选择实现，当前默认使用远程实现
  final remoteDataSource = ref.watch(payRemoteDataSourceProvider);
  return RemotePayRepository(remoteDataSource: remoteDataSource);
});
