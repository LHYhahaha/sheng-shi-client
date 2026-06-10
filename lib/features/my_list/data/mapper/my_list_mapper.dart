import '../../../../shared/media/media_resource.dart';
import '../../domain/my_list_item.dart';
import '../dto/favorite_item_dto.dart';
import '../dto/play_history_item_dto.dart';

/// My list DTO 到 domain 的 mapper。
///
/// remote coverUrl 会映射到 MediaResource.network，但当前 MyListPage 仍用
/// coverAssetPath 渲染旧 UI，所以 mapper 同时提供 asset fallback。不要把远程 URL
/// 伪装成 asset path。
class MyListMapper {
  const MyListMapper();

  static const _displayTitleFallback = 'Untitled';

  MyListItem mapFavorite(FavoriteItemDto dto) {
    final fallbackAsset = MyListItem.fallbackCoverAssetPath;
    return MyListItem(
      dramaId: dto.dramaId,
      title: dto.title ?? _displayTitleFallback,
      introduction: dto.description ?? '',
      coverAssetPath: dto.coverUrl ?? fallbackAsset,
      coverResource: _coverResource(dto.coverUrl, dto.coverAspectRatio),
      currentEpisode: dto.latestEpisodeNumber ?? 1,
      episodeCount: dto.totalEpisodes,
    );
  }

  MyListItem mapPlayHistory(PlayHistoryItemDto dto) {
    final fallbackAsset = MyListItem.fallbackCoverAssetPath;
    return MyListItem(
      dramaId: dto.dramaId,
      title: dto.title ?? _displayTitleFallback,
      introduction: dto.summary ?? '',
      coverAssetPath: dto.coverUrl ?? fallbackAsset,
      coverResource: _coverResource(dto.coverUrl, null),
      currentEpisode: dto.episodeNo,
      episodeCount: dto.episodeTotal ?? 0,
      episodeId: dto.episodeId,
      watchSecond: dto.watchSecond,
    );
  }

  MediaResource _coverResource(String? coverUrl, double? aspectRatio) {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return MediaResource.network(coverUrl, aspectRatio: aspectRatio);
    }
    return MediaResource.asset(
      MyListItem.fallbackCoverAssetPath,
      aspectRatio: aspectRatio,
    );
  }
}
