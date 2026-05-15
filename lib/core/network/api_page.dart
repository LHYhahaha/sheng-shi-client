/// API 分页结果。
///
/// 使用 token 而不是页码，是为了兼容后端按推荐流、时间线或游标分页。调用方不要
/// 根据 items 长度自行推断是否有下一页，应以 `nextPageToken` 为准。
class ApiPage<T> {
  const ApiPage({required this.items, required this.nextPageToken});

  /// 当前页数据。
  final List<T> items;

  /// 下一页游标。
  ///
  /// null 表示没有更多；调用方不要自己生成 token。
  final String? nextPageToken;
}
