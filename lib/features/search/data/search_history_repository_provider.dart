import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_history_repository.dart';
import 'shared_preferences_search_history_repository.dart';

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SharedPreferencesSearchHistoryRepository();
});
