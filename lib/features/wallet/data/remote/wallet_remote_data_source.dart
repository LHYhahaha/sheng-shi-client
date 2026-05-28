import '../../../../core/network/api_client.dart';
import '../dto/wallet_consumption_record_dto.dart';
import '../dto/wallet_dto.dart';
import '../dto/wallet_page_dto.dart';
import '../dto/wallet_reward_coin_record_dto.dart';
import '../dto/wallet_setting_dto.dart';
import '../dto/wallet_transaction_record_dto.dart';

/// 钱包远程数据源骨架。
///
/// 钱包余额、流水、奖励和自动解锁设置都是登录后数据，统一使用 required auth policy。
class WalletRemoteDataSource {
  const WalletRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<WalletDto> getWallet() {
    return _apiClient.get<WalletDto>(
      '/api/payment/wallet',
      authPolicy: ApiAuthPolicy.required,
      decoder: WalletDto.fromJson,
    );
  }

  Future<WalletPageDto<WalletTransactionRecordDto>> listTransactions({
    String? pageToken,
  }) {
    return _apiClient.get<WalletPageDto<WalletTransactionRecordDto>>(
      '/api/payment/recharge/records',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) =>
          WalletPageDto.fromJson(data, WalletTransactionRecordDto.fromJson),
    );
  }

  Future<WalletPageDto<WalletConsumptionRecordDto>> listConsumptionRecords({
    required String status,
    String? pageToken,
  }) {
    return _apiClient.get<WalletPageDto<WalletConsumptionRecordDto>>(
      '/api/payment/coin/consume-records',
      queryParameters: <String, Object?>{
        'pageToken': pageToken,
      }..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) =>
          WalletPageDto.fromJson(data, WalletConsumptionRecordDto.fromJson),
    );
  }

  Future<WalletPageDto<WalletRewardCoinRecordDto>> listRewardCoins({
    String? pageToken,
  }) {
    return _apiClient.get<WalletPageDto<WalletRewardCoinRecordDto>>(
      '/api/payment/bonus-coin/records',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) =>
          WalletPageDto.fromJson(data, WalletRewardCoinRecordDto.fromJson),
    );
  }

  Future<WalletRewardCoinRecordDto> claimRewardCoin({required String id}) {
    return _apiClient.post<WalletRewardCoinRecordDto>(
      '/wallet/reward-coins/$id/claim',
      authPolicy: ApiAuthPolicy.required,
      decoder: WalletRewardCoinRecordDto.fromJson,
    );
  }

  Future<WalletSettingDto> setAutoUnlockEnabled({required bool enabled}) {
    return _apiClient.patch<WalletSettingDto>(
      '/entitlements/settings/auto-unlock',
      data: {'autoUnlockEnabled': enabled},
      authPolicy: ApiAuthPolicy.required,
      decoder: WalletSettingDto.fromJson,
    );
  }
}
