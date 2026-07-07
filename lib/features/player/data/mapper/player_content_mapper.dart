import '../../../entitlement/domain/episode_unlock_type.dart';
import '../../../../core/utils/compact_count_formatter.dart';
import '../../domain/player_content.dart';
import '../../domain/player_subtitle.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_dto.dart';

/// 播放详情 DTO 到 domain 的 mapper。
class PlayerContentMapper {
  const PlayerContentMapper();

  static const _displayTitleFallback = 'Untitled';

  PlayerContent mapContent(
    PlayerContentDto dto, {
    List<PlayerRecommendation> recommendations = const [],
    PlayerRecommendationLoadStatus recommendationsStatus =
        PlayerRecommendationLoadStatus.loaded,
  }) {
    return PlayerContent(
      id: dto.id.toString(),
      title: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      playTitle: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      synopsis: dto.summary,
      viewCountLabel: formatCompactCount(dto.playCount),
      likeCountLabel: formatCompactCount(dto.favoriteCount),
      backgroundAssetPath: 'assets/images/player/player_background.png',
      posterAssetPath: 'assets/images/player/detail_cover.png',
      coverUrl: dto.coverUrl.isNotEmpty ? dto.coverUrl : null,
      episodes: dto.episodes
          .map(
            (episode) =>
                mapEpisode(episode, pricePerEpisode: dto.pricePerEpisode),
          )
          .toList(growable: false),
      recommendations: recommendations,
      tags: List<String>.unmodifiable(dto.tagsName),
      playCount: dto.playCount,
      favoriteCount: dto.favoriteCount,
      episodeTotal: dto.episodeTotal,
      recommendationsStatus: recommendationsStatus,
    );
  }

  PlayerEpisode mapEpisode(PlayerEpisodeDto dto, {int pricePerEpisode = 0}) {
    // 根据 isVipOnly 和 isUnlocked 判断解锁类型
    final unlockType = _determineUnlockType(dto);

    // isLocked 表示用户是否已解锁该集
    // isUnlocked == 0 表示未解锁，需要上锁
    // isUnlocked == 1 表示已解锁，不需要上锁
    final isLocked = dto.isUnlocked == 0;

    return PlayerEpisode(
      id: dto.id.toString(),
      number: dto.episodeNo,
      isLocked: isLocked,
      unlockType: unlockType,
      requiredCoins: pricePerEpisode,
      // 从 PlayerContentDto 的 pricePerEpisode 获取
      videoUrl: dto.sourceUrl.isNotEmpty ? dto.sourceUrl : null,
      duration: dto.durationSec > 0 ? Duration(seconds: dto.durationSec) : null,
      isAvailable: dto.status == 1,
      subtitles: _mapSubtitles(dto.subtitles),
      episodeSources: _mapEpisodeSources(dto.episodeSources),
    );
  }

  /// 将 DTO 字幕列表转换为领域模型列表。
  List<PlayerSubtitle> _mapSubtitles(List<PlayerEpisodeSubtitleDto> dtos) {
    return dtos
        .where(
          (dto) =>
              dto.status == 1 &&
              dto.language.isNotEmpty &&
              dto.subtitleUrl.isNotEmpty,
        )
        .map((dto) {
          return PlayerSubtitle(
            id: dto.id,
            language: dto.language,
            languageCode: dto.languageCode,
            name: dto.subtitleName,
            url: dto.subtitleUrl,
            format: dto.format.isNotEmpty ? dto.format : 'vtt',
            isDefault: dto.status == 1,
            position: switch (dto.subtitlePosition) {
              '2' => PlayerSubtitlePosition.middle,
              '3' => PlayerSubtitlePosition.top,
              _ => PlayerSubtitlePosition.bottom,
            },
          );
        })
        .toList(growable: false);
  }

  List<PlayerEpisodeSource> _mapEpisodeSources(
    List<PlayerEpisodeSourceDto> dtos,
  ) {
    return dtos
        .where(
          (dto) =>
              dto.status == 1 &&
              dto.language.isNotEmpty &&
              dto.sourceUrl.isNotEmpty,
        )
        .map(
          (dto) => PlayerEpisodeSource(
            id: dto.id,
            language: dto.language,
            languageCode: dto.languageCode,
            url: dto.sourceUrl,
          ),
        )
        .toList(growable: false);
  }

  /// 根据 DTO 字段判断剧集的解锁类型。
  ///
  /// 规则：
  /// - 如果 isVipOnly == 1，则为 membership（会员专属）
  /// - 如果 isVipOnly == 0 且 isUnlocked == 0，则为 coins（需要金币解锁）
  /// - 如果 isUnlocked == 1，则为 free（已解锁，可直接观看）
  EpisodeUnlockType _determineUnlockType(PlayerEpisodeDto dto) {
    // 已解锁的剧集视为免费（可直接观看）
    if (dto.isUnlocked == 1) {
      return EpisodeUnlockType.free;
    }

    // 会员专属剧集
    if (dto.isVipOnly == 1) {
      return EpisodeUnlockType.membership;
    }

    // 需要解锁的剧集（isVipOnly=0 且 isUnlocked=0）
    return EpisodeUnlockType.coins;
  }
}
