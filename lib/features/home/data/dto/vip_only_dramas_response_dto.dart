import '../../../../core/network/json_field_parser.dart';

class VipOnlyDramasResponseDto {
  const VipOnlyDramasResponseDto({required this.limit, required this.dramas});

  final int limit;
  final List<VipOnlyDramaDto> dramas;

  factory VipOnlyDramasResponseDto.fromJson(Map<String, Object?> json) {
    final dramas = json['dramas'];
    return VipOnlyDramasResponseDto(
      limit: JsonFieldParser.optionalInt(json, 'limit') ?? 6,
      dramas: dramas is List
          ? dramas
                .whereType<Map>()
                .map(
                  (item) =>
                      VipOnlyDramaDto.fromJson(Map<String, Object?>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class VipOnlyDramaDto {
  const VipOnlyDramaDto({
    required this.id,
    required this.coverUrl,
    required this.title,
    required this.summary,
  });

  final int id;
  final String coverUrl;
  final String title;
  final String summary;

  factory VipOnlyDramaDto.fromJson(Map<String, Object?> json) {
    return VipOnlyDramaDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
    );
  }
}
