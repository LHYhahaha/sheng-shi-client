class PlayerPreloadConfig {
  const PlayerPreloadConfig({
    this.homeStartupPreloadCount = 1,
    this.singleDramaForwardHlsPreloadCount = 1,
    this.singleDramaBackwardHlsPreloadCount = 1,
    this.forYouForwardHlsPreloadCount = 1,
    this.forYouBackwardHlsPreloadCount = 1,
    this.maxConcurrentHlsPreloads = 1,
    this.maxPreloadBytes = 2 * 1024 * 1024,
    this.preloadTimeout = const Duration(seconds: 4),
    this.preparedForwardSessionCount = 1,
    this.retainedBackwardSessionCount = 1,
  });

  /// Controls Home startup HLS HTTP preload count.
  ///
  /// The default is one first-screen candidate because Home must stay light and
  /// must not compete with list rendering. Increasing this consumes more
  /// network before the user explicitly plays anything. This is safe to move to
  /// remote config later if the server can account for network policy.
  final int homeStartupPreloadCount;

  /// Controls single-drama forward HLS HTTP preload count.
  ///
  /// The default is one next episode, matching the current vertical playback
  /// behavior. Increasing this can reduce future loading, but costs extra
  /// playlist/segment requests while the current episode is playing. This is a
  /// good future server/remote-config knob.
  final int singleDramaForwardHlsPreloadCount;

  /// Controls single-drama backward HLS HTTP preload count.
  ///
  /// The default is one previous episode to preserve existing swipe-back
  /// behavior. Increasing this is usually low value because retained media
  /// sessions already handle recent back-swipes, while extra HLS requests still
  /// cost bandwidth. This can be remote-configured conservatively.
  final int singleDramaBackwardHlsPreloadCount;

  /// Controls For You forward HLS HTTP preload count.
  ///
  /// The default is one next feed item because feed users mostly scroll
  /// forward. Increasing this may help fast swipes, but can quickly compete with
  /// current playback on weak networks. This is suitable for remote config only
  /// after device timing proves a benefit.
  final int forYouForwardHlsPreloadCount;

  /// Controls For You backward HLS HTTP preload count.
  ///
  /// The default is one to keep current adjacent-item behavior. Raising it is
  /// risky for feeds because users rarely scroll backward several items and the
  /// extra HTTP work may waste bandwidth. This should remain conservative in
  /// any future server-driven policy.
  final int forYouBackwardHlsPreloadCount;

  /// Controls concurrent HLS HTTP preload work, not media-session preparation.
  ///
  /// The default is one so preload cannot fan out and starve current playback.
  /// Increasing this raises bandwidth, radio, and CDN pressure. This is a
  /// remote-config candidate only with careful rollout and timing logs.
  final int maxConcurrentHlsPreloads;

  /// Controls the byte budget for HLS first-segment preheat.
  ///
  /// The default matches the existing preheater budget of 2 MiB. Increasing this
  /// can improve warm-up for large first segments, but may waste data on feeds
  /// that users skip. This should eventually be reconciled with server
  /// `preloadPolicy.maxPreloadBytes`.
  final int maxPreloadBytes;

  /// Controls HLS playlist and segment preload timeout.
  ///
  /// The default is four seconds, matching the existing preheater behavior.
  /// Increasing this may let slow sources finish preloading, but stale pending
  /// work can compete with active playback. This can be remotely tuned later.
  final Duration preloadTimeout;

  /// Controls forward media-session preparation count.
  ///
  /// The current client caps this at one prepared next session because prepared
  /// sessions hold player/decoder resources and audio-lifecycle risk. Do not
  /// increase this together with HLS preload counts without a separate device
  /// review. Remote config may expose this later, but the current effective cap
  /// remains one.
  final int preparedForwardSessionCount;

  /// Controls retained backward media-session count.
  ///
  /// The current client caps this at one retained previous session because it
  /// preserves the main swipe-back use case without building a player pool.
  /// Increasing this costs memory and decoder resources. Remote config should
  /// keep this capped until there is strong evidence.
  final int retainedBackwardSessionCount;

  int get effectiveHomeStartupPreloadCount =>
      homeStartupPreloadCount.clamp(0, 1).toInt();

  int get effectiveMaxConcurrentHlsPreloads =>
      maxConcurrentHlsPreloads.clamp(1, 1).toInt();

  int get effectiveMaxPreloadBytes =>
      maxPreloadBytes.clamp(0, 64 * 1024 * 1024).toInt();

  Duration get effectivePreloadTimeout {
    if (preloadTimeout <= Duration.zero) {
      return const Duration(seconds: 4);
    }
    return preloadTimeout;
  }

  int get effectivePreparedForwardSessionCount =>
      preparedForwardSessionCount.clamp(0, 1).toInt();

  int get effectiveRetainedBackwardSessionCount =>
      retainedBackwardSessionCount.clamp(0, 1).toInt();

  int forwardHlsPreloadCountFor(bool forYou) {
    return (forYou
            ? forYouForwardHlsPreloadCount
            : singleDramaForwardHlsPreloadCount)
        .clamp(0, 10)
        .toInt();
  }

  int backwardHlsPreloadCountFor(bool forYou) {
    return (forYou
            ? forYouBackwardHlsPreloadCount
            : singleDramaBackwardHlsPreloadCount)
        .clamp(0, 10)
        .toInt();
  }
}
