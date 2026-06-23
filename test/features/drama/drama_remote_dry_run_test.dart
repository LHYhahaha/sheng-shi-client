import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/home/data/home_repository_provider.dart';
import 'package:drama_client/features/home/data/home_remote_repository.dart';
import 'package:drama_client/features/home/domain/drama.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/drama_remote_dry_run_harness.dart';

bool _hasMappingCause(Object? error) =>
    error is ApiMappingException ||
    (error is ApiException && error.cause is ApiMappingException);

void main() {
  group('provider', () {
    test('dramaRepositoryProvider uses RemoteDramaRepository', () {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(tabs: [validTabJson()]);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(harness.apiClient),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dramaRepositoryProvider),
        isA<RemoteDramaRepository>(),
      );
    });
  });

  group('header injection', () {
    test(
      'home data request includes base headers without Authorization',
      () async {
        final harness = DramaRemoteDryRunHarness();
        harness.stubHomeData(tabs: [validTabJson()]);

        await harness.repository.getHomeData();

        final request = harness.lastRequestTo('/home/data')!;

        expect(request.headers['Device-Id'], harness.requestContext.deviceId);
        expect(request.headers['Lang'], harness.requestContext.lang);
        expect(request.headers['Platform'], harness.requestContext.platform);
        expect(
          request.headers['App-Version'],
          harness.requestContext.appVersion,
        );
        expect(request.headers.containsKey('Authorization'), isFalse);
      },
    );
  });

  group('envelope', () {
    test('code 0 returns mapped domain models', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          validTabJson(
            name: 'Popular',
            flag: 'popular',
            dramas: [validDramaItemJson(title: 'Heart Thief')],
          ),
        ],
      );

      final categories = await harness.repository.getHomeData();

      expect(categories.single.flag, 'popular');
      expect(categories.single.title, 'Popular');
      expect(categories.single.dramas.single.id, 'found-you');
      expect(categories.single.dramas.single.title, 'Heart Thief');
    });

    test('code != 0 throws ApiException with businessCode', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubEnvelopeError('GET', '/home/data', 3001);

      await expectLater(
        harness.repository.getHomeData(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.businessCode,
            'businessCode',
            3001,
          ),
        ),
      );
    });

    test('home data type wrong throws ApiMappingException', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.adapter.setResponse(
        'GET',
        '/home/data',
        RecordingHttpResponse(body: apiEnvelopeSuccess('not-a-map')),
      );

      await expectLater(
        harness.repository.getHomeData(),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test(
      'network error propagates as ApiException without mock fallback',
      () async {
        final harness = DramaRemoteDryRunHarness();
        harness.adapter.fetchException = DioException(
          requestOptions: RequestOptions(path: '/home/data'),
          type: DioExceptionType.connectionTimeout,
        );

        await expectLater(
          harness.repository.getHomeData(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              ApiErrorCode.timeout,
            ),
          ),
        );
      },
    );
  });

  group('strict DTO', () {
    test('missing drama id in tab fails mapping', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          validTabJson(
            dramas: [
              {'title': 'No Id', 'episode_total': 1},
            ],
          ),
        ],
      );

      await expectLater(
        harness.repository.getHomeData(),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test('missing tab flag fails mapping', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          {
            'id': 1,
            'name': 'Popular',
            'sort': 1,
            'status': 1,
            'dramas': [],
          },
        ],
      );

      await expectLater(
        harness.repository.getHomeData(),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test('missing title uses display fallback', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          validTabJson(
            dramas: [validDramaItemJson(title: null)],
          ),
        ],
      );

      final categories = await harness.repository.getHomeData();

      expect(categories.single.dramas.single.title, 'Untitled');
    });

    test('missing cover uses asset fallback', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          validTabJson(
            dramas: [validDramaItemJson(title: 'No Cover', coverUrl: null)],
          ),
        ],
      );

      final categories = await harness.repository.getHomeData();
      final drama = categories.single.dramas.single;

      expect(drama.coverResource.isAsset, isTrue);
      expect(drama.coverResource.value, Drama.fallbackCoverAssetPath);
    });
  });

  group('empty', () {
    test('empty tabs list succeeds', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(tabs: []);

      final categories = await harness.repository.getHomeData();

      expect(categories, isEmpty);
    });

    test('empty dramas in tab succeeds', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubHomeData(
        tabs: [
          validTabJson(dramas: []),
        ],
      );

      final categories = await harness.repository.getHomeData();

      expect(categories.single.dramas, isEmpty);
    });
  });
}

