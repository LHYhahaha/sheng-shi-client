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

  MyListItem mapFavorite(FavoriteItemDto dto) {
    final fallbackAsset = MyListItem.fallbackCoverAssetPath;
    return MyListItem(
      id: _favoriteId(dto),
      title: dto.title,
      introduction: dto.description ?? '',
      coverAssetPath: fallbackAsset,
      coverResource: _coverResource(dto.coverUrl, dto.coverAspectRatio),
      currentEpisode: dto.latestEpisodeNumber ?? 1,
      episodeCount: dto.totalEpisodes,
    );
  }

  MyListItem mapPlayHistory(PlayHistoryItemDto dto) {
    final fallbackAsset = MyListItem.fallbackCoverAssetPath;
    return MyListItem(
      id: _historyId(dto),
      title: dto.title,
      introduction: dto.description ?? '',
      coverAssetPath: fallbackAsset,
      coverResource: _coverResource(dto.coverUrl, dto.coverAspectRatio),
      currentEpisode: dto.episodeNumber,
      episodeCount: dto.totalEpisodes,
    );
  }

  String favoriteDeleteDramaId(MyListItem item) {
    return item.id.startsWith('favorite:')
        ? item.id.substring('favorite:'.length)
        : item.id;
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

  String _favoriteId(FavoriteItemDto dto) {
    if (dto.dramaId.isNotEmpty) return dto.dramaId;
    return dto.favoriteId ?? '';
  }

  String _historyId(PlayHistoryItemDto dto) {
    if (dto.historyId != null && dto.historyId!.isNotEmpty) {
      return dto.historyId!;
    }
    return 'history:${dto.dramaId}:${dto.episodeId}';
  }
}
