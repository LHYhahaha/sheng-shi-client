import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/features/drama/data/drama_repository_provider.dart';
import 'package:drama_client/features/drama/data/dto/drama_category_dto.dart';
import 'package:drama_client/features/drama/data/dto/drama_dto.dart';
import 'package:drama_client/features/drama/data/dto/drama_feed_page_dto.dart';
import 'package:drama_client/features/drama/data/mock_drama_repository.dart';
import 'package:drama_client/features/drama/data/remote/drama_remote_data_source.dart';
import 'package:drama_client/features/drama/data/remote_drama_repository.dart';
import 'package:drama_client/features/drama/domain/drama_repository.dart';

void main() {
  test('remote repository maps categories through mapper', () async {
    final repository = RemoteDramaRepository(
      remoteDataSource: _FakeDramaRemoteDataSource(
        categories: const [
          DramaCategoryDto(id: 'popular', title: 'Popular', sortOrder: 1),
        ],
      ),
    );

    final categories = await repository.listHomeCategories();

    expect(categories, hasLength(1));
    expect(categories.single.id, 'popular');
    expect(categories.single.title, 'Popular');
  });

  test('remote repository maps feed page through mapper', () async {
    final repository = RemoteDramaRepository(
      remoteDataSource: _FakeDramaRemoteDataSource(
        feedPage: const DramaFeedPageDto(
          items: [
            DramaDto(
              dramaId: 'heart-thief',
              title: 'Heart Thief',
              description: null,
              coverUrl: 'https://cdn.example.com/heart.jpg',
              posterUrl: null,
              viewCount: null,
              viewCountLabel: '8.4 M',
              episodeCount: 60,
              tags: ['Drama'],
              badges: ['exclusive'],
              categoryIds: ['new'],
              coverAspectRatio: 0.75,
            ),
          ],
          nextPageToken: '2',
        ),
      ),
    );

    final page = await repository.listHomeFeed(
      categoryId: 'new',
      pageToken: '1',
      pageSize: 20,
    );

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'heart-thief');
    expect(page.items.single.categoryId, 'new');
    expect(page.items.single.isExclusive, isTrue);
    expect(page.nextPageToken, '2');
  });

  test('dramaRepositoryProvider default remains mock', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(dramaRepositoryProvider);

    expect(repository, isA<MockDramaRepository>());
    expect(repository, isA<DramaRepository>());
  });

  test('dramaRepositoryProvider can be switched to remote', () {
    final container = ProviderContainer(
      overrides: [useRemoteDramaApiProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    final repository = container.read(dramaRepositoryProvider);

    expect(repository, isA<RemoteDramaRepository>());
    expect(repository, isA<DramaRepository>());
  });
}

class _FakeDramaRemoteDataSource implements DramaRemoteDataSource {
  _FakeDramaRemoteDataSource({
    this.categories = const <DramaCategoryDto>[],
    this.feedPage = const DramaFeedPageDto(items: [], nextPageToken: null),
  });

  final List<DramaCategoryDto> categories;
  final DramaFeedPageDto feedPage;

  @override
  Future<List<DramaCategoryDto>> listHomeCategories() async => categories;

  @override
  Future<DramaFeedPageDto> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) async => feedPage;
}
