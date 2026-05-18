import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/account_cancellation_controller.dart';
import '../../application/auth_account_cancellation_coordinator.dart';
import '../../application/auth_controller.dart';
import '../../domain/account_deletion_exception.dart';

class AccountCancellationPage extends ConsumerStatefulWidget {
  const AccountCancellationPage({super.key});

  @override
  ConsumerState<AccountCancellationPage> createState() =>
      _AccountCancellationPageState();
}

class _AccountCancellationPageState
    extends ConsumerState<AccountCancellationPage> {
  Future<void> _submitDelete() async {
    final l10n = context.l10n;
    final cancellationState = ref.read(accountCancellationControllerProvider);
    if (!cancellationState.canSubmit) {
      return;
    }

    final coordinator = ref.read(authAccountCancellationCoordinatorProvider);
    final result = await coordinator.showDeleteConfirm(
      title: l10n.accountCancellationConfirmTitle,
      message: l10n.accountCancellationConfirmMessage,
      confirmLabel: l10n.accountCancellationConfirmDelete,
      cancelLabel: l10n.accountCancellationConfirmCancel,
    );

    if (!mounted || result != ConfirmResult.confirmed) {
      return;
    }

    final cancellationController = ref.read(
      accountCancellationControllerProvider.notifier,
    );
    final authController = ref.read(authControllerProvider.notifier);

    if (ref.read(authControllerProvider).isLoading) {
      await authController.load();
      if (!mounted) {
        return;
      }
    }

    cancellationController.setSubmitting(true);
    await authController.deleteAccount();

    if (!mounted) {
      return;
    }

    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) {
      cancellationController.setSubmitting(false);
      return;
    }
    if (authState.failedAction == AuthFailureAction.deleteAccount ||
        authState.error != null) {
      cancellationController.setError(authState.error);
      ref.read(appToastProvider).error(l10n.authDeleteAccountFailed);
      return;
    }

    ref.read(appToastProvider).success(l10n.accountCancellationSuccess);
    context.go(RoutePaths.profile);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(accountCancellationControllerProvider);
    final controller = ref.read(accountCancellationControllerProvider.notifier);

    final buttonLabel = state.countdownFinished
        ? l10n.accountCancellationDeleteButtonReady
        : l10n.accountCancellationDeleteButtonCountdown(state.remainingSeconds);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountCancellationHeader(title: l10n.accountCancellationTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    l10n.accountCancellationDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoDeletionCard(
                    title: l10n.accountCancellationInfoCardTitle,
                    items: [
                      l10n.accountCancellationInfoProfile,
                      l10n.accountCancellationInfoWallet,
                      l10n.accountCancellationInfoMembership,
                      l10n.accountCancellationInfoPlayback,
                    ],
                  ),
                  const SizedBox(height: 20),
                  _RiskNoticeCard(
                    title: l10n.accountCancellationRiskTitle,
                    body: l10n.accountCancellationRiskBody,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage(context, state.error!),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RiskCheckboxRow(
                    label: l10n.accountCancellationAcceptRisk,
                    value: state.acceptedRisk,
                    onChanged: controller.setAcceptedRisk,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('account_cancellation_delete_button'),
                    onPressed: state.canSubmit ? _submitDelete : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.danger,
                      disabledBackgroundColor: AppColors.danger.withValues(
                        alpha: 0.35,
                      ),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.45,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            buttonLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(BuildContext context, Object error) {
    if (error is AccountDeletionRejectedException) {
      return error.message;
    }
    return context.l10n.authDeleteAccountFailed;
  }
}

class _AccountCancellationHeader extends StatelessWidget {
  const _AccountCancellationHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            child: IconButton(
              key: const ValueKey('account_cancellation_back_button'),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.settings);
                }
              },
              padding: EdgeInsets.zero,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 22 / 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDeletionCard extends StatelessWidget {
  const _InfoDeletionCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('account_cancellation_info_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RiskNoticeCard extends StatelessWidget {
  const _RiskNoticeCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('account_cancellation_risk_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCheckboxRow extends StatelessWidget {
  const _RiskCheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('account_cancellation_risk_checkbox'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
              activeColor: AppColors.danger,
              checkColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: value ? 1 : 0.45),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
