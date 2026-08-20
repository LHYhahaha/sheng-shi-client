import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/runtime_supported_locales_provider.dart';
import '../data/language_options_repository_provider.dart';
import '../domain/language_option.dart';

final languageOptionsProvider =
    FutureProvider.autoDispose<List<LanguageOption>>((ref) async {
      final repository = ref.watch(languageOptionsRepositoryProvider);
      final options = await repository.fetchGlobalLanguages();
      ref
          .read(runtimeSupportedLocalesProvider.notifier)
          .registerLanguageCodes(options.map((option) => option.code));
      return options;
    });
