import 'player_content.dart';

enum PlayerFeedMode { singleDrama, forYou }

class PlayerFeedConfig {
  const PlayerFeedConfig.singleDrama({
    required this.dramaId,
    required this.episodeId,
  }) : mode = PlayerFeedMode.singleDrama;

  const PlayerFeedConfig.forYou()
    : mode = PlayerFeedMode.forYou,
      dramaId = null,
      episodeId = null;

  final PlayerFeedMode mode;
  final String? dramaId;
  final String? episodeId;

  @override
  bool operator ==(Object other) {
    return other is PlayerFeedConfig &&
        other.mode == mode &&
        other.dramaId == dramaId &&
        other.episodeId == episodeId;
  }

  @override
  int get hashCode => Object.hash(mode, dramaId, episodeId);
}

class PlayerFeedItem {
  const PlayerFeedItem({
    required this.id,
    required this.mode,
    required this.content,
    required this.episode,
  });

  final String id;
  final PlayerFeedMode mode;
  final PlayerContent content;
  final PlayerEpisode episode;

  PlayerFeedItem copyWith({PlayerEpisode? episode}) {
    return PlayerFeedItem(
      id: id,
      mode: mode,
      content: content,
      episode: episode ?? this.episode,
    );
  }
}

abstract interface class PlayerFeedRepository {
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  });

  Future<List<PlayerFeedItem>> listForYouFeed();
}
