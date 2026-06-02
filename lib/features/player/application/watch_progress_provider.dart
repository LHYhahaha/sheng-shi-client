import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/watch_progress_dto.dart';
import '../data/player_remote_data_source_provider.dart';

/// 获取观看进度的 provider。
final watchProgressProvider = FutureProvider.family<WatchProgressDto?, int>(
  (ref, dramaId) async {
    final dataSource = ref.read(playerRemoteDataSourceProvider);
    try {
      return await dataSource.fetchWatchProgress(dramaId: dramaId);
    } catch (e) {
      // 获取观看进度失败时返回 null，不中断播放流程
      return null;
    }
  },
);
