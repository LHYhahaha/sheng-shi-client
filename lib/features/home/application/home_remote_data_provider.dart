import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/domain/drama.dart';
import '../../../shared/media/media_resource.dart';
import '../domain/home_data.dart';
import 'home_data_controller.dart';

/// 远程首页数据转换为 UI 可用的分类和剧卡列表。
///
/// 这个 provider 将 HomeData 转换为 DramaCategory 和 Drama 列表，
/// 供 HomePage 使用。保留 HomeFeedController 的 mock 数据链路不动。
final homeRemoteDataProvider =
    Provider<HomeRemoteData?>((ref) {
  final homeDataState = ref.watch(homeDataControllerProvider);
  
  if (homeDataState.data == null) {
    return null;
  }

  final homeData = homeDataState.data!;
  
  // 将 HomeTab 转换为 DramaCategory
  final categories = homeData.tabs
      .map((tab) => DramaCategory(
        id: tab.id.toString(),
        title: tab.name,
      ))
      .toList(growable: false);

  return HomeRemoteData(
    categories: categories,
    tabs: homeData.tabs,
  );
});

/// 远程首页数据容器。
class HomeRemoteData {
  const HomeRemoteData({
    required this.categories,
    required this.tabs,
  });

  /// 分类列表。
  final List<DramaCategory> categories;

  /// 原始 tab 数据（用于获取对应 tab 的 dramas）。
  final List<HomeTab> tabs;

  /// 根据分类索引获取该分类的剧卡列表。
  List<Drama> getDramasForCategoryIndex(int index) {
    if (index < 0 || index >= tabs.length) {
      return const [];
    }

    return tabs[index].dramas
        .map((homeDrama) => Drama(
          id: homeDrama.id,
          title: homeDrama.title,
          coverAssetPath: Drama.fallbackCoverAssetPath,
          coverResource: MediaResource.network(
            homeDrama.coverUrl,
            aspectRatio: 0.7, // 标准剧卡比例
          ),
          viewCountLabel: _formatPlayCount(homeDrama.playCount),
          episodeCount: homeDrama.episodeTotal,
          categoryId: tabs[index].id.toString(),
          tags: homeDrama.tags,
          coverAspectRatio: 0.7,
          isExclusive: homeDrama.isVipOnly,
        ))
        .toList(growable: false);
  }

  /// 格式化播放次数为展示文案。
  static String _formatPlayCount(int playCount) {
    if (playCount < 1000) {
      return playCount.toString();
    }
    if (playCount < 1000000) {
      return '${(playCount / 1000).toStringAsFixed(1)}K';
    }
    return '${(playCount / 1000000).toStringAsFixed(1)}M';
  }
}
