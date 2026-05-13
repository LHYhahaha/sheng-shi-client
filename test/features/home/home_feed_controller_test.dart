import 'package:drama_client/features/drama/data/drama_repository_provider.dart';
import 'package:drama_client/features/drama/domain/drama.dart';
import 'package:drama_client/features/drama/domain/drama_repository.dart';
import 'package:drama_client/features/home/application/home_feed_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads initial home feed data', () async {
    final repository = _FakeDramaRepository();
    final container = _createContainer(repository);

    await container.read(homeFeedControllerProvider.notifier).loadInitial();
    final state = container.read(homeFeedControllerProvider);

    expect(state.isInitialLoading, isFalse);
    expect(state.initialError, isNull);
    expect(state.categories.map((category) => category.id), ['popular']);
    expect(state.items.map((item) => item.id), ['drama-1']);
  });

  test('shows empty when repository returns no feed items', () async {
    final repository = _FakeDramaRepository(items: const []);
    final container = _createContainer(repository);

    await container.read(homeFeedControllerProvider.notifier).loadInitial();
    final state = container.read(homeFeedControllerProvider);

    expect(state.isInitialLoading, isFalse);
    expect(state.initialError, isNull);
    expect(state.items, isEmpty);
    expect(state.categories, isNotEmpty);
  });

  test('keeps initial error retryable', () async {
    final repository = _FakeDramaRepository()..shouldThrow = true;
    final container = _createContainer(repository);
    final controller = container.read(homeFeedControllerProvider.notifier);

    await controller.loadInitial();
    var state = container.read(homeFeedControllerProvider);
    expect(state.isInitialLoading, isFalse);
    expect(state.initialError, isA<StateError>());
    expect(state.items, isEmpty);

    repository.shouldThrow = false;
    await controller.loadInitial();
    state = container.read(homeFeedControllerProvider);

    expect(state.initialError, isNull);
    expect(state.items.map((item) => item.id), ['drama-1']);
  });
}

ProviderContainer _createContainer(DramaRepository repository) {
  final container = ProviderContainer(
    overrides: [dramaRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeDramaRepository implements DramaRepository {
  _FakeDramaRepository({this.items = const [_drama]});

  bool shouldThrow = false;
  final List<Drama> items;

  @override
  Future<List<DramaCategory>> listHomeCategories() async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    return const [DramaCategory(id: 'popular', title: 'Popular')];
  }

  @override
  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    return DramaFeedPage(items: items, nextPageToken: null);
  }
}

const _drama = Drama(
  id: 'drama-1',
  title: 'Drama 1',
  coverAssetPath: 'assets/images/home/drama_cover_figma.png',
  viewCountLabel: '1 M',
  episodeCount: 10,
  categoryId: 'popular',
  tags: ['Rebirth'],
  coverAspectRatio: 171 / 226,
);
