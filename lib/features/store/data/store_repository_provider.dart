import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/store_repository.dart';
import 'mock_store_repository.dart';
import 'remote/store_remote_data_source.dart';
import 'remote_store_repository.dart';

final useRemoteStoreApiProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('USE_REMOTE_STORE_API');
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  if (ref.watch(useRemoteStoreApiProvider)) {
    return RemoteStoreRepository(
      remoteDataSource: StoreRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockStoreRepository();
});
