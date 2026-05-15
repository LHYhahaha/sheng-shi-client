import '../domain/drama.dart';
import '../domain/drama_repository.dart';

/// 首页 mock 数据仓库。
///
/// 这里模拟分类、分页和剧卡元信息，不模拟播放源。播放源留在 player mock repository，
/// 保持 Home 与 Player 的业务边界和真实后端一致。
class MockDramaRepository implements DramaRepository {
  const MockDramaRepository();

  static const _networkDelay = Duration(milliseconds: 220);

  @override
  Future<List<DramaCategory>> listHomeCategories() async {
    return Future<List<DramaCategory>>.delayed(
      _networkDelay,
      () => _categories,
    );
  }

  @override
  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) async {
    final page = int.tryParse(pageToken ?? '0') ?? 0;
    final source = _items
        .where((item) {
          return categoryId == 'popular' || item.categoryId == categoryId;
        })
        .toList(growable: false);

    final repeated = List<Drama>.generate(pageSize, (index) {
      final base = source[(page * pageSize + index) % source.length];
      final sequence = page * pageSize + index;

      return Drama(
        id: '${base.id}-$sequence',
        title: base.title,
        coverAssetPath: base.coverAssetPath,
        viewCountLabel: base.viewCountLabel,
        episodeCount: base.episodeCount,
        categoryId: base.categoryId,
        tags: base.tags,
        coverAspectRatio: base.coverAspectRatio,
        isExclusive: base.isExclusive && sequence.isOdd,
      );
    });

    return Future<DramaFeedPage>.delayed(
      _networkDelay,
      () => DramaFeedPage(
        items: repeated,
        nextPageToken: page >= 3 ? null : '${page + 1}',
      ),
    );
  }

  static const _categories = [
    DramaCategory(id: 'popular', title: 'Popular'),
    DramaCategory(id: 'new', title: 'New'),
    DramaCategory(id: 'ranking', title: 'Ranking'),
    DramaCategory(id: 'original', title: 'Original'),
    DramaCategory(id: 'asian', title: 'Asian'),
  ];

  static final _items = [
    Drama(
      id: 'found-you',
      title: 'Found You,Hea',
      coverAssetPath: 'assets/images/home/drama_cover_figma.png',
      viewCountLabel: '84.1 M',
      episodeCount: 52,
      categoryId: 'popular',
      tags: ['Rebirth'],
      coverAspectRatio: 171 / 226,
    ),
    Drama(
      id: 'heart-thief',
      title: 'Found You,Heart\nThiefFound You,Heart Th...',
      coverAssetPath: 'assets/images/home/drama_cover_figma.png',
      viewCountLabel: '84.1 M',
      episodeCount: 60,
      categoryId: 'new',
      tags: ['Rebirth', 'Rebirth'],
      coverAspectRatio: 171 / 226,
      isExclusive: true,
    ),
    Drama(
      id: 'reborn-love',
      title: 'Found You,Hea',
      coverAssetPath: 'assets/images/home/drama_cover_figma.png',
      viewCountLabel: '84.1 M',
      episodeCount: 48,
      categoryId: 'ranking',
      tags: ['Rebirth'],
      coverAspectRatio: 171 / 226,
    ),
    Drama(
      id: 'secret-vow',
      title: 'Found You,Heart\nThiefFound You,Heart Th...',
      coverAssetPath: 'assets/images/home/drama_cover_figma.png',
      viewCountLabel: '84.1 M',
      episodeCount: 66,
      categoryId: 'original',
      tags: ['Rebirth'],
      coverAspectRatio: 171 / 226,
    ),
    Drama(
      id: 'asian-reunion',
      title: 'Found You,Hea',
      coverAssetPath: 'assets/images/home/drama_cover_figma.png',
      viewCountLabel: '84.1 M',
      episodeCount: 45,
      categoryId: 'asian',
      tags: ['Rebirth'],
      coverAspectRatio: 171 / 226,
    ),
  ];
}
