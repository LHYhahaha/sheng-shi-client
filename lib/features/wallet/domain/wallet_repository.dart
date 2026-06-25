import 'wallet_record.dart';

class WalletRecordPage {
  const WalletRecordPage({required this.items, required this.nextPageToken});

  final List<WalletRecord> items;
  final String? nextPageToken;
}

abstract interface class WalletRepository {
  Future<WalletData> fetchWallet();

  Future<WalletRecordPage> fetchTransactionRecords({
    String? pageToken,
  });

  Future<WalletRecordPage> fetchConsumptionRecords({
    required String status,
    String? pageToken,
  });

  Future<WalletRecordPage> fetchRewardCoins({
    String? pageToken,
  });
}
