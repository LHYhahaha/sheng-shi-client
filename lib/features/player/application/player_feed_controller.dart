import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/player_feed_repository_provider.dart';
import '../domain/player_content.dart';
import '../domain/player_feed.dart';

/// 播放器 feed provider，按 sessionKey 隔离实例。
///
/// For You tab 和单剧 route 都会使用播放器，但它们的 index、列表和 retry 状态不能互相
/// 污染。这里使用 family 是为了让“资源播放状态”和“页面 feed 状态”都能按入口隔离。
final playerFeedControllerProvider =
    NotifierProvider.family<PlayerFeedController, PlayerFeedState, String>(
      PlayerFeedController.new,
    );

/// 播放页 feed 状态。
///
/// 同一个控制器支持单剧列表和 For You 流。它只管理 item 顺序和当前 index，
/// 不解析播放源，也不判断付费可播放；这些边界由 playback/controller 和 UI paywall
/// 处理，避免 feed 层提前触碰媒体资源。
class PlayerFeedState {
  const PlayerFeedState({
    required this.config,
    required this.items,
    required this.currentIndex,
    required this.isLoading,
    this.error,
  });

  const PlayerFeedState.initial()
    : config = null,
      items = const [],
      currentIndex = 0,
      isLoading = true,
      error = null;

  /// 当前 feed 的加载配置。
  ///
  /// retry 依赖它重新加载相同来源。null 只出现在初始状态，表示还没有确定加载单剧或
  /// For You。
  final PlayerFeedConfig? config;

  /// 当前播放器 PageView 的 item 列表。
  ///
  /// 列表顺序决定滑动方向和 preloadAround 的 previous/current/next 计算。不要在 UI
  /// 层临时排序或过滤，否则 playback window 会和页面不一致。
  final List<PlayerFeedItem> items;

  /// 当前 PageView index。
  ///
  /// 播放器页面通过它同步 PageController 和 currentItem。它只描述 feed 位置，不代表
  /// 当前 item 已经完成播放 source resolve。
  final int currentIndex;

  /// feed 是否正在加载。
  ///
  /// 只覆盖内容列表加载，不表示播放器 opening/buffering。播放器 loading 由
  /// PlayerPlaybackState 管理。
  final bool isLoading;

  /// feed 加载错误。
  ///
  /// 只表示列表/详情加载失败，不表示媒体播放失败。媒体错误在 PlayerPlaybackState。
  final Object? error;

  PlayerFeedItem? get currentItem {
    if (items.isEmpty || currentIndex >= items.length) {
      return null;
    }

    return items[currentIndex];
  }

  bool get canGoNext => currentIndex + 1 < items.length;

  PlayerFeedState copyWith({
    PlayerFeedConfig? config,
    List<PlayerFeedItem>? items,
    int? currentIndex,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return PlayerFeedState(
      config: config ?? this.config,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 播放页 feed 控制器。
///
/// `sessionKey` 让 For You tab 与单剧 route 拥有独立 feed 状态。不要复用全局 feed，
/// 否则一个页面的滑动 index 会影响另一个播放器实例。
class PlayerFeedController extends Notifier<PlayerFeedState> {
  PlayerFeedController(this.sessionKey);

  final String sessionKey;
  int _generation = 0;

  @override
  PlayerFeedState build() => const PlayerFeedState.initial();

  Future<void> load(PlayerFeedConfig config) async {
    final generation = ++_generation;
    state = state.copyWith(
      config: config,
      items: const [],
      currentIndex: 0,
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(playerFeedRepositoryProvider);
      final items = switch (config.mode) {
        PlayerFeedMode.singleDrama => repository.listSingleDramaFeed(
          dramaId: "27",
          // config.dramaId!,
          episodeId: config.episodeId!,
        ),
        PlayerFeedMode.forYou => repository.listForYouFeed(),
      };
      final loadedItems = await items;
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: List<PlayerFeedItem>.unmodifiable(loadedItems),
        currentIndex: 0,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: const [],
        currentIndex: 0,
        isLoading: false,
        error: error,
      );
    }
  }

  Future<void> retry() async {
    final config = state.config;
    if (config == null) {
      return;
    }

    await load(config);
  }

  void setCurrentIndex(int index) {
    if (index < 0 ||
        index >= state.items.length ||
        index == state.currentIndex) {
      return;
    }

    state = state.copyWith(currentIndex: index);
  }

  void goNext() {
    if (!state.canGoNext) {
      return;
    }

    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  int selectEpisode(PlayerEpisode episode) {
    final currentItem = state.currentItem;
    if (currentItem == null) {
      return state.currentIndex;
    }

    final matchingIndex = state.items.indexWhere((item) {
      return item.content.id == currentItem.content.id &&
          item.episode.id == episode.id;
    });

    if (matchingIndex != -1) {
      state = state.copyWith(currentIndex: matchingIndex);
      return matchingIndex;
    }

    // 如果选集不在当前 feed 中，用当前 item 替换 episode 而不是重建整个列表。
    // 这保留页面上下文和 PageView 位置，后续播放源仍由 playback controller 重新解析。
    final updatedItems = [...state.items];
    updatedItems[state.currentIndex] = currentItem.copyWith(episode: episode);
    state = state.copyWith(
      items: List<PlayerFeedItem>.unmodifiable(updatedItems),
    );
    return state.currentIndex;
  }

  bool _isCurrent(int generation) => generation == _generation;
}
