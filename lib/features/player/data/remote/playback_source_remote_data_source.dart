import '../../../../core/network/api_client.dart';
import '../dto/playback_source_dto.dart';

/// 播放源远程数据源骨架。
///
/// 播放源接口属于登录后的业务接口，默认使用 `ApiAuthPolicy.required`。当前 token 可为空，
/// 不会影响 skeleton 测试；真实 token storage 后续再接入 ApiRequestContext。
class PlaybackSourceRemoteDataSource {
  const PlaybackSourceRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PlaybackSourceDto> getPlaybackSource({required String episodeId}) {
    return _apiClient.get<PlaybackSourceDto>(
      '/episodes/$episodeId/playback-source',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data is Map<String, Object?>) {
          return PlaybackSourceDto.fromJson(data);
        }
        return const PlaybackSourceDto(
          episodeId: '',
          sourceId: '',
          hlsUrl: null,
          backupHlsUrls: [],
          expiresAt: null,
          durationMs: null,
          width: null,
          height: null,
          aspectRatio: null,
          codec: null,
          cachePolicy: {},
          preloadPolicy: {},
          subtitleTracks: [],
          previewSpriteUrl: null,
          previewVttUrl: null,
        );
      },
    );
  }
}
