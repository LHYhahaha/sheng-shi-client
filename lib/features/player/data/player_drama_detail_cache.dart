import 'dart:async';

import 'dto/player_content_dto.dart';
import 'remote/player_remote_data_source.dart';

/// 播放器短剧详情的短时请求缓存。
///
/// For You 停稳后会提前请求当前剧详情；Watch Now 再进入普通播放页时复用同一个
/// Future/结果，避免重复等待详情接口。TTL 刻意保持较短，降低解锁状态变更后使用旧
/// 数据的风险。
class PlayerDramaDetailCache {
  PlayerDramaDetailCache({
    required PlayerRemoteDataSource remoteDataSource,
    this.ttl = const Duration(seconds: 30),
  }) : _remoteDataSource = remoteDataSource;

  final PlayerRemoteDataSource _remoteDataSource;
  final Duration ttl;
  final Map<int, _DramaDetailCacheEntry> _entries = {};

  Future<PlayerContentDto> get(int dramaId) {
    final now = DateTime.now();
    final cached = _entries[dramaId];
    if (cached != null && now.difference(cached.createdAt) < ttl) {
      return cached.future;
    }

    late final Future<PlayerContentDto> request;
    request = _remoteDataSource.fetchDramaDetail(dramaId: dramaId).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      final current = _entries[dramaId];
      if (identical(current?.future, request)) {
        _entries.remove(dramaId);
      }
      return Future<PlayerContentDto>.error(error, stackTrace);
    });
    _entries[dramaId] = _DramaDetailCacheEntry(future: request, createdAt: now);
    return request;
  }

  void prefetch(int dramaId) {
    unawaited(
      get(dramaId).then<void>(
        (_) {},
        // 预取失败不能影响当前 For You 播放；正式进入时会重新请求。
        onError: (_, _) {},
      ),
    );
  }

  void invalidate(int dramaId) {
    _entries.remove(dramaId);
  }
}

class _DramaDetailCacheEntry {
  const _DramaDetailCacheEntry({required this.future, required this.createdAt});

  final Future<PlayerContentDto> future;
  final DateTime createdAt;
}
