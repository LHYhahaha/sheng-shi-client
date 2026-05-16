import 'package:drama_client/core/toast/app_toast_service.dart';

/// 测试用 toast 记录器，避免 widget 测试被 bot_toast 定时器污染。
class RecordingAppToastService implements AppToastService {
  final List<String> successes = [];
  final List<String> errors = [];
  final List<String> infos = [];
  final List<String> warnings = [];

  @override
  void success(String message) => successes.add(message);

  @override
  void error(String message) => errors.add(message);

  @override
  void info(String message) => infos.add(message);

  @override
  void warning(String message) => warnings.add(message);

  void clear() {
    successes.clear();
    errors.clear();
    infos.clear();
    warnings.clear();
  }
}
