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
      nextPageToken: _nextPageToken(json),
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
      nextPageToken: _nextPageToken(json),
    );
  }
}

List<Object?> _items(Map<String, Object?> json) {
  final value = json['list'] ?? json['items'];
  if (value is List) return value;
  return const <Object?>[];
}

String? _stringValue(Object? value) => value is String ? value : null;

String? _nextPageToken(Map<String, Object?> json) {
  final explicit = _stringValue(json['nextPageToken']);
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final pageInfo = json['page'];
  if (pageInfo is! Map<String, Object?>) {
    return null;
  }

  final currentPage =
      _intValue(pageInfo['page']) ??
      _intValue(pageInfo['pageNo']) ??
      _intValue(pageInfo['pageNum']) ??
      _intValue(pageInfo['current']);
  final pageSize =
      _intValue(pageInfo['pageSize']) ??
      _intValue(pageInfo['size']) ??
      _intValue(pageInfo['limit']);
  final total =
      _intValue(pageInfo['total']) ??
      _intValue(pageInfo['totalCount']) ??
      _intValue(pageInfo['count']);
  final hasNext = pageInfo['hasNext'] == true || pageInfo['hasMore'] == true;

  if (currentPage == null) {
    return null;
  }
  if (hasNext) {
    return (currentPage + 1).toString();
  }
  if (pageSize != null && total != null && currentPage * pageSize < total) {
    return (currentPage + 1).toString();
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
