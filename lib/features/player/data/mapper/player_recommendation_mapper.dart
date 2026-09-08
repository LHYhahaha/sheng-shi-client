import '../../domain/player_content.dart';
import '../dto/player_recommendation_dto.dart';

/// 推荐项 DTO 到 domain 的 mapper。
class PlayerRecommendationMapper {
  const PlayerRecommendationMapper();

  static const _displayTitleFallback = 'Untitled';
  static const _fallbackCoverAssetPath =
      'assets/images/player/recommend_placeholder.png';

  PlayerRecommendation mapRecommendation(PlayerRecommendationDto dto) {
    return PlayerRecommendation(
      id: dto.id.toString(),
      title: dto.title.isNotEmpty ? dto.title : _displayTitleFallback,
      subtitle: _formatSubtitle(dto),
      // 如果是网络 URL，保持原样；否则使用 fallback
      coverAssetPath: dto.coverUrl.isNotEmpty
          ? dto.coverUrl
          : _fallbackCoverAssetPath,
      watchProgress: dto.watchProgress?.toDomain(),
      trial: dto.trial?.toDomain(),
    );
  }

  List<PlayerRecommendation> mapRecommendations(
    List<PlayerRecommendationDto> dtos,
  ) {
    return dtos.map((dto) => mapRecommendation(dto)).toList(growable: false);
  }

  /// 格式化副标题：优先使用标签，其次使用简介。
  String _formatSubtitle(PlayerRecommendationDto dto) {
    if (dto.tagsName.isNotEmpty) {
      return dto.tagsName.join(' · ');
    }
    return dto.summary.isNotEmpty ? dto.summary : '';
  }
}
