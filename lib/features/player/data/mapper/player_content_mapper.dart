import '../../../entitlement/domain/episode_unlock_type.dart';
import '../../domain/player_content.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_dto.dart';

/// 播放详情 DTO 到 domain 的 mapper。
class PlayerContentMapper {
  const PlayerContentMapper();

  static const _displayTitleFallback = 'Untitled';

  PlayerContent mapContent(PlayerContentDto dto) {
    return PlayerContent(
      id: dto.id.toString(),
      title: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      playTitle: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      synopsis: dto.summary,
      viewCountLabel: '${dto.episodeTotal} episodes',
      likeCountLabel: '0',
      backgroundAssetPath: 'assets/images/player/player_background.png',
      posterAssetPath: 'assets/images/player/detail_cover.png',
      episodes: dto.episodes.map(mapEpisode).toList(growable: false),
      recommendations: const [],
    );
  }

  PlayerEpisode mapEpisode(PlayerEpisodeDto dto) {
    return PlayerEpisode(
      id: dto.id.toString(),
      number: dto.episodeNo,
      isLocked: false,  // 根据 isVipOnly 判断，暂时设为 false
      unlockType: EpisodeUnlockType.free,  // 根据 isVipOnly 判断，暂时设为 free
      requiredCoins: 0,
      duration: dto.durationSec > 0 ? Duration(seconds: dto.durationSec) : null,
      isAvailable: dto.status == 1,
    );
  }
}
