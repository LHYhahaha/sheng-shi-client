import '../domain/player_content.dart';
import 'mapper/player_content_mapper.dart';
import 'remote/player_remote_data_source.dart';

/// 播放详情远程 repository。
///
/// 通过 fetchDramaDetail 接口获取完整的短剧详情（包含所有集数和字幕信息）。
class RemotePlayerContentRepository implements PlayerContentRepository {
  const RemotePlayerContentRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _contentMapper = contentMapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerContentMapper _contentMapper;

  @override
  Future<PlayerContent> getPlayerContent({required String dramaId}) async {
    final dramaIdInt = int.tryParse(dramaId) ?? 0;
    final dto = await _remoteDataSource.fetchDramaDetail(dramaId: dramaIdInt);
    return _contentMapper.mapContent(dto);
  }
}
