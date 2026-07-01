import 'player_feed_item_dto.dart';

/// 播放 feed 分页远程 DTO。
class PlayerFeedPageDto {
  const PlayerFeedPageDto({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
  });

  final int page;
  final int pageSize;
  final int total;
  final List<PlayerFeedItemDto> items;

  bool get hasMore => page * pageSize < total;

  factory PlayerFeedPageDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['dramas'];
    return PlayerFeedPageDto(
      page: _intValue(json['page']) ?? 1,
      pageSize: _intValue(json['page_size']) ?? 20,
      total: _intValue(json['total']) ?? 0,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => PlayerFeedItemDto.fromJson(
                    Map<String, Object?>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <PlayerFeedItemDto>[],
    );
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
