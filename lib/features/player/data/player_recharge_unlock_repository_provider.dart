import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../features/pay/provider/iap_price_service_provider.dart';
import '../domain/player_recharge_unlock_repository.dart';
import 'remote/player_recharge_unlock_repository_impl.dart';
import 'remote/player_remote_data_source.dart';

/// Player recharge unlock repository always uses the remote API.
final playerRechargeUnlockRepositoryProvider =
    Provider<PlayerRechargeUnlockRepository>((ref) {
  return PlayerRechargeUnlockRepositoryImpl(
    remoteDataSource: PlayerRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
    iapPriceService: ref.watch(iapPriceServiceProvider),
  );
});
