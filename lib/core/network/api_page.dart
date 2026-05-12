class ApiPage<T> {
  const ApiPage({required this.items, required this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;
}
