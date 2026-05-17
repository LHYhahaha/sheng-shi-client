/// 标准 API envelope 构造（Home/Drama dry run 与 remote contract 测试）。
Map<String, Object?> apiEnvelopeSuccess(Object? data) => {
  'code': 0,
  'message': 'success',
  'data': data,
};

Map<String, Object?> apiEnvelopeError(
  int code, {
  String message = 'error',
  Object? data,
}) => {'code': code, 'message': message, 'data': data};
