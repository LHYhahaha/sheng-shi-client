import 'favorite_item_dto.dart';
import 'play_history_item_dto.dart';

/// My list 远程分页 DTO。
///
/// 收藏和播放历史共用 token 分页结构，但 item 类型不同。repository 会按 tab 选择
/// 对应的 fromJson，避免 UI 感知远程分页格式。
class MyListPageDto<T> {
  const MyListPageDto({required this.items, required this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;

  static MyListPageDto<FavoriteItemDto> favoritesFromJson(
    Map<String, Object?> json,
  ) {
    return MyListPageDto<FavoriteItemDto>(
      items: _items(json)
          .whereType<Map<String, Object?>>()
          .map(FavoriteItemDto.fromJson)
          .toList(growable: false),
      nextPageToken: _stringValue(json['nextPageToken']),
    );
  }

  static MyListPageDto<PlayHistoryItemDto> playHistoryFromJson(
    Map<String, Object?> json,
  ) {
    return MyListPageDto<PlayHistoryItemDto>(
      items: _items(json)
          .whereType<Map<String, Object?>>()
          .map(PlayHistoryItemDto.fromJson)
          .toList(growable: false),
      nextPageToken: _stringValue(json['nextPageToken']),
    );
  }
}

List<Object?> _items(Map<String, Object?> json) {
  final value = json['list'];
  if (value is List) return value;
  return const <Object?>[];
}

String? _stringValue(Object? value) => value is String ? value : null;
