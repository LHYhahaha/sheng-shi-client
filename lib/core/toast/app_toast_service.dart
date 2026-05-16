import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'app_toast_style.dart';

enum AppToastKind { success, error, info, warning }

/// 全局 toast 抽象；业务层只依赖此接口，不直接引用第三方 toast 包。
abstract class AppToastService {
  void success(String message);

  void error(String message);

  void info(String message);

  void warning(String message);
}

/// 基于 bot_toast 的默认实现。
class BotAppToastService implements AppToastService {
  const BotAppToastService();

  @override
  void success(String message) => _show(message, AppToastKind.success);

  @override
  void error(String message) => _show(message, AppToastKind.error);

  @override
  void info(String message) => _show(message, AppToastKind.info);

  @override
  void warning(String message) => _show(message, AppToastKind.warning);

  void _show(String message, AppToastKind kind) {
    BotToast.showCustomNotification(
      align: Alignment.topCenter,
      duration: AppToastStyle.displayDuration,
      onlyOne: true,
      crossPage: true,
      backButtonBehavior: BackButtonBehavior.ignore,
      toastBuilder: (cancel) {
        return _AppToastBanner(
          key: ValueKey('app_toast_${kind.name}'),
          message: message,
          kind: kind,
        );
      },
    );
  }
}

class _AppToastBanner extends StatelessWidget {
  const _AppToastBanner({required this.message, required this.kind, super.key});

  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppToastStyle.marginFor(context),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppToastStyle.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(kind), color: _iconColorFor(kind), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppToastStyle.messageStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AppToastKind kind) {
    return switch (kind) {
      AppToastKind.success => Icons.check_circle_rounded,
      AppToastKind.error => Icons.error_rounded,
      AppToastKind.info => Icons.info_rounded,
      AppToastKind.warning => Icons.warning_rounded,
    };
  }

  Color _iconColorFor(AppToastKind kind) {
    return switch (kind) {
      AppToastKind.success => AppToastStyle.successIconColor,
      AppToastKind.error => AppToastStyle.errorIconColor,
      AppToastKind.info => AppToastStyle.infoIconColor,
      AppToastKind.warning => AppToastStyle.warningIconColor,
    };
  }
}
