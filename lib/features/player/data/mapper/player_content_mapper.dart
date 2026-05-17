import '../../../../core/network/api_mapping_exception.dart';
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
      id: dto.dramaId,
      title: dto.title ?? _displayTitleFallback,
      playTitle: dto.title ?? _displayTitleFallback,
      synopsis: dto.description ?? '',
      viewCountLabel: dto.viewCountLabel ?? _formatViewCount(dto.viewCount),
      likeCountLabel: dto.likeCountLabel ?? '',
      backgroundAssetPath: 'assets/images/player/player_background.png',
      posterAssetPath: 'assets/images/player/recommend_1.png',
      episodes: dto.episodes.map(mapEpisode).toList(growable: false),
      recommendations: const <PlayerRecommendation>[],
    );
  }

  PlayerEpisode mapEpisode(PlayerEpisodeDto dto) {
    final unlockType = _unlockType(dto.unlockType);
    return PlayerEpisode(
      id: dto.episodeId,
      number: dto.episodeNumber,
      isLocked: unlockType != EpisodeUnlockType.free,
      unlockType: unlockType,
      requiredCoins: dto.requiredCoins ?? 0,
      videoAspectRatio: dto.aspectRatio,
      duration: _durationFromMs(dto.durationMs),
      isAvailable: dto.isAvailable,
    );
  }

  Duration? _durationFromMs(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return null;
    }
    return Duration(milliseconds: durationMs);
  }

  EpisodeUnlockType _unlockType(String value) {
    return switch (value.toLowerCase()) {
      'coins' || 'coin' => EpisodeUnlockType.coins,
      'membership' || 'member' || 'vip' => EpisodeUnlockType.membership,
      'free' => EpisodeUnlockType.free,
      _ => throw ApiMappingException(
        dtoName: 'PlayerEpisodeDto',
        field: 'unlockType',
        reason: 'unknown unlockType at mapper',
      ),
    };
  }

  String _formatViewCount(int? viewCount) {
    if (viewCount == null || viewCount <= 0) return '';
    if (viewCount >= 1000000) {
      final millions = viewCount / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M Views';
    }
    if (viewCount >= 1000) {
      final thousands = viewCount / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K Views';
    }
    return '$viewCount Views';
  }
}
