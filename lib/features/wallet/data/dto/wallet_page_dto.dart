class WalletPageDto<T> {
  const WalletPageDto({required this.items, required this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;

  factory WalletPageDto.fromJson(
    Object? json,
    T Function(Object? json) itemMapper,
  ) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final rawItems =
        map['items'] ?? map['list'] ?? map['records'] ?? map['rows'];
    final nextPageToken = _string(map['nextPageToken']) ?? _nextPageToken(map);

    return WalletPageDto<T>(
      items: rawItems is List
          ? rawItems.map(itemMapper).toList(growable: false)
          : <T>[],
      nextPageToken: nextPageToken,
    );
  }
}

String? _nextPageToken(Map<String, Object?> map) {
  final pageInfo = map['page'] is Map<String, Object?>
      ? map['page'] as Map<String, Object?>
      : map;
  final currentPage = _firstInt(pageInfo, const [
    'page',
    'current',
    'currentPage',
    'pageNum',
    'pageNo',
  ]);
  if (currentPage == null) {
    return null;
  }

  final hasNext = pageInfo['hasNext'] ?? pageInfo['hasMore'];
  if (hasNext == true) {
    return (currentPage + 1).toString();
  }

  final pages = _firstInt(pageInfo, const ['pages', 'totalPages']);
  if (pages != null) {
    return currentPage < pages ? (currentPage + 1).toString() : null;
  }

  final pageSize = _firstInt(pageInfo, const [
    'pageSize',
    'size',
    'page_size',
  ]);
  final total = _firstInt(pageInfo, const [
    'total',
    'totalCount',
    'total_count',
  ]);
  if (pageSize != null && total != null) {
    return currentPage * pageSize < total
        ? (currentPage + 1).toString()
        : null;
  }

  return null;
}

int? _firstInt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _string(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}
