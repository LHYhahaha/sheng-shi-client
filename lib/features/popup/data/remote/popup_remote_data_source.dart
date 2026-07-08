import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/popup_dto.dart';
import '../dto/popup_exit_recommendation_dto.dart';

class PopupRemoteDataSource {
  const PopupRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PopupDto?> fetchPopup({required String placementCode}) {
    return _apiClient.get<PopupDto?>(
      '/api/popup',
      queryParameters: <String, Object?>{'placement_code': placementCode},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data == null) {
          return null;
        }
        if (data is Map<String, Object?>) {
          return PopupDto.fromJson(data);
        }
        if (data is Map) {
          return PopupDto.fromJson(Map<String, Object?>.from(data));
        }
        return null;
      },
    );
  }

  Future<PopupExitRecommendationResponseDto> fetchDetailExitPopup({
    required String dramaId,
    CancelToken? cancelToken,
  }) {
    return _apiClient.get<PopupExitRecommendationResponseDto>(
      '/api/popup/detail/exit',
      queryParameters: <String, Object?>{'drama_id': dramaId},
      authPolicy: ApiAuthPolicy.required,
      cancelToken: cancelToken,
      decoder: (data) => PopupExitRecommendationResponseDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'PopupExitRecommendationResponseDto',
        ),
      ),
    );
  }
}
