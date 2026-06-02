import '../../../entitlement/domain/episode_unlock_type.dart';
import '../../domain/player_content.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_dto.dart';

/// 播放详情 DTO 到 domain 的 mapper。
class PlayerContentMapper {
  const PlayerContentMapper();

  static const _displayTitleFallback = 'Untitled';

  PlayerContent mapContent(
    PlayerContentDto dto, {
    List<PlayerRecommendation> recommendations = const [],
  }) {
    return PlayerContent(
      id: dto.id.toString(),
      title: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      playTitle: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      synopsis: dto.summary,
      viewCountLabel: _formatPlayCount(dto.playCount),
      likeCountLabel: _formatFavoriteCount(dto.favoriteCount),
      backgroundAssetPath: 'assets/images/player/player_background.png',
      posterAssetPath: 'assets/images/player/detail_cover.png',
      episodes: dto.episodes
          .map((episode) => mapEpisode(episode, pricePerEpisode: dto.pricePerEpisode))
          .toList(growable: false),
      recommendations: recommendations,
      playCount: dto.playCount,
      favoriteCount: dto.favoriteCount,
      episodeTotal: dto.episodeTotal,
    );
  }

  PlayerEpisode mapEpisode(PlayerEpisodeDto dto, {int pricePerEpisode = 0}) {
    // 根据 isVipOnly 判断解锁类型
    final unlockType = _determineUnlockType(dto);
    
    // isLocked 表示用户是否已解锁该集
    // 如果已解锁（isUnlocked == 1）或者是免费剧集，则不锁定
    final isLocked = dto.isUnlocked == 0 && unlockType != EpisodeUnlockType.free;

    return PlayerEpisode(
      id: dto.id.toString(),
      number: dto.episodeNo,
      isLocked: isLocked,
      unlockType: unlockType,
      requiredCoins: pricePerEpisode,  // 从 PlayerContentDto 的 pricePerEpisode 获取
      videoUrl: dto.sourceUrl.isNotEmpty ? dto.sourceUrl : null,
      duration: dto.durationSec > 0 ? Duration(seconds: dto.durationSec) : null,
      isAvailable: dto.status == 1,
    );
  }

  /// 根据 DTO 字段判断剧集的解锁类型。
  ///
  /// 规则：
  /// - 如果 isVipOnly == 0，则为 free（免费剧集）
  /// - 如果 isVipOnly == 1，则为 membership（需要会员或金币解锁）
  EpisodeUnlockType _determineUnlockType(PlayerEpisodeDto dto) {
    if (dto.isVipOnly == 1) {
      return EpisodeUnlockType.membership;  // 会员专属或需要金币解锁
    }

    return EpisodeUnlockType.free;  // 免费剧集
  }
}

/// 格式化播放量为展示文案。
String _formatPlayCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M Views';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K Views';
  } else {
    return '$count Views';
  }
}

/// 格式化收藏量为展示文案。
String _formatFavoriteCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else {
    return '$count';
  }
}
