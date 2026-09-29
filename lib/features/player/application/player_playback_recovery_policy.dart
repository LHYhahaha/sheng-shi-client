/// Stable categories used by playback recovery and UI error presentation.
///
/// Native-player messages are intentionally classified here rather than being
/// interpreted by widgets or individual player entry points.
enum PlayerPlaybackErrorKind {
  recoverableNetwork,
  sourceResolve,
  mediaFatal,
  unknown,
}

/// Stateless recovery decisions shared by For You and the regular player.
///
/// Timer ownership and media-session commands stay in PlayerPlaybackController;
/// this policy only answers whether a failure can be retried and how it should
/// be categorized. Keeping the policy independent makes the later recovery
/// coordinator extraction testable without a native player.
class PlayerPlaybackRecoveryPolicy {
  const PlayerPlaybackRecoveryPolicy();

  PlayerPlaybackErrorKind classifyError(String error) {
    final normalized = error.toLowerCase();
    // Explicit HTTP 4xx means source, signature, or entitlement is invalid.
    // Check it before segment matching so failed HLS segments are not treated
    // as harmless transport noise.
    if (normalized.contains('400') ||
        normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('404')) {
      return PlayerPlaybackErrorKind.sourceResolve;
    }
    if (normalized.contains('tcp') ||
        normalized.contains('ffurl') ||
        normalized.contains('segment') ||
        normalized.contains('.ts') ||
        normalized.contains('connection') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return PlayerPlaybackErrorKind.recoverableNetwork;
    }
    if (normalized.contains('source') || normalized.contains('resolve')) {
      return PlayerPlaybackErrorKind.sourceResolve;
    }
    if (normalized.contains('fatal') ||
        normalized.contains('invalid') ||
        normalized.contains('failed to open')) {
      return PlayerPlaybackErrorKind.mediaFatal;
    }
    return PlayerPlaybackErrorKind.unknown;
  }

  bool shouldAutoRetryFirstFrameTimeout({
    required bool hasAlreadyRetried,
    required bool isCurrentItem,
    required bool hasSource,
    required bool hasFirstFrame,
    required bool isPaused,
  }) {
    return !hasAlreadyRetried &&
        isCurrentItem &&
        hasSource &&
        !hasFirstFrame &&
        !isPaused;
  }
}
