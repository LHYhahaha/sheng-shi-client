import '../../drama/domain/drama_trial.dart';
import '../../entitlement/domain/episode_unlock_type.dart';
import '../../drama/domain/drama_watch_progress.dart';
import 'player_subtitle.dart';

/// 推荐列表加载状态。
enum PlayerRecommendationLoadStatus {
  /// 初始状态（尚未开始加载）。
  initial,

  /// 正在加载中。
  loading,

  /// 加载成功。
  loaded,

  /// 加载失败。
  error,
}

/// 播放器剧集内容模型。
///
/// 这是播放页 chrome 和详情弹层共用的数据，不等同于首页 Drama 卡片。这里可以包含
/// episodes/recommendations，但仍不代表当前 episode 已授权播放。
class PlayerContent {
  const PlayerContent({
    required this.id,
    required this.title,
    required this.playTitle,
    required this.synopsis,
    required this.viewCountLabel,
    required this.likeCountLabel,
    required this.backgroundAssetPath,
    required this.posterAssetPath,
    this.coverUrl,
    required this.episodes,
    required this.recommendations,
    this.tags = const [],
    this.playCount = 0,
    this.favoriteCount = 0,
    this.isFavorited,
    this.likeCountDelta = 0,
    this.episodeTotal = 0,
    this.watchProgress,
    this.trial,
    this.isDramaAvailable = true,
    this.recommendationsStatus = PlayerRecommendationLoadStatus.loaded,
  });

  /// 剧内容 id。
  ///
  /// 用于详情、推荐和播放 feed 关联，不要用展示标题做业务关联。
  final String id;

  /// 剧名展示文案。
  ///
  /// 只用于 UI 展示；内容多语言接入后应由内容接口返回对应语言。
  final String title;

  /// 播放页标题展示文案。
  ///
  /// 可以和 `title` 不同，用于播放器 chrome 的短标题或营销标题。
  final String playTitle;

  /// 剧情简介。
  ///
  /// 只用于详情弹层展示，不参与推荐或播放权限判断。
  final String synopsis;

  /// 播放量展示文案。
  ///
  /// 已经是格式化后的 label，UI 不应再解析其中数字做排序或统计。
  final String viewCountLabel;

  /// 点赞量展示文案。
  ///
  /// 与播放量一样是展示 label，真实埋点/互动计数应走单独接口。
  final String likeCountLabel;

  /// 播放页背景图 asset 路径。
  ///
  /// 当前是本地 mock asset；远程图接入时应在 repository 层转换为可渲染资源。
  final String backgroundAssetPath;

  /// 播放页海报图 asset 路径。
  ///
  /// 用于首帧前或不可播放时的视觉占位，不代表视频源。
  final String posterAssetPath;

  /// 网络封面 URL。
  ///
  /// 优先使用此字段加载封面，如果为空则使用 [posterAssetPath]。
  final String? coverUrl;

  /// 剧集列表。
  ///
  /// 列表包含 locked/unavailable 信息；播放前仍必须经过 playback controller 判断。
  final List<PlayerEpisode> episodes;

  /// 详情页推荐列表。
  ///
  /// 推荐项只用于展示/跳转，不应直接加入当前播放 feed 或预热。
  final List<PlayerRecommendation> recommendations;

  /// 内容标签，仅用于播放器信息区展示。
  final List<String> tags;

  /// 推荐列表加载状态。
  ///
  /// 当推荐列表正在异步加载时，可使用此状态在 UI 中展示 loading 效果。
  final PlayerRecommendationLoadStatus recommendationsStatus;

  /// 播放量。
  ///
  /// 从服务端返回的原始播放数据。
  final int playCount;

  /// 收藏量。
  ///
  /// 从服务端返回的原始收藏数据。
  final int favoriteCount;

  /// 当前用户是否已收藏；接口未提供时为 `null`。
  final bool? isFavorited;

  /// 点赞数变化。
  ///
  /// 本地缓存的点赞数相对于初始值的变化量，用于立即更新 UI。
  final int likeCountDelta;

  /// 总集数。
  ///
  /// 从服务端返回的总集数，用于动态生成 episode tab。
  final int episodeTotal;

  /// 详情接口下发的权威续播记录；只用于普通播放器初始目标选择。
  final PlayerWatchProgress? watchProgress;

  /// 限时试看配置，仅保留接口数据，后续业务逻辑按需使用。
  final PlayerTrial? trial;

  /// 短剧整体是否上架。
  ///
  /// 详情接口的 `status != 1` 会使所有剧集进入既有 unavailable 播放态；保留
  /// 此字段用于播放器在首次进入时给出“短剧已下架”的明确提示。
  final bool isDramaAvailable;

  /// 当前剧集是否是本剧按集序最早的未解锁剧集。
  ///
  /// 金币和广告只能连续解锁，不能跳过前面的锁集。剧集列表的返回顺序并不作为
  /// 业务依据，因此按 [PlayerEpisode.number] 判断。
  bool isSequentialUnlockEligible(
    PlayerEpisode episode, {
    bool Function(String episodeId)? isEpisodeUnlocked,
  }) {
    final isUnlocked = isEpisodeUnlocked ?? (_) => false;
    if (!episode.isLocked || isUnlocked(episode.id)) {
      return false;
    }
    PlayerEpisode? firstLocked;
    for (final candidate in episodes) {
      if (!candidate.isLocked ||
          isUnlocked(candidate.id) ||
          (firstLocked != null && candidate.number >= firstLocked.number)) {
        continue;
      }
      firstLocked = candidate;
    }
    return firstLocked?.id == episode.id;
  }
}

class PlayerTrial {
  const PlayerTrial({
    required this.trialEnabled,
    required this.trialEpisodeNum,
    required this.trialDurationSec,
  });

  final bool trialEnabled;
  final int trialEpisodeNum;
  final int trialDurationSec;
}

class PlayerWatchProgress {
  const PlayerWatchProgress({
    required this.episodeId,
    required this.episodeNo,
    required this.position,
    required this.duration,
    required this.progressPercent,
  });

  final String episodeId;
  final int episodeNo;
  final Duration position;
  final Duration duration;
  final int progressPercent;

  bool get hasHistory => episodeId != '0' && position > Duration.zero;
}

/// 播放页 episode 模型。
///
/// `videoSource` 是 source hint，不是最终 playable URL。真实链路必须通过
/// PlayerPlaybackSourceRepository resolve，才能处理签名、过期和 proxy spike。
class PlayerEpisode {
  const PlayerEpisode({
    required this.id,
    required this.number,
    required this.isLocked,
    this.unlockType = EpisodeUnlockType.free,
    this.viewingEntitlementType = 'free',
    this.requiredCoins = 60,
    this.videoAssetPath,
    this.videoUrl,
    this.videoAspectRatio,
    this.duration,
    this.isAvailable = true,
    this.subtitles = const [],
    this.episodeSources = const [],
    this.adUnlock,
  });

  /// 该集可用的字幕轨道列表。
  ///
  /// 为空表示无字幕。播放器应允许关闭字幕。
  final List<PlayerSubtitle> subtitles;

  /// 已将对应语言字幕烧录进画面的视频资源。
  final List<PlayerEpisodeSource> episodeSources;

  /// 广告解锁资格；为空或不可用时，播放页不展示广告解锁入口。
  final PlayerAdUnlockOffer? adUnlock;

  /// 剧集 id。
  ///
  /// 与 content id 组合后形成 feed item id。不要只用集数 number 作为稳定 id。
  final String id;

  /// 剧集序号。
  ///
  /// 用于 UI 展示和选集排序，不用于授权或 source cache key。
  final int number;

  /// 是否被付费/会员锁定。
  ///
  /// locked episode 不能 preload/open/prepare。即使 mock 数据带 videoSource，也必须等
  /// 解锁后重新走 source resolve。
  final bool isLocked;

  /// entitlement 解锁策略。
  ///
  /// `isLocked` 只是播放器层的保护位：只要为 true，PlayerPlaybackController 就不会
  /// open/preload/prepare。`unlockType` 才描述为什么锁定以及 UI 下一步去哪。
  final EpisodeUnlockType unlockType;

  /// 当前实际观看权益来源，直接对应埋点枚举。
  ///
  /// 详情接口提供初始值；播放期间的金币或会员解锁会在本地立即更新。
  final String viewingEntitlementType;

  /// 解锁该集需要的金币数。
  ///
  /// 仅在 locked episode 上用于 entitlement unlock sheet 展示。真实价格仍应由服务端
  /// 决策返回，客户端不能用本地默认值完成扣费。
  final int requiredCoins;

  /// 本地视频 asset 路径。
  ///
  /// 当前主链路使用远端 HLS；本地 asset 仅作为兼容字段。生产 HLS preload 不应依赖它。
  final String? videoAssetPath;

  /// 远端视频 URL hint。
  ///
  /// 这是内容侧给出的原始 hint，不是播放器最终 source。最终 source 由
  /// PlayerPlaybackSourceRepository 解析。
  final String? videoUrl;

  /// 视频画幅比例。
  ///
  /// 用于播放器 fit 和 UI 适配，不参与 source 选择。
  final double? videoAspectRatio;

  /// 内容侧下发的剧集时长。
  ///
  /// HLS duration 在打开初期可能为 0 或延迟返回，短剧 seek UI 可用该字段作为
  /// metadata fallback；真实媒体 duration 大于 0 后仍应优先使用播放器返回值。
  final Duration? duration;

  /// 内容是否可用。
  ///
  /// unavailable 代表下架、缺源或地区不可用，不能 preload/open/prepare。
  final bool isAvailable;

  bool get isUnavailable => !isAvailable;

  PlayerEpisode copyWith({
    String? id,
    int? number,
    bool? isLocked,
    EpisodeUnlockType? unlockType,
    String? viewingEntitlementType,
    int? requiredCoins,
    String? videoAssetPath,
    String? videoUrl,
    double? videoAspectRatio,
    Duration? duration,
    bool? isAvailable,
    List<PlayerSubtitle>? subtitles,
    List<PlayerEpisodeSource>? episodeSources,
    PlayerAdUnlockOffer? adUnlock,
  }) {
    return PlayerEpisode(
      id: id ?? this.id,
      number: number ?? this.number,
      isLocked: isLocked ?? this.isLocked,
      unlockType: unlockType ?? this.unlockType,
      viewingEntitlementType:
          viewingEntitlementType ?? this.viewingEntitlementType,
      requiredCoins: requiredCoins ?? this.requiredCoins,
      videoAssetPath: videoAssetPath ?? this.videoAssetPath,
      videoUrl: videoUrl ?? this.videoUrl,
      videoAspectRatio: videoAspectRatio ?? this.videoAspectRatio,
      duration: duration ?? this.duration,
      isAvailable: isAvailable ?? this.isAvailable,
      subtitles: subtitles ?? this.subtitles,
      episodeSources: episodeSources ?? this.episodeSources,
      adUnlock: adUnlock ?? this.adUnlock,
    );
  }

  String? get videoSource {
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      return videoUrl;
    }
    if (videoAssetPath != null && videoAssetPath!.isNotEmpty) {
      return 'asset:///$videoAssetPath';
    }
    return null;
  }
}

/// 由剧集详情接口下发的广告解锁展示与播放配置。
class PlayerAdUnlockOffer {
  const PlayerAdUnlockOffer({
    required this.isAvailable,
    required this.watchedToday,
    required this.dailyLimit,
    required this.closeAfter,
    this.placementId,
    this.adVideoUrl,
    this.taskToken,
  });

  final bool isAvailable;
  final int watchedToday;
  final int dailyLimit;
  final Duration closeAfter;
  final String? placementId;
  final String? adVideoUrl;
  final String? taskToken;
}

/// 播放详情页推荐项。
///
/// 推荐只用于展示和跳转，不应该被 preload/open；真正播放仍要重新进入 feed/source 链路。
class PlayerRecommendation {
  const PlayerRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverAssetPath,
    this.watchProgress,
    this.trial,
  });

  /// 推荐剧 id。
  ///
  /// 点击后应重新进入详情/feed 链路，不直接复用当前 content。
  final String id;

  /// 推荐标题。
  final String title;

  /// 推荐副标题或标签。
  final String subtitle;

  /// 推荐封面 asset 路径。
  final String coverAssetPath;
  final DramaWatchProgress? watchProgress;
  final DramaTrial? trial;
}

/// 播放内容仓库边界。
///
/// 负责剧集详情、选集和推荐内容，不负责 media session。不要在仓库实现里创建播放器。
abstract interface class PlayerContentRepository {
  /// 获取短剧详情（包含所有集数和字幕信息）。
  Future<PlayerContent> getPlayerContent({required String dramaId});
}
