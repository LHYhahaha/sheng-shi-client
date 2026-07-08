import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/search_repository.dart';
import 'remote/search_remote_data_source.dart';
import 'remote_search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return RemoteSearchRepository(
    remoteDataSource: SearchRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});
