import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/drama_repository.dart';
import 'mock_drama_repository.dart';

final dramaRepositoryProvider = Provider<DramaRepository>((ref) {
  return const MockDramaRepository();
});
