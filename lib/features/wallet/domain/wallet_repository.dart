import 'wallet_record.dart';

abstract interface class WalletRepository {
  Future<WalletData> fetchWallet();
}
