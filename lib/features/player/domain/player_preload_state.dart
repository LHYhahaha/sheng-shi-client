enum PlaybackPreloadStatus { pending, success, failed, cancelled }

class PlaybackPreloadState {
  const PlaybackPreloadState({
    required this.itemId,
    required this.sourceUrl,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
    this.details,
  });

  final String itemId;
  final String sourceUrl;
  final PlaybackPreloadStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Object? error;
  final String? details;

  PlaybackPreloadState copyWith({
    PlaybackPreloadStatus? status,
    DateTime? completedAt,
    Object? error,
    String? details,
    bool clearError = false,
    bool clearDetails = false,
  }) {
    return PlaybackPreloadState(
      itemId: itemId,
      sourceUrl: sourceUrl,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: clearError ? null : error ?? this.error,
      details: clearDetails ? null : details ?? this.details,
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
