import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mapper/player_recommendation_mapper.dart';
import '../data/player_remote_data_source_provider.dart';
import '../domain/player_content.dart';

/// 获取推荐列表的 provider。
///
/// 根据剧 ID 和 tag IDs 从远程 API 获取推荐列表，并转换为 domain 模型。
/// 注意：这个 provider 需要 tag_ids，通常在获取详情后才能获得。
/// 推荐在 RemotePlayerContentRepository 中并行获取。
final playerRecommendationProvider = FutureProvider.family<
  List<PlayerRecommendation>,
  ({String dramaId, List<int> tagIds})
>((ref, params) async {
  final dataSource = ref.watch(playerRemoteDataSourceProvider);
  final dramaIdInt = int.tryParse(params.dramaId) ?? 0;
  final dtos = await dataSource.fetchRecommendations(
    dramaId: dramaIdInt,
    tagIds: params.tagIds,
  );
  final mapper = const PlayerRecommendationMapper();
  return mapper.mapRecommendations(dtos);
});
