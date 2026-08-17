import '../../../core/network/api_client.dart';
import '../../../core/network/json_field_parser.dart';
import '../domain/ad_unlock_models.dart';

class AdUnlockRemoteDataSource {
  const AdUnlockRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  }) {
    return _apiClient.get<AdUnlockStatus>(
      '/api/ad/unlock/status',
      queryParameters: {'drama_id': dramaId, 'episode_no': episodeNo},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) =>
          _status(JsonFieldParser.requireMap(data, dtoName: 'AdUnlockStatus')),
    );
  }

  Future<AdMaterial> preloadMaterial({int? materialId}) {
    return _apiClient.get<AdMaterial>(
      '/api/ad/material/preload',
      queryParameters: {'material_id': ?materialId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) =>
          _material(JsonFieldParser.requireMap(data, dtoName: 'AdMaterial')),
    );
  }

  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) {
    return _apiClient.post<AdUnlockSession>(
      '/api/ad/session',
      data: {
        'drama_id': dramaId,
        'episode_no': episodeNo,
        'material_id': ?materialId,
      },
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        final map = JsonFieldParser.requireMap(
          data,
          dtoName: 'AdUnlockSession',
        );
        return AdUnlockSession(
          sessionNo: JsonFieldParser.optionalString(map, 'session_no') ?? '',
          material: _material(map),
          watchSeconds: JsonFieldParser.optionalInt(map, 'watch_seconds') ?? 30,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (JsonFieldParser.optionalInt(map, 'expire_at') ?? 0) * 1000,
          ),
          reused: (JsonFieldParser.optionalInt(map, 'reused') ?? 0) == 1,
          h5Url: JsonFieldParser.optionalString(map, 'h5_url'),
        );
      },
    );
  }

  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  }) {
    return _apiClient.post<void>(
      '/api/ad/session/confirm',
      data: {'session_no': sessionNo, 'watch_seconds': watchSeconds},
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );
  }

  static AdMaterial _material(Map<String, Object?> map) => AdMaterial(
    id: JsonFieldParser.optionalInt(map, 'material_id') ?? 0,
    fileUrl: JsonFieldParser.optionalString(map, 'file_url') ?? '',
    type: AdMaterialType.fromWire(
      JsonFieldParser.optionalInt(map, 'material_type') ?? 1,
    ),
  );

  static AdUnlockStatus _status(Map<String, Object?> map) => AdUnlockStatus(
    enabled: (JsonFieldParser.optionalInt(map, 'unlock_enabled') ?? 0) == 1,
    normalDailyLimit:
        JsonFieldParser.optionalInt(map, 'normal_daily_limit') ?? 0,
    normalUsedCount: JsonFieldParser.optionalInt(map, 'normal_used_count') ?? 0,
    normalRemainCount:
        JsonFieldParser.optionalInt(map, 'normal_remain_count') ?? 0,
    memberDailyLimit:
        JsonFieldParser.optionalInt(map, 'member_daily_limit') ?? 0,
    memberUsedCount: JsonFieldParser.optionalInt(map, 'member_used_count') ?? 0,
    memberRemainCount:
        JsonFieldParser.optionalInt(map, 'member_remain_count') ?? 0,
    episodeUnlockStatus: AdEpisodeUnlockStatus.fromWire(
      JsonFieldParser.optionalInt(map, 'episode_unlock_status') ?? 3,
    ),
    resetTime: JsonFieldParser.optionalString(map, 'reset_time'),
    message: JsonFieldParser.optionalString(map, 'episode_unlock_message'),
  );
}
