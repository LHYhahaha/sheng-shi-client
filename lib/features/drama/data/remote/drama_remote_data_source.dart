import '../../../../core/network/api_client.dart';
import '../dto/drama_category_dto.dart';
import '../dto/drama_feed_page_dto.dart';

/// Home/Drama 远程数据源骨架。
///
/// 这里只负责调用 API 和解析 DTO，不返回 domain model，也不处理 UI 状态。默认 provider
/// 仍走 mock，本类用于后续真实接口接入和 mapper 单元测试。
class DramaRemoteDataSource {
  const DramaRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DramaCategoryDto>> listHomeCategories() {
    return _apiClient.get<List<DramaCategoryDto>>(
      '/home/categories',
      decoder: (data) {
        final items = _extractList(data, fallbackKey: 'items');
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
      decoder: (data) {
        if (data is Map<String, Object?>) {
          return DramaFeedPageDto.fromJson(data);
        }
        return const DramaFeedPageDto(items: [], nextPageToken: null);
      },
    );
  }

  List<Object?> _extractList(Object? data, {required String fallbackKey}) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, Object?>) {
      final value = data[fallbackKey];
      if (value is List) {
        return value;
      }
    }
    return const <Object?>[];
  }
}
