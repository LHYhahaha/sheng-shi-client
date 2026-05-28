class WalletPageDto<T> {
  const WalletPageDto({required this.items, required this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;

  factory WalletPageDto.fromJson(
    Object? json,
    T Function(Object? json) itemMapper,
  ) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    
    // 适配两种格式：
    // 1. 游标分页（旧格式）：直接包含 items 和 nextPageToken
    // 2. 偏移量分页（充值记录）：包含 list 和 page 对象
    final rawItems = map['items'] ?? 
        (map['list'] is List ? map['list'] : null);
    
    // 计算 nextPageToken
    String? nextPageToken = map['nextPageToken'] is String
        ? map['nextPageToken'] as String
        : null;
    
    // 如果没有游标token，尝试从 page 对象计算
    if (nextPageToken == null && map['page'] is Map<String, Object?>) {
      final pageInfo = map['page'] as Map<String, Object?>;
      final currentPage = _int(pageInfo['page']);
      final pageSize = _int(pageInfo['pageSize']);
      final total = _int(pageInfo['total']);
      
      // 如果还有更多数据，计算下一页的页码
      if ((currentPage + 1) * pageSize < total) {
        nextPageToken = (currentPage + 1).toString();
      }
    }
    
    return WalletPageDto<T>(
      items: rawItems is List
          ? rawItems.map(itemMapper).toList(growable: false)
          : <T>[],
      nextPageToken: nextPageToken,
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
