import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'remote/bottom_tab_config_remote_data_source.dart';

/// 供后续动态 Tab 方案读取配置的数据源 provider。
final bottomTabConfigRemoteDataSourceProvider =
    Provider<BottomTabConfigRemoteDataSource>((ref) {
      return BottomTabConfigRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      );
    });
