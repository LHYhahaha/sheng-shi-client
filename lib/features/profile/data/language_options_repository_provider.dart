import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/language_options_repository.dart';
import 'global_language_options_repository.dart';
import 'remote/global_language_remote_data_source.dart';

final languageOptionsRepositoryProvider = Provider<LanguageOptionsRepository>((
  ref,
) {
  return GlobalLanguageOptionsRepository(
    remoteDataSource: GlobalLanguageRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});
