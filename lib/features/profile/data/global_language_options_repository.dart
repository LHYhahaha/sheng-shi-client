import '../domain/language_option.dart';
import '../domain/language_options_repository.dart';
import 'remote/global_language_remote_data_source.dart';

class GlobalLanguageOptionsRepository implements LanguageOptionsRepository {
  const GlobalLanguageOptionsRepository({required this.remoteDataSource});

  final GlobalLanguageRemoteDataSource remoteDataSource;

  @override
  Future<List<LanguageOption>> fetchGlobalLanguages() {
    return remoteDataSource.fetchGlobalLanguages();
  }
}
