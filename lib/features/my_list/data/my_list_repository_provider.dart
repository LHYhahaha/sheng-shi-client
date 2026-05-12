import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/my_list_repository.dart';
import 'mock_my_list_repository.dart';

final myListRepositoryProvider = Provider<MyListRepository>((ref) {
  return const MockMyListRepository();
});
