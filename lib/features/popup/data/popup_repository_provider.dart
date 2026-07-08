import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'popup_repository.dart';
import 'remote/popup_remote_data_source.dart';
import 'remote_popup_repository.dart';

final popupRepositoryProvider = Provider<PopupRepository>((ref) {
  return RemotePopupRepository(
    remoteDataSource: PopupRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});
