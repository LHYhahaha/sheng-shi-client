import 'wallet_record.dart';

abstract interface class WalletRepository {
  Future<WalletData> fetchWallet();

  Future<List<WalletRecord>> fetchTransactionRecords({
    String? pageToken,
  });

  Future<List<WalletRecord>> fetchConsumptionRecords({
    required String status,
    String? pageToken,
  });

  Future<List<WalletRecord>> fetchRewardCoins({
    String? pageToken,
  });
}
