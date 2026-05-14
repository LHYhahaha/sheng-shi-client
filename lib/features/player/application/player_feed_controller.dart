import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/player_feed_repository_provider.dart';
import '../domain/player_content.dart';
import '../domain/player_feed.dart';

final playerFeedControllerProvider =
    NotifierProvider.family<PlayerFeedController, PlayerFeedState, String>(
      PlayerFeedController.new,
    );

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

  final PlayerFeedConfig? config;
  final List<PlayerFeedItem> items;
  final int currentIndex;
  final bool isLoading;
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
          dramaId: config.dramaId!,
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

    final updatedItems = [...state.items];
    updatedItems[state.currentIndex] = currentItem.copyWith(episode: episode);
    state = state.copyWith(
      items: List<PlayerFeedItem>.unmodifiable(updatedItems),
    );
    return state.currentIndex;
  }

  bool _isCurrent(int generation) => generation == _generation;
}
