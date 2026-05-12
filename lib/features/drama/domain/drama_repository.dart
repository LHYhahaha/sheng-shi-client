import 'drama.dart';

abstract interface class DramaRepository {
  Future<List<DramaCategory>> listHomeCategories();

  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  });
}
