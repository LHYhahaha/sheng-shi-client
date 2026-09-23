import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/modal/app_modal_result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_login_modal_content.dart';
import 'auth_modal_payloads.dart';
import '../../domain/auth_session.dart';

/// Auth 登录全局 bottom sheet（复用 [AuthLoginModalContent]）。
class AuthLoginModalSheet extends ConsumerStatefulWidget {
  const AuthLoginModalSheet({required this.payload, super.key});

  final AuthLoginModalPayload payload;

  @override
  ConsumerState<AuthLoginModalSheet> createState() =>
      _AuthLoginModalSheetState();
}

class _AuthLoginModalSheetState extends ConsumerState<AuthLoginModalSheet> {
  ProviderSubscription? _providerSubscription;

  @override
  void initState() {
    super.initState();

    // 使用 listenManual 监听 auth 状态变化，确保第三方登录完成后能可靠地关闭 bottom sheet
    _providerSubscription = ref.listenManual(
      authControllerProvider.select((state) => state.user?.provider),
      (_, next) {
        if (!mounted) {
          return;
        }
        if (next != null && next != AuthProviderType.device) {
          final session = ref.read(authControllerProvider).session;
          final user = session.user;
          if (user == null) {
            return;
          }
          Navigator.of(context).pop(
            LoginModalResult.success(
              provider: user.provider.name,
              userId: user.userId,
              userNickname: user.nickname,
              accountLinked: session.guestId != null,
            ),
          );
        }
      },
      fireImmediately: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(authControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _providerSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.w, 16.w, 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                ),
                SizedBox(height: 8.w),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(const LoginModalResult.cancelled());
                    },
                    icon: Icon(Icons.close_rounded, size: 20.w),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: 40.w,
                      height: 40.w,
                    ),
                  ),
                ),
                if (state.isLoading && !state.isLoggedIn) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.w),
                    child: Center(
                      child: AppPegTopLoader(size: 24.w, noBackground: true),
                    ),
                  ),
                ] else
                  AuthLoginModalContent(
                    intent: widget.payload.intent,
                    reason: widget.payload.reason,
                    message: widget.payload.message,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
