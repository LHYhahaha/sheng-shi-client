/// 远程 DTO / mapper 字段解析失败。
///
/// 用于 strict required 字段、unknown enum、错误 payload 类型等场景。
/// 不携带 token、完整 URL 等敏感值，仅记录 dto 名、字段名与原因。
class ApiMappingException implements Exception {
  const ApiMappingException({
    required this.dtoName,
    required this.field,
    required this.reason,
  });

  final String dtoName;
  final String field;
  final String reason;

  @override
  String toString() => 'ApiMappingException($dtoName.$field: $reason)';
}
