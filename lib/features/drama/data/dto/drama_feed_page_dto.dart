import 'drama_dto.dart';

/// 首页 feed 分页远程 DTO。
class DramaFeedPageDto {
  const DramaFeedPageDto({required this.items, required this.nextPageToken});

  final List<DramaDto> items;
  final String? nextPageToken;

  factory DramaFeedPageDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    return DramaFeedPageDto(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, Object?>>()
                .map(DramaDto.fromJson)
                .toList(growable: false)
          : const <DramaDto>[],
      nextPageToken: json['nextPageToken'] is String
          ? json['nextPageToken']! as String
          : null,
    );
  }
}
