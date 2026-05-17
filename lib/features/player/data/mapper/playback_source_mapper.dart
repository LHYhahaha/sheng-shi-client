import '../../../../core/network/api_mapping_exception.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_playback_source.dart';
import '../dto/playback_source_dto.dart';

/// 播放源 DTO mapper。
class PlaybackSourceMapper {
  const PlaybackSourceMapper();

  PlaybackSource mapSource(
    PlaybackSourceDto dto, {
    required PlayerFeedItem item,
    required PlaybackSourceStatus status,
  }) {
    if (!_isAccessAllowed(dto)) {
      throw ApiMappingException(
        dtoName: 'PlaybackSourceDto',
        field: 'accessStatus',
        reason: dto.reasonCode ?? dto.accessStatus ?? 'unavailable',
      );
    }

    if (!dto.expiresAt.isAfter(DateTime.now())) {
      throw const ApiMappingException(
        dtoName: 'PlaybackSourceDto',
        field: 'expiresAt',
        reason: 'playback source expired',
      );
    }

    if (dto.hlsUrl.isEmpty) {
      throw const ApiMappingException(
        dtoName: 'PlaybackSourceDto',
        field: 'hlsUrl',
        reason: 'missing hlsUrl',
      );
    }

    return PlaybackSource(
      itemId: item.id,
      remoteUrl: dto.hlsUrl,
      playableSource: dto.hlsUrl,
      cacheKey: _cacheKey(dto, item),
      expiresAt: dto.expiresAt,
      codecHint: dto.codec ?? 'hls',
      status: status,
    );
  }

  bool _isAccessAllowed(PlaybackSourceDto dto) {
    if (!dto.isAvailable) return false;
    final accessStatus = dto.accessStatus?.toLowerCase();
    if (accessStatus == null || accessStatus.isEmpty) return true;
    return switch (accessStatus) {
      'allowed' || 'allow' || 'ok' || 'available' => true,
      _ => false,
    };
  }

  String _cacheKey(PlaybackSourceDto dto, PlayerFeedItem item) {
    final sourceId = dto.sourceId.isNotEmpty ? dto.sourceId : 'unknown-source';
    return 'player:${item.content.id}:${item.episode.id}:$sourceId';
  }
}
