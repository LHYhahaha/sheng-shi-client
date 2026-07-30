import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../app/router/route_paths.dart';
import '../../l10n/app_localizations.dart';
import 'account_ban_controller.dart';

/// 根级封禁遮罩。它覆盖所有业务内容，只保留反馈与退出两个入口。
class AccountBannedOverlay extends ConsumerWidget {
  const AccountBannedOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountBanControllerProvider);
    if (!state.isBanned || state.isViewingFeedback) {
      return child;
    }

    final l10n = context.l10n;
    return Stack(
      children: [
        child,
        const Positioned.fill(child: ColoredBox(color: Color(0xE6000000))),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Text(
                      l10n.appAccountBannedDialogMessage,
                      key: const ValueKey('account_banned_message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF5A5A5A)),
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: const ValueKey('account_banned_exit'),
                            onPressed: SystemNavigator.pop,
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              l10n.appAccountBannedActionExit,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0xFF5A5A5A),
                        ),
                        Expanded(
                          child: TextButton(
                            key: const ValueKey('account_banned_feedback'),
                            onPressed: () {
                              ref
                                  .read(accountBanControllerProvider.notifier)
                                  .openFeedback();
                              // 此遮罩由 MaterialApp.router 的 builder 创建，位于
                              // GoRouter 的 context 之外，不能使用 context.push。
                              ref
                                  .read(appRouterProvider)
                                  .push(RoutePaths.profileFeedback);
                            },
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              l10n.appAccountBannedActionFeedback,
                              style: const TextStyle(color: Color(0xFFFF4D5A)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
