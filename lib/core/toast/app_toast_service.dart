import 'app_center_toast.dart';

enum AppToastKind { success, error, info, warning }

/// 全局 toast 抽象；业务层只依赖此接口，不直接引用第三方 toast 包。
abstract class AppToastService {
  void success(String message);

  void error(String message);

  void info(String message);

  void warning(String message);
}

/// 所有业务提示统一使用居中 Toast。
class BotAppToastService implements AppToastService {
  const BotAppToastService();

  @override
  void success(String message) => showAppCenterToast(message);

  @override
  void error(String message) => showAppCenterToast(message);

  @override
  void info(String message) => showAppCenterToast(message);

  @override
  void warning(String message) => showAppCenterToast(message);
}
