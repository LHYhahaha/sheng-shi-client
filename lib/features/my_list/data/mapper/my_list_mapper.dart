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
      id: _favoriteId(dto),
      title: dto.title ?? _displayTitleFallback,
      introduction: dto.description ?? '',
      coverAssetPath: fallbackAsset,
      coverResource: _coverResource(dto.coverUrl, dto.coverAspectRatio),
      currentEpisode: dto.latestEpisodeNumber ?? 1,
      episodeCount: dto.totalEpisodes,
      dramaId: dto.dramaId != 0 ? dto.dramaId : null,
    );
  }

  MyListItem mapPlayHistory(PlayHistoryItemDto dto) {
    final fallbackAsset = MyListItem.fallbackCoverAssetPath;
    return MyListItem(
      id: _historyId(dto),
      title: 'EP. ${dto.episodeNo}',
      introduction: '',
      coverAssetPath: fallbackAsset,
      currentEpisode: dto.episodeNo,
      episodeCount: 0,
      dramaId: dto.dramaId,
      episodeId: dto.episodeId,
      historyId: dto.historyId,
    );
  }

  String favoriteDeleteDramaId(MyListItem item) {
    final id = item.id.startsWith('favorite:')
        ? item.id.substring('favorite:'.length)
        : item.id;
    return id;
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
    if (dto.dramaId != 0) return dto.dramaId.toString();
    return dto.favoriteId ?? '';
  }

  String _historyId(PlayHistoryItemDto dto) {
    return 'history:${dto.dramaId}:${dto.episodeId}';
  }
}
