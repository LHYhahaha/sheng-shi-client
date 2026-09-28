import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_feed.dart';
import 'playback_experience_state.dart';
import 'player_feed_controller.dart';
import 'player_playback_controller.dart';
import 'player_viewport_controller.dart';

/// Coordinates the desired playback target for one session without owning a
/// media-kit player. Media commands remain with the runtime/playback layers.
final playbackExperienceCoordinatorProvider =
    NotifierProvider.family<
      PlaybackExperienceCoordinator,
      PlaybackExperienceState,
      String
    >(PlaybackExperienceCoordinator.new);

class PlaybackExperienceCoordinator extends Notifier<PlaybackExperienceState> {
  PlaybackExperienceCoordinator(this.sessionKey);

  final String sessionKey;
  Future<void> _operation = Future<void>.value();

  @override
  PlaybackExperienceState build() => const PlaybackExperienceState();

  void setVisibility(PlaybackExperienceVisibility visibility) {
    if (state.visibility == visibility) {
      return;
    }
    state = state.copyWith(visibility: visibility);
  }

  /// Establishes the canonical initial viewport target for a visible For You
  /// feed. The existing viewport listener remains responsible for dispatching
  /// entitlement and playback until its migration in the next phase.
  Future<void> synchronize() {
    final next = _operation.then<void>(
      (_) => _synchronizeNow(),
      onError: (_, _) => _synchronizeNow(),
    );
    _operation = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<void> _synchronizeNow() async {
    if (!ref.mounted ||
        sessionKey != PlayerPlaybackSessionKeys.forYouTab ||
        state.visibility != PlaybackExperienceVisibility.visible) {
      return;
    }
    final feed = ref.read(playerFeedControllerProvider(sessionKey));
    final item = feed.currentItem;
    if (item == null) {
      return;
    }
    final target = PlaybackExperienceTarget(
      itemId: item.id,
      episodeId: item.episode.id,
      feedRevision: feed.revision,
    );
    if (state.target != target) {
      state = state.copyWith(
        target: target,
        health: PlaybackExperienceHealth.idle,
        commandGeneration: state.commandGeneration + 1,
      );
    }

    final viewport = ref.read(playerViewportControllerProvider(sessionKey));
    if (viewport.settledIndex == feed.currentIndex &&
        viewport.settledItemId == item.id) {
      return;
    }
    ref
        .read(playerViewportControllerProvider(sessionKey).notifier)
        .initialize(index: feed.currentIndex, itemId: item.id);
  }

  /// Rejects a settled callback from an earlier feed replacement or a target
  /// that has been superseded by a more recent visible item.
  Future<void> onViewportSettled({
    required PlayerFeedItem item,
    required int index,
    required int feedRevision,
  }) async {
    final target = state.target;
    if (target == null ||
        target.itemId != item.id ||
        target.episodeId != item.episode.id ||
        target.feedRevision != feedRevision) {
      return;
    }
    final feed = ref.read(playerFeedControllerProvider(sessionKey));
    if (feed.revision != feedRevision ||
        feed.currentIndex != index ||
        feed.currentItem?.id != item.id) {
      return;
    }
    state = state.copyWith(health: PlaybackExperienceHealth.opening);
  }
}
