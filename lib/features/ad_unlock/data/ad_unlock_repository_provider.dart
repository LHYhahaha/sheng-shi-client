import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ad_material_preloader.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/ad_unlock_repository.dart';
import 'ad_unlock_remote_data_source.dart';
import 'file_ad_material_downloader.dart';
import 'remote_ad_unlock_repository.dart';

final adUnlockRepositoryProvider = Provider<AdUnlockRepository>((ref) {
  return RemoteAdUnlockRepository(
    dataSource: AdUnlockRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});

final adMaterialPreloaderProvider = Provider<AdMaterialPreloader>((ref) {
  return AdMaterialPreloader(
    repository: ref.watch(adUnlockRepositoryProvider),
    downloader: FileAdMaterialDownloader(),
  );
});
