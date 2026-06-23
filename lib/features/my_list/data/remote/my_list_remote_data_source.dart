import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/favorite_item_dto.dart';
import '../dto/favorite_mutation_dto.dart';
import '../dto/my_list_page_dto.dart';
import '../dto/play_history_item_dto.dart';

/// My list / 播放历史远程数据源骨架。
class MyListRemoteDataSource {
  const MyListRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MyListPageDto<FavoriteItemDto>> listFavorites({
    int? page,
    int? pageSize,
  }) {
    return _apiClient.get<MyListPageDto<FavoriteItemDto>>(
      '/api/user/short/follow/list',
      queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MyListPageDto.favoritesFromJson(
        JsonFieldParser.requireMap(data, dtoName: 'FavoriteItemDto'),
      ),
    );
  }

  Future<FavoriteMutationDto> addFavorite({required int dramaId}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/me/favorites',
      data: {'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<FavoriteMutationDto> deleteFavorite({required int dramaId}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/api/user/short/unfollow',
      data: {'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<FavoriteMutationDto> deleteFavorites({required List<int> dramaIds}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/api/user/short/unfollow',
      data: {'dramaIds': dramaIds},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<MyListPageDto<PlayHistoryItemDto>> listPlayHistory({
    int? page,
    int? pageSize,
  }) {
    return _apiClient.get<MyListPageDto<PlayHistoryItemDto>>(
      '/api/user/watch/history/list',
      queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MyListPageDto.playHistoryFromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayHistoryItemDto'),
      ),
    );
  }

  Future<FavoriteMutationDto> deletePlayHistory({required int historyId}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/api/user/watch/history/delete',
      data: {"dramaId": historyId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<FavoriteMutationDto> deletePlayHistories({List<int>? historyIds}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/api/user/watch/history/delete',
      data: {'dramaIds': historyIds},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }
}
