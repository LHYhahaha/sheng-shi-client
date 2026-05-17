import 'app_modal_policy.dart';
import 'app_modal_source.dart';

/// 弹窗业务类型；O2+ 逐步扩展具体 payload。
enum AppModalType {
  confirm,
  login,
  coinUnlock,
  recharge,
  paymentConfirm,
  membershipPurchase,
  storeConfirm,
  walletRestore,
  blockingUpgrade,
  unknown,
}

/// 全局弹窗请求基类。
sealed class AppModalRequest {
  const AppModalRequest({
    required this.requestId,
    required this.source,
    required this.priority,
    required this.dismissPolicy,
    required this.createdAt,
    required this.type,
  });

  final String requestId;
  final AppModalSource source;
  final AppModalPriority priority;
  final AppModalDismissPolicy dismissPolicy;
  final DateTime createdAt;
  final AppModalType type;
}

/// 通用确认弹窗请求（O1 skeleton）。
final class ConfirmModalRequest extends AppModalRequest {
  ConfirmModalRequest({
    required super.requestId,
    required super.source,
    super.priority = AppModalPriority.normal,
    super.dismissPolicy = AppModalDismissPolicy.standard,
    DateTime? createdAt,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  }) : super(
         type: AppModalType.confirm,
         createdAt: createdAt ?? DateTime.now(),
       );

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
}
