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

  Future<MyListPageDto<FavoriteItemDto>> listFavorites({String? pageToken}) {
    return _apiClient.get<MyListPageDto<FavoriteItemDto>>(
      '/me/favorites',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MyListPageDto.favoritesFromJson(
        JsonFieldParser.requireMap(data, dtoName: 'FavoriteItemDto'),
      ),
    );
  }

  Future<FavoriteMutationDto> addFavorite({required String dramaId}) {
    return _apiClient.post<FavoriteMutationDto>(
      '/me/favorites',
      data: {'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<FavoriteMutationDto> deleteFavorite({required String dramaId}) {
    return _apiClient.delete<FavoriteMutationDto>(
      '/me/favorites/$dramaId',
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<FavoriteMutationDto> deleteFavorites({
    required List<String> dramaIds,
  }) {
    return _apiClient.delete<FavoriteMutationDto>(
      '/me/favorites:batch',
      data: {'dramaIds': dramaIds},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  Future<MyListPageDto<PlayHistoryItemDto>> listPlayHistory({
    String? pageToken,
  }) {
    return _apiClient.get<MyListPageDto<PlayHistoryItemDto>>(
      '/me/play-history',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MyListPageDto.playHistoryFromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayHistoryItemDto'),
      ),
    );
  }

  Future<FavoriteMutationDto> deletePlayHistory({required String historyId}) {
    return _apiClient.delete<FavoriteMutationDto>(
      '/me/play-history/$historyId',
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }
}
