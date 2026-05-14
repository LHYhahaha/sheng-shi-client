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

  /// 控制首页启动阶段的 HLS HTTP 预加载数量。
  ///
  /// 默认只预加载首屏 1 个候选，因为首页需要保持轻量，不能和列表渲染抢资源。
  /// 调大后会在用户明确点击播放前消耗更多网络。未来如果服务端能结合网络策略控制，
  /// 这个字段可以作为远程配置下发。
  final int homeStartupPreloadCount;

  /// 控制单剧播放页向后预加载的 HLS HTTP 数量。
  ///
  /// 默认预加载下一集 1 个，和当前上下滑播放行为一致。调大后可能减少后续加载等待，
  /// 但会在当前剧集播放时增加 playlist/segment 请求。这个字段适合未来作为服务端
  /// 或远程配置的调优项。
  final int singleDramaForwardHlsPreloadCount;

  /// 控制单剧播放页向前预加载的 HLS HTTP 数量。
  ///
  /// 默认预加载上一集 1 个，用来保持现有回滑体验。继续调大通常收益不高，因为最近
  /// 回滑主要由 retained media session 处理，而额外 HLS 请求仍然会消耗带宽。
  /// 如果未来远程配置这个字段，也应该保持保守。
  final int singleDramaBackwardHlsPreloadCount;

  /// 控制 For You 信息流向后预加载的 HLS HTTP 数量。
  ///
  /// 默认预加载下一个 feed item 1 个，因为信息流用户大多向下滑。调大后可能改善
  /// 快速连续滑动，但在弱网下也更容易和当前播放抢带宽。只有真机 timing 证明有收益后，
  /// 才适合作为远程配置逐步放开。
  final int forYouForwardHlsPreloadCount;

  /// 控制 For You 信息流向前预加载的 HLS HTTP 数量。
  ///
  /// 默认保留 1 个，用来维持当前相邻 item 行为。信息流用户很少连续向上回看多个 item，
  /// 所以调大容易浪费带宽。未来即使由服务端策略驱动，也应保持保守。
  final int forYouBackwardHlsPreloadCount;

  /// 控制并发 HLS HTTP 预加载任务数，不控制 media-session prepare。
  ///
  /// 默认锁定为 1，避免预加载并发扩散后抢占当前播放。调大会增加带宽、无线网络和 CDN
  /// 压力。未来如果要远程配置，必须配合灰度和 timing 日志。
  final int maxConcurrentHlsPreloads;

  /// 控制 HLS 首段预热的字节预算。
  ///
  /// 默认沿用现有预热预算 2 MiB。调大可能改善大首段视频的预热效果，但在用户快速滑走
  /// 的信息流里也可能浪费流量。后续应和服务端 `preloadPolicy.maxPreloadBytes` 对齐。
  final int maxPreloadBytes;

  /// 控制 HLS playlist 和 segment 预加载超时时间。
  ///
  /// 默认 4 秒，和现有 HLS preheater 行为一致。调大可能让慢源完成预加载，但过期的
  /// pending 任务也会更久地占用网络资源。后续可以远程调优。
  final Duration preloadTimeout;

  /// 控制向后 media-session prepare 数量。
  ///
  /// 当前客户端有效上限为 1 个 next prepared session，因为 prepared session 会持有播放器、
  /// 解码资源，并带来音频生命周期风险。不要因为 HLS preload 数量变大就同步调大这个字段。
  /// 未来可以暴露给远程配置，但当前有效 cap 仍然是 1。
  final int preparedForwardSessionCount;

  /// 控制向前 retained media-session 数量。
  ///
  /// 当前客户端有效上限为 1 个 previous retained session，用来覆盖主要回滑场景，同时
  /// 避免形成播放器实例池。调大会增加内存和解码资源占用。除非有强真机证据，远程配置
  /// 也应保持这个 cap。
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
