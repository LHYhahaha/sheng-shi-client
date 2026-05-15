import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/wallet_repository.dart';
import 'mock_wallet_repository.dart';
import 'remote/wallet_remote_data_source.dart';
import 'remote_wallet_repository.dart';

/// Wallet remote skeleton 开关。
///
/// 默认保持 mock，避免商业链路远程骨架影响已验收的充值/钱包 MVP。
final useRemoteWalletApiProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('USE_REMOTE_WALLET_API');
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  if (ref.watch(useRemoteWalletApiProvider)) {
    return RemoteWalletRepository(
      remoteDataSource: WalletRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockWalletRepository();
});
