import 'dart:async';

import 'dto/watch_progress_dto.dart';
import 'remote/player_remote_data_source.dart';

/// 单剧观看进度的短时单飞缓存。
///
/// 普通播放器页和点击/可见预热必须读取同一 Future，避免同一次进入既请求详情又
/// 重复请求 `/api/user/watch/progress`，并确保两边使用相同的续播集与秒数。
class PlayerRemoteWatchProgressCache {
  PlayerRemoteWatchProgressCache({
    required PlayerRemoteDataSource remoteDataSource,
    this.ttl = const Duration(seconds: 12),
  }) : _remoteDataSource = remoteDataSource;

  final PlayerRemoteDataSource _remoteDataSource;
  final Duration ttl;
  final Map<int, _WatchProgressCacheEntry> _entries = {};

  Future<WatchProgressDto?> get(int dramaId) {
    final now = DateTime.now();
    final cached = _entries[dramaId];
    if (cached != null && now.difference(cached.createdAt) < ttl) {
      return cached.future;
    }
    late final Future<WatchProgressDto?> request;
    request = _remoteDataSource.fetchWatchProgress(dramaId: dramaId).catchError(
      (Object error, StackTrace stackTrace) {
        final current = _entries[dramaId];
        if (identical(current?.future, request)) {
          _entries.remove(dramaId);
        }
        return Future<WatchProgressDto?>.error(error, stackTrace);
      },
    );
    _entries[dramaId] = _WatchProgressCacheEntry(
      future: request,
      createdAt: now,
    );
    return request;
  }

  void prefetch(int dramaId) {
    unawaited(get(dramaId).then<void>((_) {}, onError: (_, _) {}));
  }
}

class _WatchProgressCacheEntry {
  const _WatchProgressCacheEntry({
    required this.future,
    required this.createdAt,
  });

  final Future<WatchProgressDto?> future;
  final DateTime createdAt;
}
