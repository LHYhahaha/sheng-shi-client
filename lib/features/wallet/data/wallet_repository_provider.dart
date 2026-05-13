import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet_repository.dart';
import 'mock_wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return const MockWalletRepository();
});
