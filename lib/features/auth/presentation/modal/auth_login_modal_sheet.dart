import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/modal/app_modal_result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_login_modal_content.dart';
import 'auth_modal_payloads.dart';

/// Auth 登录全局 bottom sheet（复用 [AuthLoginModalContent]）。
class AuthLoginModalSheet extends ConsumerStatefulWidget {
  const AuthLoginModalSheet({required this.payload, super.key});

  final AuthLoginModalPayload payload;

  @override
  ConsumerState<AuthLoginModalSheet> createState() =>
      _AuthLoginModalSheetState();
}

class _AuthLoginModalSheetState extends ConsumerState<AuthLoginModalSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(authControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((state) => state.isLoggedIn), (
      previous,
      next,
    ) {
      if (!next || !mounted) {
        return;
      }
      final session = ref.read(authControllerProvider).session;
      final user = session.user;
      if (user == null) {
        return;
      }
      Navigator.of(context).pop(
        LoginModalResult.success(
          provider: user.provider.name,
          userId: user.id,
          userNickname: user.nickname,
          accountLinked: session.guestId != null,
        ),
      );
    });

    final state = ref.watch(authControllerProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(const LoginModalResult.cancelled());
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
                if (state.isLoading && !state.isLoggedIn) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
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
