import '../../domain/drama.dart';
import '../../../../shared/media/media_resource.dart';
import '../dto/drama_category_dto.dart';
import '../dto/drama_dto.dart';
import '../dto/drama_feed_page_dto.dart';

/// Home/Drama 远程 DTO 到 domain model 的映射层。
class DramaMapper {
  const DramaMapper();

  static const _displayTitleFallback = 'Untitled';

  DramaCategory mapCategory(DramaCategoryDto dto) {
    return DramaCategory(
      id: dto.id,
      title: dto.title.isEmpty ? _displayTitleFallback : dto.title,
    );
  }

  Drama mapDrama(DramaDto dto) {
    final coverUrl = dto.coverUrl ?? dto.posterUrl;
    final aspectRatio = dto.coverAspectRatio ?? 171 / 226;

    return Drama(
      id: dto.dramaId,
      title: dto.title ?? _displayTitleFallback,
      coverAssetPath: Drama.fallbackCoverAssetPath,
      coverResource: coverUrl == null || coverUrl.isEmpty
          ? MediaResource.asset(
              Drama.fallbackCoverAssetPath,
              aspectRatio: aspectRatio,
            )
          : MediaResource.network(coverUrl, aspectRatio: aspectRatio),
      viewCountLabel: _formatViewCount(dto.viewCount),
      episodeCount: dto.episodeCount,
      categoryId: dto.categoryIds.isNotEmpty ? dto.categoryIds.first : '',
      tags: dto.tags,
      coverAspectRatio: aspectRatio,
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
      if (thousands >= 999.95) {
        return '1.0M';
      }
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)} K';
    }
    return '$viewCount';
  }
}
