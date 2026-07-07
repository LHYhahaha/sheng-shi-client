import 'language_option.dart';

abstract class LanguageOptionsRepository {
  Future<List<LanguageOption>> fetchGlobalLanguages();
}
