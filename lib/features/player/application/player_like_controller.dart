import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/user_library/user_library_sync_controller.dart';
import '../data/player_remote_data_source_provider.dart';
import '../data/remote/player_remote_data_source.dart';

/// 播放页点赞状态 provider，按 dramaId 隔离。
final playerLikeControllerProvider = NotifierProvider.autoDispose
    .family<PlayerLikeController, PlayerLikeState, String>(
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

  /// 当前页面最近一次接口返回的收藏数。
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

  // Notifier.build may run more than once when a dependency is refreshed.
  // This reference is reassigned on each build, so it must not be `late final`.
  late PlayerRemoteDataSource _remoteDataSource;

  @override
  PlayerLikeState build() {
    _remoteDataSource = ref.watch(playerRemoteDataSourceProvider);
    final syncedIsLiked = ref
        .read(userLibrarySyncControllerProvider)
        .favoriteFor(dramaId);
    ref.listen<UserLibrarySyncState>(userLibrarySyncControllerProvider, (
      previous,
      next,
    ) {
      final isLiked = next.favoriteFor(dramaId);
      if (isLiked != null) {
        applyExternalFavoriteState(isLiked);
      }
    });

    // 页面离开后 provider 会自动释放；这里仅接收本次登录会话内的同步操作。
    return PlayerLikeState(
      isLiked: syncedIsLiked ?? false,
      likeCountDelta: 0,
      serverFavoriteCount: null,
      isLoading: false,
      error: null,
    );
  }

  /// 用播放器接口返回的收藏快照协调状态和计数。
  ///
  /// 请求进行中时忽略列表回包，避免旧快照覆盖当前页面的乐观状态。
  void syncFeedLikeState({required bool? isLiked, required int favoriteCount}) {
    final librarySync = ref.read(userLibrarySyncControllerProvider.notifier);
    librarySync.observeFavoriteFromServer(
      dramaId: dramaId,
      isFavorited: isLiked,
    );
    isLiked =
        ref.read(userLibrarySyncControllerProvider).favoriteFor(dramaId) ??
        isLiked;
    if (state.isLoading) {
      return;
    }
    state = PlayerLikeState(
      isLiked: isLiked ?? state.isLiked,
      likeCountDelta: 0,
      serverFavoriteCount: favoriteCount,
      isLoading: false,
      error: null,
    );
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

    state = state.copyWith(
      isLiked: newIsLiked,
      likeCountDelta: newDelta,
      isLoading: true,
      error: null,
    );
    // 同步给首页、For You 等仍在监听该短剧的入口；不写入持久化缓存。
    ref
        .read(userLibrarySyncControllerProvider.notifier)
        .setFavorite(dramaId: dramaId, isFavorited: newIsLiked);
    try {
      if (currentIsLiked) {
        // 取消点赞
        await _remoteDataSource.unfollowShort(dramaId: dramaIdInt);
      } else {
        // 点赞
        await _remoteDataSource.followShort(dramaId: dramaIdInt);
      }

      // 请求成功，保留已立即呈现的状态；不写入跨页面缓存。
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // 请求失败，恢复点击前的图标与数量。
      state = PlayerLikeState(
        isLiked: currentIsLiked,
        likeCountDelta: state.likeCountDelta - (newIsLiked ? 1 : -1),
        serverFavoriteCount: state.serverFavoriteCount,
        isLoading: false,
        error: e.toString(),
      );
      // 所有入口与当前播放器同时回退。
      ref
          .read(userLibrarySyncControllerProvider.notifier)
          .setFavorite(dramaId: dramaId, isFavorited: currentIsLiked);
    }
  }

  /// 接收其它入口的收藏变更，使当前播放器的图标和数量同步更新。
  void applyExternalFavoriteState(bool isLiked) {
    if (state.isLoading || state.isLiked == isLiked) {
      return;
    }
    final nextDelta = state.serverFavoriteCount == null
        ? state.likeCountDelta
        : state.likeCountDelta + (isLiked ? 1 : -1);
    state = state.copyWith(isLiked: isLiked, likeCountDelta: nextDelta);
  }
}
