/// 通用弹窗结果类型。
enum AppModalResultKind { completed, cancelled, dismissed, failed }

/// 队列拒绝原因（O5）。
enum AppModalRejectReason { queueFull, systemDisabled }

/// 所有全局弹窗结果的基类；业务应使用具体子类型而非裸 bool/String。
sealed class AppModalResult {
  const AppModalResult(this.kind);

  final AppModalResultKind kind;
}

/// 通用确认弹窗结果。
sealed class ConfirmResult extends AppModalResult {
  const ConfirmResult(super.kind);

  static const ConfirmResult confirmed = _ConfirmResultConfirmed();

  static const ConfirmResult cancelled = _ConfirmResultCancelled();

  static const ConfirmResult dismissed = _ConfirmResultDismissed();

  bool get isConfirmed => kind == AppModalResultKind.completed;

  bool get isCancelled => kind == AppModalResultKind.cancelled;

  bool get isDismissed => kind == AppModalResultKind.dismissed;
}

final class _ConfirmResultConfirmed extends ConfirmResult {
  const _ConfirmResultConfirmed() : super(AppModalResultKind.completed);
}

final class _ConfirmResultCancelled extends ConfirmResult {
  const _ConfirmResultCancelled() : super(AppModalResultKind.cancelled);
}

final class _ConfirmResultDismissed extends ConfirmResult {
  const _ConfirmResultDismissed() : super(AppModalResultKind.dismissed);
}

/// 登录弹窗结果（O3）。成功态携带 primitive 元数据，避免 core import auth feature。
final class LoginModalResult extends AppModalResult {
  const LoginModalResult.success({
    required this.provider,
    required this.userId,
    required this.userNickname,
    this.accountLinked = false,
  }) : super(AppModalResultKind.completed);

  const LoginModalResult.cancelled()
    : provider = null,
      userId = null,
      userNickname = null,
      accountLinked = false,
      super(AppModalResultKind.cancelled);

  const LoginModalResult.dismissed()
    : provider = null,
      userId = null,
      userNickname = null,
      accountLinked = false,
      super(AppModalResultKind.dismissed);

  const LoginModalResult.failed()
    : provider = null,
      userId = null,
      userNickname = null,
      accountLinked = false,
      super(AppModalResultKind.failed);

  /// [AuthProviderType.name] when login succeeded.
  final String? provider;

  final String? userId;
  final String? userNickname;
  final bool accountLinked;

  bool get isSuccess => kind == AppModalResultKind.completed;

  bool get isCancelled => kind == AppModalResultKind.cancelled;

  bool get isDismissed => kind == AppModalResultKind.dismissed;

  bool get isFailed => kind == AppModalResultKind.failed;
}

/// 预留：金币解锁结果（O2）。
final class CoinUnlockModalResult extends AppModalResult {
  const CoinUnlockModalResult.completed() : super(AppModalResultKind.completed);

  const CoinUnlockModalResult.cancelled() : super(AppModalResultKind.cancelled);

  const CoinUnlockModalResult.dismissed() : super(AppModalResultKind.dismissed);
}

/// 预留：充值结果（O2）。
final class RechargeModalResult extends AppModalResult {
  const RechargeModalResult.completed() : super(AppModalResultKind.completed);

  const RechargeModalResult.cancelled() : super(AppModalResultKind.cancelled);
}

/// 预留：支付确认结果（O2）。
final class PaymentModalResult extends AppModalResult {
  const PaymentModalResult.completed() : super(AppModalResultKind.completed);

  const PaymentModalResult.cancelled() : super(AppModalResultKind.cancelled);

  const PaymentModalResult.failed() : super(AppModalResultKind.failed);
}

/// Store 购买确认弹窗结果（O4）。
final class StorePurchaseModalResult extends AppModalResult {
  const StorePurchaseModalResult.completed()
    : super(AppModalResultKind.completed);

  const StorePurchaseModalResult.cancelled()
    : super(AppModalResultKind.cancelled);

  const StorePurchaseModalResult.dismissed()
    : super(AppModalResultKind.dismissed);
}

/// Membership 购买确认弹窗结果（O4）。
final class MembershipPurchaseModalResult extends AppModalResult {
  const MembershipPurchaseModalResult.completed()
    : super(AppModalResultKind.completed);

  const MembershipPurchaseModalResult.cancelled()
    : super(AppModalResultKind.cancelled);

  const MembershipPurchaseModalResult.dismissed()
    : super(AppModalResultKind.dismissed);
}

/// 队列或系统策略拒绝展示（O5）。
final class AppModalRejectedResult extends AppModalResult {
  const AppModalRejectedResult(this.reason) : super(AppModalResultKind.failed);

  final AppModalRejectReason reason;

  bool get isQueueFull => reason == AppModalRejectReason.queueFull;

  bool get isSystemDisabled => reason == AppModalRejectReason.systemDisabled;
}

/// Presenter 未注册或展示失败（O5）；不阻塞后续队列。
final class AppModalPresentFailedResult extends AppModalResult {
  const AppModalPresentFailedResult() : super(AppModalResultKind.failed);
}
