import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/player_feed_repository_provider.dart';
import '../data/local/player_episode_unlock_cache.dart';
import '../domain/player_content.dart';
import '../domain/player_feed.dart';
import '../../entitlement/domain/episode_unlock_type.dart';

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
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextPage = 2,
    this.error,
    this.loadMoreError,
  });

  const PlayerFeedState.initial()
    : config = null,
      items = const [],
      currentIndex = 0,
      isLoading = true,
      isLoadingMore = false,
      hasMore = false,
      nextPage = 2,
      error = null,
      loadMoreError = null;

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

  /// For You 是否正在追加下一页。
  final bool isLoadingMore;

  /// For You 服务端是否还有下一页。
  final bool hasMore;

  /// 下一次追加请求使用的页码。
  final int nextPage;

  /// feed 加载错误。
  ///
  /// 只表示列表/详情加载失败，不表示媒体播放失败。媒体错误在 PlayerPlaybackState。
  final Object? error;

  /// 追加分页失败不会清空已经可播放的列表，错误单独保存在这里。
  final Object? loadMoreError;

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
    bool? isLoadingMore,
    bool? hasMore,
    int? nextPage,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return PlayerFeedState(
      config: config ?? this.config,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      error: clearError ? null : error ?? this.error,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
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
      isLoadingMore: false,
      hasMore: false,
      nextPage: 2,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final repository = ref.read(playerFeedRepositoryProvider);
      final pagedRepository = repository is PagedForYouFeedRepository
          ? repository as PagedForYouFeedRepository
          : null;
      final PlayerFeedPage? forYouPage;
      final List<PlayerFeedItem> loadedItems;
      if (config.mode == PlayerFeedMode.forYou && pagedRepository != null) {
        forYouPage = await pagedRepository.listForYouFeedPage(page: 1);
        loadedItems = forYouPage.items;
      } else {
        forYouPage = null;
        loadedItems = await switch (config.mode) {
          PlayerFeedMode.singleDrama => repository.listSingleDramaFeed(
            dramaId: config.dramaId!,
            episodeId: config.episodeId!,
          ),
          PlayerFeedMode.forYou => repository.listForYouFeed(),
        };
      }
      if (!_isCurrent(generation)) {
        return;
      }
      final initialIndex = _episodeIndex(loadedItems, config.episodeId);

      state = state.copyWith(
        items: List<PlayerFeedItem>.unmodifiable(loadedItems),
        currentIndex: initialIndex,
        isLoading: false,
        hasMore: forYouPage?.hasMore ?? false,
        nextPage: (forYouPage?.page ?? 1) + 1,
        clearError: true,
        clearLoadMoreError: true,
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

  /// 在 For You 到达列表末尾后追加下一页。
  ///
  /// 已有列表始终保留；重复触发、无下一页、非 For You 或仓库不支持分页时直接返回。
  Future<void> loadMore() async {
    final config = state.config;
    final repository = ref.read(playerFeedRepositoryProvider);
    final pagedRepository = repository is PagedForYouFeedRepository
        ? repository as PagedForYouFeedRepository
        : null;
    if (config?.mode != PlayerFeedMode.forYou ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        pagedRepository == null) {
      return;
    }

    final generation = _generation;
    final requestedPage = state.nextPage;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final page = await pagedRepository.listForYouFeedPage(
        page: requestedPage,
      );
      if (!_isCurrent(generation)) {
        return;
      }

      final knownIds = state.items.map((item) => item.id).toSet();
      final newItems = page.items
          .where((item) => knownIds.add(item.id))
          .toList(growable: false);
      state = state.copyWith(
        items: List<PlayerFeedItem>.unmodifiable([...state.items, ...newItems]),
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextPage: page.page + 1,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(isLoadingMore: false, loadMoreError: error);
    }
  }

  Future<void> retry() async {
    final config = state.config;
    if (config == null) {
      return;
    }

    await load(config);
  }

  Future<PlayerFeedItem?> refreshCurrentDramaAtEpisode({
    required String episodeId,
  }) async {
    final config = state.config;
    final currentItem = state.currentItem;
    final dramaId = config?.dramaId ?? currentItem?.content.id;
    if (dramaId == null || dramaId.isEmpty) {
      return currentItem;
    }

    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(playerFeedRepositoryProvider);
      final loadedItems = await repository.listSingleDramaFeed(
        dramaId: dramaId,
        episodeId: episodeId,
      );
      if (!_isCurrent(generation)) {
        return state.currentItem;
      }
      final refreshedIndex = _episodeIndex(loadedItems, episodeId);

      state = state.copyWith(
        config: PlayerFeedConfig.singleDrama(
          dramaId: dramaId,
          episodeId: episodeId,
        ),
        items: List<PlayerFeedItem>.unmodifiable(loadedItems),
        currentIndex: refreshedIndex,
        isLoading: false,
        clearError: true,
      );
      return state.currentItem;
    } catch (error) {
      if (!_isCurrent(generation)) {
        return state.currentItem;
      }

      state = state.copyWith(isLoading: false, error: error);
      return state.currentItem;
    }
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

  /// 更新推荐流中的指定 item 当前剧集，同时保留推荐列表顺序和 PageView index。
  PlayerFeedItem? updateItemEpisode({
    required String itemId,
    required PlayerEpisode episode,
  }) {
    final itemIndex = state.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      return null;
    }
    final updatedItems = [...state.items];
    final updatedItem = updatedItems[itemIndex].copyWith(episode: episode);
    updatedItems[itemIndex] = updatedItem;
    state = state.copyWith(
      items: List<PlayerFeedItem>.unmodifiable(updatedItems),
    );
    return updatedItem;
  }

  /// 更新指定剧集的播放地址。
  ///
  /// 在金币解锁成功后调用，将服务端返回的 sourceUrl 写入对应的 episode，
  /// 以便播放器可以立即播放解锁后的剧集。
  ///
  /// [dramaId] 剧目ID
  /// [episodeId] 剧集ID
  /// [sourceUrl] 播放地址
  /// 返回是否成功更新
  bool updateEpisodeVideoUrl({
    required String dramaId,
    required String episodeId,
    required String sourceUrl,
  }) {
    final itemIndex = state.items.indexWhere((item) {
      return item.content.id == dramaId && item.episode.id == episodeId;
    });

    if (itemIndex == -1) {
      debugPrint(
        '[PlayerFeed] 未找到对应的剧集: dramaId=$dramaId, episodeId=$episodeId',
      );
      return false;
    }

    final item = state.items[itemIndex];
    final updatedEpisode = PlayerEpisode(
      id: item.episode.id,
      number: item.episode.number,
      isLocked: false, // 解锁后不再锁定
      unlockType: EpisodeUnlockType.free, // 解锁后变为免费
      requiredCoins: item.episode.requiredCoins,
      videoUrl: sourceUrl, // 更新播放地址
      videoAssetPath: item.episode.videoAssetPath,
      videoAspectRatio: item.episode.videoAspectRatio,
      duration: item.episode.duration,
      isAvailable: item.episode.isAvailable,
      subtitles: item.episode.subtitles,
    );

    final updatedItems = [...state.items];
    updatedItems[itemIndex] = item.copyWith(episode: updatedEpisode);
    state = state.copyWith(
      items: List<PlayerFeedItem>.unmodifiable(updatedItems),
    );

    // 更新解锁状态缓存，避免UI闪烁
    PlayerEpisodeUnlockCache.setUnlockStatus(dramaId, episodeId, true);

    debugPrint(
      '[PlayerFeed] 已更新剧集播放地址: dramaId=$dramaId, '
      'episodeId=$episodeId, sourceUrl=$sourceUrl',
    );
    return true;
  }

  bool _isCurrent(int generation) => generation == _generation;

  int _episodeIndex(List<PlayerFeedItem> items, String? episodeId) {
    if (episodeId == null || episodeId.isEmpty || items.isEmpty) {
      return 0;
    }
    final requestedNumber = int.tryParse(episodeId);
    final index = items.indexWhere((item) {
      return item.episode.id == episodeId ||
          item.episode.number == requestedNumber;
    });
    return index == -1 ? 0 : index;
  }
}
