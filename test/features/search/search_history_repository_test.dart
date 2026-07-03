import 'package:drama_client/features/search/data/shared_preferences_search_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores search history separately for each user', () async {
    final repository = SharedPreferencesSearchHistoryRepository();

    await repository.write('user:1', const ['alpha', 'beta']);
    await repository.write('user:2', const ['gamma']);

    expect(await repository.read('user:1'), ['alpha', 'beta']);
    expect(await repository.read('user:2'), ['gamma']);
  });

  test('clears only the selected user history', () async {
    final repository = SharedPreferencesSearchHistoryRepository();
    await repository.write('user:1', const ['alpha']);
    await repository.write('user:2', const ['beta']);

    await repository.clear('user:1');

    expect(await repository.read('user:1'), isEmpty);
    expect(await repository.read('user:2'), ['beta']);
  });
}
