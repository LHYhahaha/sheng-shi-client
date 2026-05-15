import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/drama_repository.dart';
import 'mock_drama_repository.dart';

final dramaRepositoryProvider = Provider<DramaRepository>((ref) {
  // 首页数据源统一从 provider 注入，方便 mock/真实接口切换。页面不要直接 new
  // repository，否则 startup preload、分页测试和后续接口替换会分叉。
  return const MockDramaRepository();
});
