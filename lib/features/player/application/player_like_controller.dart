import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/player_like_cache.dart';
import '../data/player_remote_data_source_provider.dart';
import '../data/remote/player_remote_data_source.dart';

/// 播放页点赞状态 provider，按 dramaId 隔离。
final playerLikeControllerProvider =
    NotifierProvider.family<PlayerLikeController, PlayerLikeState, String>(
      PlayerLikeController.new,
    );

/// 点赞状态。
class PlayerLikeState {
  const PlayerLikeState({
    required this.isLiked,
    required this.likeCountDelta,
    required this.serverFavoriteCount,
    required this.isLoading,
    required this.error,
  });

  const PlayerLikeState.initial()
    : isLiked = false,
      likeCountDelta = 0,
      serverFavoriteCount = null,
      isLoading = false,
      error = null;

  /// 是否已点赞。
  final bool isLiked;

  /// 点赞数相对于初始值的变化量（用于乐观更新）。
  final int likeCountDelta;

  /// 最近一次播放器接口确认的收藏数。
  final int? serverFavoriteCount;

  /// 是否正在请求中。
  final bool isLoading;

  /// 错误信息。
  final String? error;

  PlayerLikeState copyWith({
    bool? isLiked,
    int? likeCountDelta,
    int? serverFavoriteCount,
    bool clearServerFavoriteCount = false,
    bool? isLoading,
    String? error,
  }) {
    return PlayerLikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCountDelta: likeCountDelta ?? this.likeCountDelta,
      serverFavoriteCount: clearServerFavoriteCount
          ? null
          : serverFavoriteCount ?? this.serverFavoriteCount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 点赞控制器。
class PlayerLikeController extends Notifier<PlayerLikeState> {
  PlayerLikeController(this.dramaId);

  final String dramaId;

  late final PlayerRemoteDataSource _remoteDataSource;

  @override
  PlayerLikeState build() {
    _remoteDataSource = ref.watch(playerRemoteDataSourceProvider);

    // 先从缓存读取点赞状态，避免UI闪烁
    final cachedIsLiked = PlayerLikeCache.getCachedLikeStatus(dramaId);
    final cachedDelta = PlayerLikeCache.getCachedLikeCountDelta(dramaId);

    return PlayerLikeState(
      isLiked: cachedIsLiked ?? false,
      likeCountDelta: cachedDelta,
      serverFavoriteCount: PlayerLikeCache.getCachedInitialLikeCount(dramaId),
      isLoading: false,
      error: null,
    );
  }

  /// 用播放器接口返回的收藏快照协调状态和计数。
  ///
  /// 本地点击记录优先于接口回包；只有服务端状态追上本地状态时，才接受新回包并
  /// 清除乐观计数差值，避免接口延迟期间图标或数量回退。
  void syncFeedLikeState({required bool? isLiked, required int favoriteCount}) {
    final cachedIsLiked = PlayerLikeCache.getCachedLikeStatus(dramaId);
    final cachedDelta = PlayerLikeCache.getCachedLikeCountDelta(dramaId);

    final hasCaughtUpWithLocalAction =
        isLiked != null && cachedIsLiked == isLiked && cachedDelta != 0;
    if (hasCaughtUpWithLocalAction) {
      PlayerLikeCache.setLikeCountDelta(dramaId, 0);
      PlayerLikeCache.setInitialLikeCount(dramaId, favoriteCount);
      state = state.copyWith(
        isLiked: isLiked,
        likeCountDelta: 0,
        serverFavoriteCount: favoriteCount,
      );
      return;
    }
    if (cachedDelta != 0) {
      return;
    }

    PlayerLikeCache.setInitialLikeCount(dramaId, favoriteCount);
    if (isLiked == null) {
      if (state.serverFavoriteCount != favoriteCount) {
        state = state.copyWith(serverFavoriteCount: favoriteCount);
      }
      return;
    }
    if (cachedIsLiked == null) {
      PlayerLikeCache.setLikeStatus(dramaId, isLiked);
      state = state.copyWith(
        isLiked: isLiked,
        likeCountDelta: 0,
        serverFavoriteCount: favoriteCount,
      );
      return;
    }
    if (state.serverFavoriteCount != favoriteCount) {
      state = state.copyWith(serverFavoriteCount: favoriteCount);
    }
  }

  /// 加载初始点赞状态。
  Future<void> _loadInitialLikeState() async {
    try {
      final dramaIdInt = int.tryParse(dramaId) ?? 0;
      if (dramaIdInt == 0) {
        return;
      }

      // 从服务端获取初始状态
      final isLiked = await _remoteDataSource.checkShortFollowStatus(
        dramaId: dramaIdInt,
      );

      // 更新缓存
      PlayerLikeCache.setLikeStatus(dramaId, isLiked);

      state = state.copyWith(isLiked: isLiked, likeCountDelta: 0);
    } catch (e) {
      // 静默处理错误，不影响 UI
      state = state.copyWith(error: e.toString());
    }
  }

  /// 切换点赞状态。
  Future<void> toggleLike() async {
    if (state.isLoading) {
      return;
    }

    final currentIsLiked = state.isLiked;
    final dramaIdInt = int.tryParse(dramaId) ?? 0;

    if (dramaIdInt == 0) {
      state = state.copyWith(error: 'Invalid drama ID');
      return;
    }

    // 乐观更新 UI
    final newIsLiked = !currentIsLiked;
    final newDelta = newIsLiked
        ? state.likeCountDelta + 1
        : state.likeCountDelta - 1;

    // 更新缓存
    PlayerLikeCache.setLikeStatus(dramaId, newIsLiked);
    PlayerLikeCache.updateLikeCountDelta(dramaId, newIsLiked);

    state = state.copyWith(
      isLiked: newIsLiked,
      likeCountDelta: newDelta,
      isLoading: true,
      error: null,
    );

    try {
      if (currentIsLiked) {
        // 取消点赞
        await _remoteDataSource.unfollowShort(dramaId: dramaIdInt);
      } else {
        // 点赞
        await _remoteDataSource.followShort(dramaId: dramaIdInt);
      }

      // 请求成功，保持乐观更新的状态
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // 请求失败，回滚状态
      final rollbackDelta = currentIsLiked
          ? state.likeCountDelta + 1
          : state.likeCountDelta - 1;

      // 回滚缓存
      PlayerLikeCache.setLikeStatus(dramaId, currentIsLiked);
      PlayerLikeCache.setLikeCountDelta(dramaId, rollbackDelta);

      state = state.copyWith(
        isLiked: currentIsLiked,
        likeCountDelta: rollbackDelta,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 设置初始点赞状态（从服务端获取）。
  void setInitialLikeState(bool isLiked) {
    state = state.copyWith(isLiked: isLiked);
  }

  /// 手动刷新点赞状态（用于页面重新进入时）。
  Future<void> refreshLikeStatus() async {
    if (PlayerLikeCache.getCachedLikeStatus(dramaId) != null) {
      return;
    }
    await _loadInitialLikeState();
  }
}
