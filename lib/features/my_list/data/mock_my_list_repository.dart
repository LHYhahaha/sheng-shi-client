import '../domain/my_list_item.dart';
import '../domain/my_list_repository.dart';

class MockMyListRepository implements MyListRepository {
  MockMyListRepository()
    : _collectionItems = List.of([]),
      _playItems = List.of([]);

  late final List<MyListItem> _collectionItems;
  late final List<MyListItem> _playItems;

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return switch (tab) {
      MyListTab.collection => List.unmodifiable(_collectionItems),
      MyListTab.play => List.unmodifiable(_playItems),
    };
  }

  @override
  Future<void> deleteFavorite({required int dramaId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _collectionItems.removeWhere((item) => item.dramaId == dramaId);
  }

  @override
  Future<void> deleteFavorites({required List<int> dramaIds}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _collectionItems.removeWhere((item) => dramaIds.contains(item.dramaId));
  }

  @override
  Future<void> deletePlayHistory({required int historyId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _playItems.removeWhere((item) => item.dramaId == historyId);
  }

  @override
  Future<void> deletePlayHistories({required List<int> historyIds}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _playItems.removeWhere((item) => historyIds.contains(item.dramaId));
  }
}

const _intro =
    'IntroductionIntroductionIntroductionIntroductionIntroductionIntroductionIntroductionIntroduc...';

final _collectionItems = [
  const MyListItem(
    dramaId: 1,
    title: 'Raja Iblis Hidup Kembali',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_1.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  const MyListItem(
    dramaId: 2,
    title: 'Pulang Malam Mengejutkan',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_2.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  const MyListItem(
    dramaId: 3,
    title: 'Naga Tersembunyi Dewa Perang',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_3.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
];

final _playItems = [
  const MyListItem(
    dramaId: 4,
    title: 'EP. 1',
    introduction: '',
    coverAssetPath: 'assets/images/my_list/cover_1.png',
    currentEpisode: 1,
    episodeCount: 0,
  ),
  const MyListItem(
    dramaId: 5,
    title: 'EP. 2',
    introduction: '',
    coverAssetPath: 'assets/images/my_list/cover_2.png',
    currentEpisode: 2,
    episodeCount: 0,
  ),
  const MyListItem(
    dramaId: 6,
    title: 'EP. 3',
    introduction: '',
    coverAssetPath: 'assets/images/my_list/cover_3.png',
    currentEpisode: 3,
    episodeCount: 0,
  ),
];
