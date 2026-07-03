abstract interface class SearchHistoryRepository {
  Future<List<String>> read(String userKey);

  Future<void> write(String userKey, List<String> items);

  Future<void> clear(String userKey);
}
