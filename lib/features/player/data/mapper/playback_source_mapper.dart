import '../../domain/player_feed.dart';
import '../../domain/player_playback_source.dart';
import '../dto/playback_source_dto.dart';

/// 播放源 DTO mapper。
///
/// subtitleTracks、preview sprite、cache/preload policy 目前只作为接口 contract 保留；
/// 当前播放器 domain 尚未消费这些字段。后续扩展时应继续从这里映射，不要让 UI 读 DTO。
class PlaybackSourceMapper {
  const PlaybackSourceMapper();

  PlaybackSource mapSource(
    PlaybackSourceDto dto, {
    required PlayerFeedItem item,
    required PlaybackSourceStatus status,
  }) {
    if (!_isAccessAllowed(dto)) {
      throw StateError(
        'Playback source unavailable: ${dto.reasonCode ?? dto.accessStatus ?? 'unknown'}.',
      );
    }

    final expiresAt = dto.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      throw StateError('Playback source expired.');
    }

    final hlsUrl = dto.hlsUrl;
    if (hlsUrl == null || hlsUrl.isEmpty) {
      throw StateError('Playback source missing hlsUrl.');
    }

    return PlaybackSource(
      itemId: item.id,
      remoteUrl: hlsUrl,
      playableSource: hlsUrl,
      cacheKey: _cacheKey(dto, item),
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
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
