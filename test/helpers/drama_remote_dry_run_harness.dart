import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/drama/data/remote/drama_remote_data_source.dart';
import 'package:drama_client/features/drama/data/remote_drama_repository.dart';
import 'package:drama_client/features/drama/domain/drama_repository.dart';

import 'fake_api_envelope.dart';
import 'recording_http_adapter.dart';

export 'fake_api_envelope.dart';
export 'recording_http_adapter.dart';

/// Home/Drama 只读 remote 链路 dry run 入口（fake HTTP，无真实 server）。
class DramaRemoteDryRunHarness {
  DramaRemoteDryRunHarness({
    ApiRequestContext? requestContext,
    Map<String, RecordingHttpResponse>? responses,
  }) : adapter = RecordingHttpAdapter(responses: responses ?? const {}),
       requestContext =
           requestContext ??
           const ApiRequestContext(
             deviceId: 'dry-run-install-id',
             lang: 'en',
             platform: 'android',
             appVersion: '1.0.0',
           ) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://dry-run.test',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    dio.httpClientAdapter = adapter;

    apiClient = ApiClient(dio: dio, requestContext: this.requestContext);
    remoteDataSource = DramaRemoteDataSource(apiClient: apiClient);
    repository = RemoteDramaRepository(remoteDataSource: remoteDataSource);
  }

  final RecordingHttpAdapter adapter;
  final ApiRequestContext requestContext;
  late final ApiClient apiClient;
  late final DramaRemoteDataSource remoteDataSource;
  late final RemoteDramaRepository repository;

  void stubHomeData({
    required List<Map<String, Object?>> tabs,
  }) {
    adapter.setResponse(
      'GET',
      '/home/data',
      RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'id': 1,
          'name': 'Home',
          'status': 1,
          'tabs': tabs,
        }),
      ),
    );
  }

  void stubEnvelopeError(String method, String path, int code) {
    adapter.setResponse(
      method,
      path,
      RecordingHttpResponse(
        body: apiEnvelopeError(code, message: 'business failure'),
      ),
    );
  }

  RecordedHttpRequest? lastRequestTo(String path) {
    for (final request in adapter.requests.reversed) {
      if (request.path == path) {
        return request;
      }
    }
    return null;
  }

  DramaRepository get repositoryInterface => repository;
}

/// 契约级 drama 条目（strict id）。
Map<String, Object?> validDramaItemJson({
  String id = 'found-you',
  String? title,
  String? coverUrl,
  int episodeTotal = 52,
}) => {
  'id': id,
  'title': ?title,
  'cover_url': ?coverUrl,
  'episode_total': episodeTotal,
  'sort': 1,
  'summary': '',
  'play_count': 84100000,
  'trailer_episode_num': 2,
  'is_vip_only': 0,
  'status': 1,
};

/// 契约级 tab 条目。
Map<String, Object?> validTabJson({
  int id = 1,
  String name = 'Popular',
  String flag = 'popular',
  int sort = 1,
  int status = 1,
  List<Map<String, Object?>>? dramas,
}) => {
  'id': id,
  'name': name,
  'flag': flag,
  'sort': sort,
  'status': status,
  'dramas': dramas ?? [validDramaItemJson()],
};

