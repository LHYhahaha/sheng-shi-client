import '../domain/drama.dart';
import '../domain/drama_repository.dart';

class MockDramaRepository implements DramaRepository {
  const MockDramaRepository();

  @override
  Future<List<Drama>> listDramas({String? category}) async {
    final items = _items.where((item) {
      return category == null ||
          category == 'Popular' ||
          item.category == category;
    }).toList();

    return Future<List<Drama>>.delayed(
      const Duration(milliseconds: 200),
      () => items,
    );
  }

  static const _items = [
    Drama(
      id: 'reborn-the-cure',
      title: 'Reborn: The Cure',
      coverUrl: 'https://picsum.photos/seed/reborn/360/540',
      episodeCount: 62,
      category: 'Original',
      isExclusive: true,
    ),
    Drama(
      id: 'life-that-shines',
      title: 'A Life That Shines Again',
      coverUrl: 'https://picsum.photos/seed/shines/360/540',
      episodeCount: 58,
      category: 'New',
    ),
    Drama(
      id: 'found-you',
      title: 'Found You',
      coverUrl: 'https://picsum.photos/seed/found/360/540',
      episodeCount: 45,
      category: 'Asian',
    ),
  ];
}
