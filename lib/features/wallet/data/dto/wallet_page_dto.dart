class WalletPageDto<T> {
  const WalletPageDto({required this.items, required this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;

  factory WalletPageDto.fromJson(
    Object? json,
    T Function(Object? json) itemMapper,
  ) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final rawItems = map['items'];
    return WalletPageDto<T>(
      items: rawItems is List
          ? rawItems.map(itemMapper).toList(growable: false)
          : <T>[],
      nextPageToken: map['nextPageToken'] is String
          ? map['nextPageToken'] as String
          : null,
    );
  }
}
