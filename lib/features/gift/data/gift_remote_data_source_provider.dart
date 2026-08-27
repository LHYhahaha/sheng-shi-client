import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'remote/gift_remote_data_source.dart';

final giftRemoteDataSourceProvider = Provider<GiftRemoteDataSource>((ref) {
  return GiftRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
