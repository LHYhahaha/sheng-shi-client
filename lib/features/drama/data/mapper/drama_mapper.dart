import '../../domain/drama.dart';
import '../dto/drama_category_dto.dart';
import '../dto/drama_dto.dart';
import '../dto/drama_feed_page_dto.dart';

/// Home/Drama 远程 DTO 到 domain model 的映射层。
///
/// mapper 是 mock 到真实 API 迁移的隔离带：接口字段可以变化，但 HomeFeedController
/// 和页面仍只依赖稳定的 domain model。后续引入 MediaImage/MediaResource 时，也应在
/// 这里完成 coverUrl 到可渲染资源的转换。
class DramaMapper {
  const DramaMapper();

  DramaCategory mapCategory(DramaCategoryDto dto) {
    return DramaCategory(id: dto.id, title: dto.title);
  }

  Drama mapDrama(DramaDto dto) {
    return Drama(
      id: dto.dramaId,
      title: dto.title,
      // TODO(api): 当前 domain 只有 coverAssetPath 字段，先临时承载 remote coverUrl。
      // 接真实图片缓存/占位策略前，应引入 MediaImage/MediaResource，避免 UI 判断 asset/url。
      coverAssetPath: dto.coverUrl ?? dto.posterUrl ?? '',
      viewCountLabel: dto.viewCountLabel ?? _formatViewCount(dto.viewCount),
      episodeCount: dto.episodeCount,
      categoryId: dto.categoryIds.isNotEmpty ? dto.categoryIds.first : '',
      tags: dto.tags,
      coverAspectRatio: dto.coverAspectRatio ?? 171 / 226,
      isExclusive: dto.badges.any(
        (badge) => badge.toLowerCase() == 'exclusive',
      ),
    );
  }

  DramaFeedPage mapFeedPage(DramaFeedPageDto dto) {
    return DramaFeedPage(
      items: dto.items.map(mapDrama).toList(growable: false),
      nextPageToken: dto.nextPageToken,
    );
  }

  String _formatViewCount(int? viewCount) {
    if (viewCount == null || viewCount <= 0) {
      return '';
    }
    if (viewCount >= 1000000) {
      final millions = viewCount / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)} M';
    }
    if (viewCount >= 1000) {
      final thousands = viewCount / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)} K';
    }
    return '$viewCount';
  }
}
