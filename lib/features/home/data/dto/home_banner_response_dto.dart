import '../../../../core/network/json_field_parser.dart';

class HomeBannerResponseDto {
  const HomeBannerResponseDto({required this.banners});

  final List<HomeBannerDto> banners;

  factory HomeBannerResponseDto.fromJson(Map<String, Object?> json) {
    return HomeBannerResponseDto(
      banners:
          JsonFieldParser.requireList(
                json['banners'],
                dtoName: 'HomeBannerResponseDto',
                field: 'banners',
              )
              .map(
                (item) => HomeBannerDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'HomeBannerDto',
                    field: 'banners[]',
                  ),
                ),
              )
              .toList(growable: false),
    );
  }
}

class HomeBannerDto {
  const HomeBannerDto({
    required this.bannerId,
    required this.imageUrl,
    required this.jumpType,
    required this.jumpParam,
  });

  final String bannerId;
  final String imageUrl;
  final String jumpType;
  final String jumpParam;

  /// 后端可能下发省略协议的地址，例如 `www.baidu.com`。
  String? get normalizedH5Url {
    final raw = jumpParam.trim();
    if (raw.isEmpty) return null;
    final candidate = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri.toString();
  }

  factory HomeBannerDto.fromJson(Map<String, Object?> json) {
    return HomeBannerDto(
      bannerId: JsonFieldParser.requireString(
        json,
        'banner_id',
        dtoName: 'HomeBannerDto',
      ),
      imageUrl: JsonFieldParser.requireString(
        json,
        'image_url',
        dtoName: 'HomeBannerDto',
      ),
      jumpType: JsonFieldParser.requireString(
        json,
        'jump_type',
        dtoName: 'HomeBannerDto',
      ),
      jumpParam: JsonFieldParser.requireString(
        json,
        'jump_param',
        dtoName: 'HomeBannerDto',
      ),
    );
  }
}
