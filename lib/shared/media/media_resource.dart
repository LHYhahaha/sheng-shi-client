/// 媒体资源来源类型。
///
/// 这里只描述资源身份，不负责缓存、占位图、错误图或加载策略。具体如何渲染由 UI 组件
/// 决定，避免把 Flutter Widget 或图片缓存实现带进 domain/data 层。
enum MediaResourceType {
  /// 本地打包 asset。
  asset,

  /// 远端网络资源。
  network,
}

/// 轻量媒体资源描述。
///
/// Phase A 先用于图片资源，后续可逐步迁移 poster、avatar、preview 等字段。这个模型
/// 不代表播放器视频源，视频播放仍走 PlayerPlaybackSourceRepository。
class MediaResource {
  const MediaResource._({
    required this.type,
    required this.value,
    this.aspectRatio,
  });

  /// 本地 asset 资源。
  const MediaResource.asset(String path, {double? aspectRatio})
    : this._(
        type: MediaResourceType.asset,
        value: path,
        aspectRatio: aspectRatio,
      );

  /// 远端网络资源。
  const MediaResource.network(String url, {double? aspectRatio})
    : this._(
        type: MediaResourceType.network,
        value: url,
        aspectRatio: aspectRatio,
      );

  /// 资源来源类型。
  final MediaResourceType type;

  /// 资源值。
  ///
  /// asset 类型时是 asset path；network 类型时是 URL。调用方必须先看 type，不能假设
  /// value 一定可以交给 Image.asset。
  final String value;

  /// 可选画幅比例。
  ///
  /// 用于列表布局预留尺寸，不参与图片缓存或 CDN 策略。
  final double? aspectRatio;

  bool get isAsset => type == MediaResourceType.asset;

  bool get isNetwork => type == MediaResourceType.network;
}
