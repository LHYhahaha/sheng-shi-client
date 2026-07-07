import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../../domain/language_option.dart';

class GlobalLanguageRemoteDataSource {
  const GlobalLanguageRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<LanguageOption>> fetchGlobalLanguages() {
    return _apiClient.get<List<LanguageOption>>(
      '/api/home/language/global',
      decoder: _parseLanguageOptions,
      authPolicy: ApiAuthPolicy.required,
    );
  }

  static List<LanguageOption> _parseLanguageOptions(Object? data) {
    final map = JsonFieldParser.requireMap(
      data,
      dtoName: 'GlobalLanguageOptions',
    );
    return map.entries
        .where((entry) => entry.key.isNotEmpty && entry.value is String)
        .map(
          (entry) =>
              LanguageOption(label: entry.key, code: entry.value! as String),
        )
        .where((option) => option.code.isNotEmpty)
        .toList(growable: false);
  }
}
