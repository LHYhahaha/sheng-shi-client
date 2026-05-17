import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/playback_source_dto.dart';

/// 播放源远程数据源骨架。
class PlaybackSourceRemoteDataSource {
  const PlaybackSourceRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PlaybackSourceDto> getPlaybackSource({required String episodeId}) {
    return _apiClient.get<PlaybackSourceDto>(
      '/episodes/$episodeId/playback-source',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => PlaybackSourceDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlaybackSourceDto'),
      ),
    );
  }
}
