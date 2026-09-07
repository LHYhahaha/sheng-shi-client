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

/// 确认弹窗的视觉样式。
enum ConfirmModalStyle {
  /// 应用内通用确认弹窗。
  standard,

  /// 灰底、底部等宽双按钮的轻量确认弹窗。
  compact,

  /// 搜索历史清空确认弹窗（保留原有调用兼容）。
  searchHistoryClear,
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
    this.analyticsPopupShowParameters,
  });

  final String requestId;
  final AppModalSource source;
  final AppModalPriority priority;
  final AppModalDismissPolicy dismissPolicy;
  final DateTime createdAt;
  final AppModalType type;

  /// 非空时，该请求被真正展示后会自动上报 `popup_show`。
  ///
  /// 参数由 feature 提供，避免 core 依赖具体业务 payload 类型。
  final Map<String, Object?>? analyticsPopupShowParameters;
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
    this.style = ConfirmModalStyle.standard,
  }) : super(
         type: AppModalType.confirm,
         createdAt: createdAt ?? DateTime.now(),
       );

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final ConfirmModalStyle style;
}

/// Feature 弹窗信封：payload 在 feature 层定义类型，core 不 import feature。
final class FeatureAppModalRequest extends AppModalRequest {
  FeatureAppModalRequest({
    required super.requestId,
    required super.source,
    required this.channel,
    this.payload,
    super.priority = AppModalPriority.normal,
    super.dismissPolicy = AppModalDismissPolicy.standard,
    DateTime? createdAt,
    super.type = AppModalType.unknown,
    super.analyticsPopupShowParameters,
    this.stackOnCurrent = false,
  }) : super(createdAt: createdAt ?? DateTime.now());

  final String channel;
  final Object? payload;

  /// 在已有 current 展示时叠层（如充值大抽屉上的 Payment Method），不入 pending 队列。
  final bool stackOnCurrent;
}
