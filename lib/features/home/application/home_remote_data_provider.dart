import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            viewCountLabel: _formatPlayCount(homeDrama.playCount),
            episodeCount: homeDrama.episodeTotal,
            categoryId: tab.id.toString(),
            tags: homeDrama.tags,
            coverAspectRatio: 0.7,
            isExclusive: homeDrama.isVipOnly,
          ),
        )
        .toList(growable: false);
  }

  static String _formatPlayCount(int playCount) {
    if (playCount <= 0) {
      return '';
    }
    if (playCount >= 1000000) {
      final millions = playCount / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)} M';
    }
    if (playCount >= 1000) {
      final thousands = playCount / 1000;
      if (thousands >= 999.95) {
        return '1.0M';
      }
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)} K';
    }
    return '$playCount';
  }
}
