import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../data/local/player_like_cache.dart';
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
    required this.isLoading,
    required this.error,
  });

  const PlayerLikeState.initial()
    : isLiked = false,
      likeCountDelta = 0,
      isLoading = false,
      error = null;

  /// 是否已点赞。
  final bool isLiked;

  /// 点赞数相对于初始值的变化量（用于乐观更新）。
  final int likeCountDelta;

  /// 是否正在请求中。
  final bool isLoading;

  /// 错误信息。
  final String? error;

  PlayerLikeState copyWith({bool? isLiked, int? likeCountDelta, bool? isLoading, String? error}) {
    return PlayerLikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCountDelta: likeCountDelta ?? this.likeCountDelta,
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
    _remoteDataSource = PlayerRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    );

    // 先从缓存读取点赞状态，避免UI闪烁
    final cachedIsLiked = PlayerLikeCache.getCachedLikeStatus(dramaId);
    final cachedDelta = PlayerLikeCache.getCachedLikeCountDelta(dramaId);
    
    // 异步获取初始点赞状态（如果缓存中没有）
    if (cachedIsLiked == null) {
      _loadInitialLikeState();
    }

    return PlayerLikeState(
      isLiked: cachedIsLiked ?? false,
      likeCountDelta: cachedDelta,
      isLoading: false,
      error: null,
    );
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
    
    state = state.copyWith(isLiked: newIsLiked, likeCountDelta: newDelta, isLoading: true, error: null);

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
    await _loadInitialLikeState();
  }
}
