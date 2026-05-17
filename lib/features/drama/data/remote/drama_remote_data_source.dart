import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/drama_category_dto.dart';
import '../dto/drama_feed_page_dto.dart';

/// Home/Drama 远程数据源骨架。
class DramaRemoteDataSource {
  const DramaRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DramaCategoryDto>> listHomeCategories() {
    return _apiClient.get<List<DramaCategoryDto>>(
      '/home/categories',
      decoder: (data) {
        final items = _extractList(data, dtoName: 'DramaCategoryDto');
        return items
            .whereType<Map<String, Object?>>()
            .map(DramaCategoryDto.fromJson)
            .toList(growable: false);
      },
    );
  }

  Future<DramaFeedPageDto> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) {
    return _apiClient.get<DramaFeedPageDto>(
      '/home/feed',
      queryParameters: <String, Object?>{
        'categoryId': categoryId,
        'pageToken': pageToken,
        'pageSize': pageSize,
      }..removeWhere((_, value) => value == null),
      decoder: (data) => DramaFeedPageDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'DramaFeedPageDto'),
      ),
    );
  }

  List<Object?> _extractList(Object? data, {required String dtoName}) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, Object?>) {
      final value = data['items'];
      if (value is List) {
        return value;
      }
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: 'items',
      reason: 'expected array payload',
    );
  }
}
