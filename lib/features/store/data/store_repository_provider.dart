import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/store_repository.dart';
import 'mock_store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return const MockStoreRepository();
});
