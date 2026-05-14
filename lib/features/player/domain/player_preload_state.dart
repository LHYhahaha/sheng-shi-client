enum PlaybackPreloadStatus { pending, success, failed, cancelled }

class PlaybackPreloadState {
  const PlaybackPreloadState({
    required this.itemId,
    required this.sourceUrl,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
  });

  final String itemId;
  final String sourceUrl;
  final PlaybackPreloadStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Object? error;

  PlaybackPreloadState copyWith({
    PlaybackPreloadStatus? status,
    DateTime? completedAt,
    Object? error,
    bool clearError = false,
  }) {
    return PlaybackPreloadState(
      itemId: itemId,
      sourceUrl: sourceUrl,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PendingPreload {
  const PendingPreload({
    required this.itemId,
    required this.sourceUrl,
    required this.generation,
  });

  final String itemId;
  final String sourceUrl;
  final int generation;
}
