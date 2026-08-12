import 'player_feed.dart';
import 'player_preload_state.dart';

/// 播放源解析状态。
///
/// `preloaded` 表示 source 已经过 HLS 预热流程，不表示已经创建 media session。
enum PlaybackSourceStatus { resolved, preloaded }

/// 播放器实际打开 source 前的业务包装。
///
/// `remoteUrl` 保留服务端原始 URL，`playableSource` 可能被 local proxy spike 改写。
/// 不要把 playableSource 写回内容模型，否则会把本地诊断链路泄漏到业务数据。
class PlaybackSource {
  const PlaybackSource({
    required this.itemId,
    required this.remoteUrl,
    required this.playableSource,
    required this.cacheKey,
    required this.expiresAt,
    required this.codecHint,
    required this.status,
    this.httpHeaders,
  });

  /// source 绑定的 feed item id。
  ///
  /// 用于防止 A item 的异步 resolve 结果落到 B item 上。
  final String itemId;

  /// 服务端或内容侧给出的原始 URL。
  ///
  /// 后续签名、过期和审计应以这个值为业务源，不受 local proxy 改写影响。
  final String remoteUrl;

  /// 播放器实际打开的 source。
  ///
  /// 可能等于 remoteUrl，也可能是 local HLS proxy URL。不要持久化这个字段到内容数据。
  final String playableSource;

  /// HTTP headers passed to the media player when opening this source.
  ///
  /// This carries the App request auth context without putting tokens in URLs.
  final Map<String, String>? httpHeaders;

  /// 播放源缓存 key。
  ///
  /// 用于未来 source/cache 复用策略，必须包含业务维度，不能只按 URL，避免签名 URL
  /// 轮换导致缓存错配。
  final String cacheKey;

  /// source 过期时间。
  ///
  /// 真实签名 URL 过期后必须重新 resolve，不能只因为 HLS preload 成功就继续复用。
  final DateTime expiresAt;

  /// 编码/封装提示。
  ///
  /// 当前为 hls，用于诊断和未来播放器策略选择，不应用作授权判断。
  final String codecHint;

  /// source 当前来自普通 resolve 还是 preload 流程。
  ///
  /// 只用于观测链路，不改变播放权限。
  final PlaybackSourceStatus status;
}

/// 播放源仓库边界。
///
/// resolve/preload 必须统一在这里进入，后续签名 URL、鉴权、缓存 key 和过期策略都会
/// 挂在这个层级。UI 直接使用 episode.videoSource 会绕过这些保护。
abstract interface class PlayerPlaybackSourceRepository {
  Future<PlaybackSource> resolve(PlayerFeedItem item);

  Future<PlaybackPreloadState> preload(
    PlayerFeedItem item, {
    Duration? preferredPosition,
  });
}

/// HLS/播放预热管理器边界。
///
/// 当前实现只预热 HTTP playlist/segment，不创建 media session；media session
/// prepare 由 PlayerPlaybackPrepareManager 负责，两个生命周期不能混用。
abstract interface class PlayerPlaybackPreloadManager {
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
    Duration? preferredPosition,
  });

  Future<void> releasePending();
}
