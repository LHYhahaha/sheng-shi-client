import 'player_feed_item_dto.dart';

/// 播放 feed 分页远程 DTO。
class PlayerFeedPageDto {
  const PlayerFeedPageDto({required this.items, required this.nextPageToken});

  final List<PlayerFeedItemDto> items;
  final String? nextPageToken;

  factory PlayerFeedPageDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    return PlayerFeedPageDto(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, Object?>>()
                .map(PlayerFeedItemDto.fromJson)
                .toList(growable: false)
          : const <PlayerFeedItemDto>[],
      nextPageToken: json['nextPageToken'] is String
          ? json['nextPageToken']! as String
          : null,
    );
  }
}
