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

  void stubCategories(List<Map<String, Object?>> items) {
    adapter.setResponse(
      'GET',
      '/home/categories',
      RecordingHttpResponse(body: apiEnvelopeSuccess(items)),
    );
  }

  void stubFeed({
    required List<Map<String, Object?>> items,
    String? nextPageToken,
  }) {
    adapter.setResponse(
      'GET',
      '/home/feed',
      RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'items': items,
          'nextPageToken': ?nextPageToken,
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

/// 契约级 drama 条目（strict dramaId）。
Map<String, Object?> validDramaItemJson({
  String dramaId = 'found-you',
  String? title,
  String? coverUrl,
  int episodeCount = 52,
}) => {
  'dramaId': dramaId,
  'title': ?title,
  'coverUrl': ?coverUrl,
  'episodeCount': episodeCount,
  'tags': <String>[],
  'badges': <String>[],
  'categoryIds': <String>['popular'],
};
