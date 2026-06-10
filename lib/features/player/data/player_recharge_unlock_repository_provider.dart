import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../../../features/pay/provider/iap_price_service_provider.dart';
import '../domain/player_recharge_unlock_repository.dart';
import 'mock_player_recharge_unlock_repository.dart';
import 'remote/player_recharge_unlock_repository_impl.dart';
import 'remote/player_remote_data_source.dart';

/// Player 充值解锁弹窗的数据入口切换开关。
///
/// 通过环境变量 `USE_REMOTE_PLAYER_API` 控制使用真实 API 还是 Mock 数据。
final useRemotePlayerRechargeApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().player;
});

final playerRechargeUnlockRepositoryProvider =
    Provider<PlayerRechargeUnlockRepository>((ref) {
  if (ref.watch(useRemotePlayerRechargeApiProvider)) {
    return PlayerRechargeUnlockRepositoryImpl(
      remoteDataSource: PlayerRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
      iapPriceService: ref.watch(iapPriceServiceProvider),
    );
  }
  return const MockPlayerRechargeUnlockRepository();
});
