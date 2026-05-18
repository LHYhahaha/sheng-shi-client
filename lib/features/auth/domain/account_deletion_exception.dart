/// 账号注销被服务端/ mock 拒绝时的业务错误（如余额不为 0、仍为会员）。
class AccountDeletionRejectedException implements Exception {
  const AccountDeletionRejectedException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'AccountDeletionRejectedException($code): $message';
}
