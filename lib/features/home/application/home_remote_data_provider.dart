import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/compact_count_formatter.dart';
import '../../../shared/media/media_resource.dart';
import '../../drama/domain/drama.dart';
import '../domain/home_data.dart';
import 'home_data_controller.dart';

final homeRemoteDataProvider = Provider<HomeRemoteData?>((ref) {
  final homeDataState = ref.watch(homeDataControllerProvider);
  final homeData = homeDataState.data;

  if (homeData == null) {
    return null;
  }

  final categories = homeData.tabs
      .map((tab) => DramaCategory(id: tab.id.toString(), title: tab.name))
      .toList(growable: false);

  return HomeRemoteData(categories: categories, tabs: homeData.tabs);
});

class HomeRemoteData {
  const HomeRemoteData({required this.categories, required this.tabs});

  final List<DramaCategory> categories;
  final List<HomeTab> tabs;

  HomeTab? getTabForCategoryIndex(int index) {
    if (index < 0 || index >= tabs.length) {
      return null;
    }
    return tabs[index];
  }

  List<Drama> getDramasForCategoryIndex(int index) {
    final tab = getTabForCategoryIndex(index);
    if (tab == null) {
      return const [];
    }

    return tab.dramas
        .map(
          (homeDrama) => Drama(
            id: homeDrama.id,
            title: homeDrama.title,
            coverAssetPath: Drama.fallbackCoverAssetPath,
            coverResource: MediaResource.network(
              homeDrama.coverUrl,
              aspectRatio: 0.7,
            ),
            viewCountLabel: formatCompactCount(
              homeDrama.playCount,
              emptyWhenNonPositive: true,
            ),
            episodeCount: homeDrama.episodeTotal,
            categoryId: tab.id.toString(),
            tags: homeDrama.tags,
            coverAspectRatio: 0.7,
            isExclusive: homeDrama.isVipOnly,
            watchProgress: homeDrama.watchProgress == null
                ? null
                : DramaWatchProgress(
                    episodeId: homeDrama.watchProgress!.episodeId.toString(),
                    episodeNo: homeDrama.watchProgress!.episodeNo,
                    positionSeconds: homeDrama.watchProgress!.positionSeconds,
                    durationSeconds: homeDrama.watchProgress!.durationSeconds,
                  ),
          ),
        )
        .toList(growable: false);
  }
}
