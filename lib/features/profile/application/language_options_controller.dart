import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/language_options_repository_provider.dart';
import '../domain/language_option.dart';

const fallbackLanguageOptions = <LanguageOption>[
  LanguageOption(label: 'English', code: 'en'),
  LanguageOption(label: '中文', code: 'zh'),
];

final languageOptionsProvider = FutureProvider<List<LanguageOption>>((
  ref,
) async {
  final repository = ref.watch(languageOptionsRepositoryProvider);
  final options = await repository.fetchGlobalLanguages();
  if (options.isEmpty) {
    return fallbackLanguageOptions;
  }
  return options;
});
