import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_content.dart';
import 'mock_player_content_repository.dart';

final playerContentRepositoryProvider = Provider<PlayerContentRepository>((
  ref,
) {
  // 内容详情统一入口。播放器页面只依赖 repository 接口，后续接真实详情/推荐接口时
  // 不需要改 presentation 层。
  return const MockPlayerContentRepository();
});
