import '../domain/my_list_item.dart';
import '../domain/my_list_repository.dart';

class MockMyListRepository implements MyListRepository {
  const MockMyListRepository();

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return switch (tab) {
      MyListTab.collection => _collectionItems,
      MyListTab.play => _playItems,
    };
  }
}

const _intro =
    'IntroductionIntroductionIntroductionIntroductionIntroductionIntroductionIntroductionIntroduc...';

const _collectionItems = [
  MyListItem(
    id: 'collection-raja-iblis',
    title: 'Raja Iblis Hidup Kembali',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_1.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  MyListItem(
    id: 'collection-pulang-malam',
    title: 'Pulang Malam Mengejutkan',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_2.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  MyListItem(
    id: 'collection-naga-tersembunyi',
    title: 'Naga Tersembunyi Dewa Perang',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_3.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
];

const _playItems = [
  MyListItem(
    id: 'play-raja-iblis',
    title: 'Raja Iblis Hidup Kembali',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_1.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  MyListItem(
    id: 'play-pulang-malam',
    title: 'Pulang Malam Mengejutkan',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_2.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
  MyListItem(
    id: 'play-naga-tersembunyi',
    title: 'Naga Tersembunyi Dewa Perang',
    introduction: _intro,
    coverAssetPath: 'assets/images/my_list/cover_3.png',
    currentEpisode: 1,
    episodeCount: 52,
  ),
];
