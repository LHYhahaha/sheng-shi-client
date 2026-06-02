import '../domain/player_content.dart';
import 'mapper/player_content_mapper.dart';
import 'mapper/player_recommendation_mapper.dart';
import 'remote/player_remote_data_source.dart';

/// 播放详情远程 repository。
///
/// 通过 fetchDramaDetail 接口获取完整的短剧详情（包含所有集数和字幕信息）。
class RemotePlayerContentRepository implements PlayerContentRepository {
  const RemotePlayerContentRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
    PlayerRecommendationMapper recommendationMapper = const PlayerRecommendationMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _contentMapper = contentMapper,
       _recommendationMapper = recommendationMapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerContentMapper _contentMapper;
  final PlayerRecommendationMapper _recommendationMapper;

  @override
  Future<PlayerContent> getPlayerContent({required String dramaId}) async {
    final dramaIdInt = int.tryParse(dramaId) ?? 0;
    final dto = await _remoteDataSource.fetchDramaDetail(dramaId: dramaIdInt);
    
    // 并行获取推荐列表
    try {
      final recommendationDtos = await _remoteDataSource.fetchRecommendations(
        dramaId: dramaIdInt,
        tagIds: dto.tagIds,
      );
      final recommendations = _recommendationMapper.mapRecommendations(recommendationDtos);
      
      return _contentMapper.mapContent(dto, recommendations: recommendations);
    } catch (e) {
      // 如果推荐获取失败，仍然返回内容（不带推荐）
      return _contentMapper.mapContent(dto);
    }
  }
}

