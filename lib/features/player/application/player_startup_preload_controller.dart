import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/domain/drama.dart';
import '../data/player_feed_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../data/player_preload_config_provider.dart';
import '../domain/player_feed.dart';
import '../domain/player_preload_state.dart';
import 'player_playback_timing_trace.dart';

final playerStartupPreloadControllerProvider =
    NotifierProvider<PlayerStartupPreloadController, PlayerStartupPreloadState>(
      PlayerStartupPreloadController.new,
    );

enum PlayerStartupPreloadStatus { idle, pending, success, failed, cancelled }

class PlayerStartupPreloadState {
  const PlayerStartupPreloadState({
    required this.status,
    this.itemId,
    this.sourceUrl,
    this.startedAt,
    this.completedAt,
    this.error,
    this.details,
  });

  const PlayerStartupPreloadState.idle()
    : status = PlayerStartupPreloadStatus.idle,
      itemId = null,
      sourceUrl = null,
      startedAt = null,
      completedAt = null,
      error = null,
      details = null;

  final PlayerStartupPreloadStatus status;
  final String? itemId;
  final String? sourceUrl;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Object? error;
  final String? details;

  bool matches(PlayerFeedItem item) {
    final source = item.episode.videoSource;
    if (source == null) {
      return false;
    }
    return status == PlayerStartupPreloadStatus.success &&
        itemId == item.id &&
        sourceUrl == source;
  }
}

class PlayerStartupPreloadController
    extends Notifier<PlayerStartupPreloadState> {
  int _generation = 0;
  late final PlayerPlaybackTimingTrace _timingTrace;

  @override
  PlayerStartupPreloadState build() {
    _timingTrace = PlayerPlaybackTimingTrace(sessionKey: 'startup-preload');
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    ref.onDispose(() {
      _generation += 1;
      unawaited(preloadManager.releasePending());
    });
    return const PlayerStartupPreloadState.idle();
  }

  List<PlayerPlaybackTimingEvent> get timingEvents => _timingTrace.events;

  String exportTimingReport() {
    return _timingTrace.exportReport();
  }

  Future<void> preloadFirstPlayableDrama(Drama? drama) async {
    final config = ref.read(playerPreloadConfigProvider);
    if (config.effectiveHomeStartupPreloadCount <= 0) {
      await cancel(reason: 'startup_preload_disabled');
      return;
    }

    if (drama == null) {
      await cancel(reason: 'no candidate');
      return;
    }

    final generation = ++_generation;
    _record(
      'startup preload request',
      itemId: drama.id,
      details: 'dramaId=${drama.id}',
    );
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    await preloadManager.releasePending();
    if (!_isCurrent(generation)) {
      return;
    }

    try {
      final items = await ref
          .read(playerFeedRepositoryProvider)
          .listSingleDramaFeed(dramaId: drama.id, episodeId: '1');
      if (!_isCurrent(generation)) {
        return;
      }
      final item = _firstPlayableItem(items);
      if (item == null) {
        state = PlayerStartupPreloadState(
          status: PlayerStartupPreloadStatus.cancelled,
          itemId: drama.id,
          completedAt: DateTime.now(),
          details: 'reason=no_playable_item',
        );
        _record(
          'startup preload cancelled',
          itemId: drama.id,
          details: 'reason=no_playable_item',
        );
        return;
      }

      final source = item.episode.videoSource;
      final startedAt = DateTime.now();
      state = PlayerStartupPreloadState(
        status: PlayerStartupPreloadStatus.pending,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
      );
      _record(
        'startup preload start',
        itemId: item.id,
        source: source,
        details: 'dramaId=${item.content.id} episodeId=${item.episode.id}',
      );

      final preloadState = await ref
          .read(playerStartupPlaybackSourceRepositoryProvider)
          .preload(item);
      if (!_isCurrent(generation)) {
        return;
      }

      final status = switch (preloadState.status) {
        PlaybackPreloadStatus.success => PlayerStartupPreloadStatus.success,
        PlaybackPreloadStatus.failed => PlayerStartupPreloadStatus.failed,
        PlaybackPreloadStatus.cancelled => PlayerStartupPreloadStatus.cancelled,
        PlaybackPreloadStatus.pending => PlayerStartupPreloadStatus.pending,
      };
      state = PlayerStartupPreloadState(
        status: status,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: preloadState.error,
        details: preloadState.details,
      );
      _record(
        switch (status) {
          PlayerStartupPreloadStatus.success => 'startup preload success',
          PlayerStartupPreloadStatus.failed => 'startup preload failed',
          PlayerStartupPreloadStatus.cancelled => 'startup preload cancelled',
          PlayerStartupPreloadStatus.pending => 'startup preload pending',
          PlayerStartupPreloadStatus.idle => 'startup preload idle',
        },
        itemId: item.id,
        source: source,
        elapsed: DateTime.now().difference(startedAt),
        error: preloadState.error,
        details: preloadState.details,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = PlayerStartupPreloadState(
        status: PlayerStartupPreloadStatus.failed,
        itemId: drama.id,
        startedAt: state.startedAt,
        completedAt: DateTime.now(),
        error: error,
      );
      _record('startup preload failed', itemId: drama.id, error: error);
    }
  }

  Future<void> cancel({String reason = 'cancel', bool syncState = true}) async {
    final previous = state;
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    _generation += 1;
    await preloadManager.releasePending();
    if (!ref.mounted) {
      return;
    }
    if (syncState && ref.mounted) {
      state = PlayerStartupPreloadState(
        status: previous.status == PlayerStartupPreloadStatus.idle
            ? PlayerStartupPreloadStatus.idle
            : PlayerStartupPreloadStatus.cancelled,
        itemId: previous.itemId,
        sourceUrl: previous.sourceUrl,
        startedAt: previous.startedAt,
        completedAt: DateTime.now(),
        details: 'reason=$reason',
      );
    }
    _record(
      'startup preload cancelled',
      itemId: previous.itemId,
      source: previous.sourceUrl,
      details: 'reason=$reason',
    );
  }

  PlayerFeedItem? _firstPlayableItem(List<PlayerFeedItem> items) {
    for (final item in items) {
      if (!item.episode.isLocked &&
          !item.episode.isUnavailable &&
          item.episode.videoSource != null) {
        return item;
      }
    }
    return null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _record(
    String event, {
    String? itemId,
    String? source,
    Duration? elapsed,
    Object? error,
    String? details,
  }) {
    _timingTrace.record(
      event,
      itemId: itemId,
      source: source,
      elapsed: elapsed,
      error: error,
      details: details,
    );
  }
}
