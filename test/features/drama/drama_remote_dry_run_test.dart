import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/drama/data/drama_repository_provider.dart';
import 'package:drama_client/features/drama/data/mock_drama_repository.dart';
import 'package:drama_client/features/drama/data/remote_drama_repository.dart';
import 'package:drama_client/features/drama/domain/drama.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/drama_remote_dry_run_harness.dart';

bool _hasMappingCause(Object? error) =>
    error is ApiMappingException ||
    (error is ApiException && error.cause is ApiMappingException);

void main() {
  group('provider switch', () {
    test('dramaRepositoryProvider defaults to mock', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(useRemoteDramaApiProvider), isFalse);
      expect(
        container.read(dramaRepositoryProvider),
        isA<MockDramaRepository>(),
      );
    });

    test('remote override wires RemoteDramaRepository with ApiClient', () {
      final harness = DramaRemoteDryRunHarness();
      harness.stubCategories([
        {'id': 'popular', 'title': 'Popular', 'sortOrder': 1},
      ]);

      final container = ProviderContainer(
        overrides: [
          useRemoteDramaApiProvider.overrideWithValue(true),
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
      'categories and feed requests include base headers without Authorization',
      () async {
        final harness = DramaRemoteDryRunHarness();
        harness.stubCategories([
          {'id': 'popular', 'title': 'Popular', 'sortOrder': 1},
        ]);
        harness.stubFeed(items: [validDramaItemJson()]);

        await harness.repository.listHomeCategories();
        await harness.repository.listHomeFeed(categoryId: 'popular');

        final categoriesRequest = harness.lastRequestTo('/home/categories')!;
        final feedRequest = harness.lastRequestTo('/home/feed')!;

        for (final request in [categoriesRequest, feedRequest]) {
          expect(request.headers['Device-Id'], harness.requestContext.deviceId);
          expect(request.headers['Lang'], harness.requestContext.lang);
          expect(request.headers['Platform'], harness.requestContext.platform);
          expect(
            request.headers['App-Version'],
            harness.requestContext.appVersion,
          );
          expect(request.headers.containsKey('Authorization'), isFalse);
        }

        expect(feedRequest.queryParameters['categoryId'], 'popular');
      },
    );
  });

  group('envelope', () {
    test('code 0 returns mapped domain models', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubCategories([
        {'id': 'new', 'title': 'New', 'sortOrder': 2},
      ]);
      harness.stubFeed(
        items: [validDramaItemJson(title: 'Heart Thief')],
        nextPageToken: 'page-2',
      );

      final categories = await harness.repository.listHomeCategories();
      final page = await harness.repository.listHomeFeed(categoryId: 'new');

      expect(categories.single.id, 'new');
      expect(page.items.single.id, 'found-you');
      expect(page.items.single.title, 'Heart Thief');
      expect(page.nextPageToken, 'page-2');
    });

    test('code != 0 throws ApiException with businessCode', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubEnvelopeError('GET', '/home/feed', 3001);

      await expectLater(
        harness.repository.listHomeFeed(categoryId: 'popular'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.businessCode,
            'businessCode',
            3001,
          ),
        ),
      );
    });

    test('feed data type wrong throws ApiMappingException', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.adapter.setResponse(
        'GET',
        '/home/feed',
        RecordingHttpResponse(body: apiEnvelopeSuccess('not-a-map')),
      );

      await expectLater(
        harness.repository.listHomeFeed(categoryId: 'popular'),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test(
      'network error propagates as ApiException without mock fallback',
      () async {
        final harness = DramaRemoteDryRunHarness();
        harness.adapter.fetchException = DioException(
          requestOptions: RequestOptions(path: '/home/categories'),
          type: DioExceptionType.connectionTimeout,
        );

        await expectLater(
          harness.repository.listHomeCategories(),
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
    test('missing dramaId in feed item fails mapping', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubFeed(
        items: [
          {'title': 'No Id', 'episodeCount': 1},
        ],
      );

      await expectLater(
        harness.repository.listHomeFeed(categoryId: 'popular'),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test('missing category id fails mapping', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubCategories([
        {'title': 'Popular', 'sortOrder': 1},
      ]);

      await expectLater(
        harness.repository.listHomeCategories(),
        throwsA(predicate(_hasMappingCause, 'mapping failure')),
      );
    });

    test('missing title uses display fallback', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubFeed(items: [validDramaItemJson(title: null)]);

      final page = await harness.repository.listHomeFeed(categoryId: 'popular');

      expect(page.items.single.title, 'Untitled');
    });

    test('missing cover uses asset fallback', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubFeed(
        items: [validDramaItemJson(title: 'No Cover', coverUrl: null)],
      );

      final page = await harness.repository.listHomeFeed(categoryId: 'popular');
      final drama = page.items.single;

      expect(drama.coverResource.isAsset, isTrue);
      expect(drama.coverResource.value, Drama.fallbackCoverAssetPath);
    });
  });

  group('pagination and empty', () {
    test('empty categories list succeeds', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubCategories([]);

      final categories = await harness.repository.listHomeCategories();

      expect(categories, isEmpty);
    });

    test('empty feed page succeeds', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.stubFeed(items: []);

      final page = await harness.repository.listHomeFeed(categoryId: 'popular');

      expect(page.items, isEmpty);
      expect(page.nextPageToken, isNull);
    });

    test('feed wrapped in items envelope key is accepted', () async {
      final harness = DramaRemoteDryRunHarness();
      harness.adapter.setResponse(
        'GET',
        '/home/categories',
        RecordingHttpResponse(
          body: apiEnvelopeSuccess({
            'items': [
              {'id': 'popular', 'title': 'Popular', 'sortOrder': 1},
            ],
          }),
        ),
      );

      final categories = await harness.repository.listHomeCategories();

      expect(categories, hasLength(1));
      expect(categories.single.id, 'popular');
    });
  });

  group('mock path unaffected', () {
    test('USE_REMOTE_DRAMA_API false keeps mock in provider container', () {
      final harness = DramaRemoteDryRunHarness();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(harness.apiClient)],
      );
      addTearDown(container.dispose);

      expect(container.read(useRemoteDramaApiProvider), isFalse);
      expect(
        container.read(dramaRepositoryProvider),
        isA<MockDramaRepository>(),
      );
    });
  });
}
