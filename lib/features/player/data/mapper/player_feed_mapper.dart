import 'package:drama_client/features/player/data/dto/player_feed_item_dto.dart';

import '../../domain/player_feed.dart';
import 'player_content_mapper.dart';

/// 播放 feed DTO mapper。
///
/// item id 必须稳定，不能使用列表 index。For You 远程 DTO 如果没有 feedItemId，则用
/// mode + dramaId + episodeId 兜底生成。
class PlayerFeedMapper {
  const PlayerFeedMapper({
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
  }) : _contentMapper = contentMapper;

  final PlayerContentMapper _contentMapper;

  PlayerFeedItem mapSingleDramaItem({
    required String dramaId,
    required PlayerFeedMode mode,
    required PlayerFeedItemDto dto,
  }) {
    final content = _contentMapper.mapContent(dto.drama);
    final episode = _contentMapper.mapEpisode(dto.episode);
    return PlayerFeedItem(
      id: _stableItemId(
        mode: mode,
        dramaId: dramaId.isNotEmpty ? dramaId : content.id,
        episodeId: episode.id,
        feedItemId: dto.feedItemId,
      ),
      mode: mode,
      content: content,
      episode: episode,
    );
  }

  PlayerFeedItem mapForYouItem(PlayerFeedItemDto dto) {
    final content = _contentMapper.mapContent(dto.drama);
    final episode = _contentMapper.mapEpisode(dto.episode);
    return PlayerFeedItem(
      id: _stableItemId(
        mode: PlayerFeedMode.forYou,
        dramaId: dto.dramaId.isNotEmpty ? dto.dramaId : content.id,
        episodeId: dto.episodeId.isNotEmpty ? dto.episodeId : episode.id,
        feedItemId: dto.feedItemId,
      ),
      mode: PlayerFeedMode.forYou,
      content: content,
      episode: episode,
    );
  }

  String _stableItemId({
    required PlayerFeedMode mode,
    required String dramaId,
    required String episodeId,
    required String feedItemId,
  }) {
    if (feedItemId.isNotEmpty) return feedItemId;
    final prefix = mode == PlayerFeedMode.forYou ? 'for-you' : 'single';
    return '$prefix:$dramaId:$episodeId';
  }
}
