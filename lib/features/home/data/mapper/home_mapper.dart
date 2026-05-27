import '../../domain/home_data.dart';
import '../dto/home_response_dto.dart';

/// 首页数据映射器。
///
/// 将 DTO 转换为 domain model。
class HomeMapper {
  const HomeMapper();

  /// 将首页响应 DTO 映射为首页数据。
  HomeData mapHomeData(HomeResponseDto dto) {
    return HomeData(
      id: dto.id,
      name: dto.name,
      status: dto.status,
      tabs: dto.tabs.map(_mapTab).toList(growable: false),
    );
  }

  HomeTab _mapTab(HomeTabDto dto) {
    return HomeTab(
      id: dto.id,
      name: dto.name,
      flag: dto.flag,
      sort: dto.sort,
      status: dto.status,
      dramas: dto.dramas.map(_mapDrama).toList(growable: false),
    );
  }

  HomeDrama _mapDrama(HomeDramaDto dto) {
    return HomeDrama(
      id: dto.id.toString(),
      sort: dto.sort,
      coverUrl: dto.coverUrl,
      title: dto.title,
      summary: dto.summary,
      playCount: dto.playCount,
      trailerEpisodeNum: dto.trailerEpisodeNum,
      isVipOnly: dto.isVipOnly == 1,
      status: dto.status,
      episodeTotal: dto.episodeTotal,
    );
  }
}
