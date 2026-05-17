import 'app_modal_result.dart';
import 'app_modal_service.dart';
import 'app_modal_source.dart';

/// 已迁移到 [AppModalService] 的阻塞式业务弹窗来源（O2–O4）。
///
/// session cleanup 时统一关闭，避免 token 失效后仍显示购买/解锁/登录弹窗。
const List<AppModalSource> blockingBusinessModalSources = [
  AppModalSource.player,
  AppModalSource.store,
  AppModalSource.membership,
  AppModalSource.auth,
];

/// 关闭所有阻塞式业务 modal 并清空 pending 队列（不展示队列中下一项）。
void dismissAllBlockingBusinessModals(
  AppModalService modalService, {
  AppModalResult result = ConfirmResult.dismissed,
}) {
  modalService.dismissAllBlockingBusinessModals(result: result);
}
