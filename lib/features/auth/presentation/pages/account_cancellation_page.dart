import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_blocking_loading_overlay.dart';
import '../../application/account_cancellation_controller.dart';
import '../../application/auth_controller.dart';
import '../../domain/account_deletion_exception.dart';
import '../../../entitlement/application/entitlement_controller.dart';

const _accountCancellationAssetRoot = 'assets/images/auth/account_cancellation';

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

    final result = await _showDeleteConfirmSheet(
      title: l10n.accountCancellationTitle,
      message: l10n.accountCancellationConfirmMessage,
      confirmLabel: 'Confirm',
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

    cancellationController
      ..clearError()
      ..setSubmitting(true);
    final canDelete = await _validateDeletionRequirements(
      l10n: l10n,
      cancellationController: cancellationController,
    );
    if (!mounted || !canDelete) {
      return;
    }

    final deleteResult = await authController.deleteAccount();

    if (!mounted) {
      return;
    }

    if (deleteResult == null) {
      final authState = ref.read(authControllerProvider);
      cancellationController.setError(authState.error);
      ref
          .read(appToastProvider)
          .error(_errorMessage(context, authState.error ?? Object()));
      return;
    }

    ref.read(appToastProvider).success(l10n.accountCancellationSuccess);
    if (deleteResult.shouldExitApp) {
      await SystemNavigator.pop();
      return;
    }
    context.go(RoutePaths.profile);
  }

  Future<ConfirmResult> _showDeleteConfirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final result = await showModalBottomSheet<ConfirmResult>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return _DeleteConfirmSheet(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
        );
      },
    );
    return result ?? ConfirmResult.dismissed;
  }

  Future<bool> _validateDeletionRequirements({
    required AppLocalizations l10n,
    required AccountCancellationController cancellationController,
  }) async {
    try {
      await ref.read(entitlementControllerProvider.notifier).load();
    } catch (error) {
      cancellationController.setError(error);
      if (mounted) {
        ref.read(appToastProvider).error(l10n.authDeleteAccountFailed);
      }
      return false;
    }

    final entitlement = ref.read(entitlementControllerProvider);
    if (entitlement.isMember) {
      cancellationController.setSubmitting(false);
      ref
          .read(appToastProvider)
          .error(l10n.accountDeletionRejectedActiveMembership);
      return false;
    }

    if (entitlement.coinBalance > 0) {
      cancellationController.setSubmitting(false);
      ref
          .read(appToastProvider)
          .error(l10n.deleteAccountToastCoinsSpentRequired);
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(accountCancellationControllerProvider);
    final controller = ref.read(accountCancellationControllerProvider.notifier);

    final buttonLabel = state.countdownFinished
        ? l10n.accountCancellationDeleteButtonReady
        : "${l10n.accountCancellationDeleteButtonCountdown} (${state.remainingSeconds}s)";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountCancellationHeader(
                  title: l10n.accountCancellationTitle,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
                    children: [
                      Text(
                        l10n.accountCancellationDescription,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                      const SizedBox(height: 11),
                      _DeletionInfoPanel(items: _deletionItems(l10n)),
                      const SizedBox(height: 18),
                      _CancellationRiskNotice(
                        firstLine: l10n.accountCancellationRiskLogoutDevices,
                        secondLine: l10n.accountCancellationRiskDeletionFinal,
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
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CancellationBottomBar(
                acceptedRisk: state.acceptedRisk,
                isSubmitting: state.isSubmitting,
                canSubmit: state.canSubmit,
                checkboxLabel: l10n.accountCancellationAcceptRisk,
                buttonLabel: buttonLabel,
                onAcceptedRiskChanged: controller.setAcceptedRisk,
                onSubmit: _submitDelete,
              ),
            ),
            if (state.isSubmitting) const AppBlockingLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  List<_DeletionInfoItem> _deletionItems(AppLocalizations l10n) {
    return [
      _DeletionInfoItem(
        title: l10n.accountCancellationInfoPersonalTitle,
        subtitle: l10n.accountCancellationInfoPersonalSubtitle,
        assetPath: '$_accountCancellationAssetRoot/personal_info.png',
        backgroundColor: const Color(0xFF00C948),
      ),
      _DeletionInfoItem(
        title: l10n.accountCancellationInfoThirdPartyTitle,
        assetPath: '$_accountCancellationAssetRoot/third_party_account.png',
        backgroundColor: const Color(0xFF00ACDF),
      ),
      _DeletionInfoItem(
        title: l10n.accountCancellationInfoAccountBalanceTitle,
        subtitle: l10n.accountCancellationInfoAccountBalanceSubtitle,
        assetPath: '$_accountCancellationAssetRoot/account_balance.png',
        backgroundColor: const Color(0xFFFF8C00),
      ),
      _DeletionInfoItem(
        title: l10n.accountCancellationInfoYourBalanceTitle,
        subtitle: l10n.accountCancellationInfoYourBalanceSubtitle,
        assetPath: '$_accountCancellationAssetRoot/your_balance.png',
        backgroundColor: const Color(0xFFBB4BE4),
      ),
      _DeletionInfoItem(
        title: l10n.accountCancellationInfoMemberBenefitsTitle,
        subtitle: l10n.accountCancellationInfoMemberBenefitsSubtitle,
        assetPath: '$_accountCancellationAssetRoot/member_benefits.png',
        backgroundColor: const Color(0xFF8E8E95),
      ),
    ];
  }

  String _errorMessage(BuildContext context, Object error) {
    if (error is AccountDeletionRejectedException) {
      return error.message;
    }
    return context.l10n.authDeleteAccountFailed;
  }
}

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 19, 16, 18 + bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            key: const ValueKey('account_cancellation_confirm_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Row(
            children: [
              Expanded(
                child: _DeleteConfirmActionButton(
                  key: const ValueKey('account_cancellation_confirm_cancel'),
                  label: cancelLabel,
                  backgroundColor: const Color(0xFFFF0D83),
                  onPressed: () {
                    Navigator.of(context).pop(ConfirmResult.cancelled);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DeleteConfirmActionButton(
                  key: const ValueKey('account_cancellation_confirm_submit'),
                  label: confirmLabel,
                  backgroundColor: const Color(0xFF3F3F42),
                  onPressed: () {
                    Navigator.of(context).pop(ConfirmResult.confirmed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmActionButton extends StatelessWidget {
  const _DeleteConfirmActionButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 18 / 14,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              // fontSize: 16,
              // fontWeight: FontWeight.w500,
              height: 22 / 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletionInfoItem {
  const _DeletionInfoItem({
    required this.title,
    required this.assetPath,
    required this.backgroundColor,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String assetPath;
  final Color backgroundColor;
}

class _DeletionInfoPanel extends StatelessWidget {
  const _DeletionInfoPanel({required this.items});

  final List<_DeletionInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('account_cancellation_info_card'),
      // constraints: const BoxConstraints(minHeight: 403),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF241A2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _DeletionInfoRow(item: items[index]),
            if (index != items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 38, top: 14, bottom: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DeletionInfoRow extends StatelessWidget {
  const _DeletionInfoRow({required this.item});

  final _DeletionInfoItem item;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeletionIconTile(item: item),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: subtitle == null ? 2 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 22 / 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 16 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletionIconTile extends StatelessWidget {
  const _DeletionIconTile({required this.item});

  final _DeletionInfoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: item.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        item.assetPath,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CancellationRiskNotice extends StatelessWidget {
  const _CancellationRiskNotice({
    required this.firstLine,
    required this.secondLine,
  });

  final String firstLine;
  final String secondLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('account_cancellation_risk_card'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Image.asset(
              '$_accountCancellationAssetRoot/warning.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Text(
                  secondLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancellationBottomBar extends StatelessWidget {
  const _CancellationBottomBar({
    required this.acceptedRisk,
    required this.isSubmitting,
    required this.canSubmit,
    required this.checkboxLabel,
    required this.buttonLabel,
    required this.onAcceptedRiskChanged,
    required this.onSubmit,
  });

  final bool acceptedRisk;
  final bool isSubmitting;
  final bool canSubmit;
  final String checkboxLabel;
  final String buttonLabel;
  final ValueChanged<bool> onAcceptedRiskChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 108 + bottomPadding,
      padding: EdgeInsets.fromLTRB(26, 14, 26, 20 + bottomPadding),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00251B2D), Color(0xFF251B2D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RiskCheckboxRow(
            label: checkboxLabel,
            value: acceptedRisk,
            onChanged: onAcceptedRiskChanged,
          ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: FilledButton(
              key: const ValueKey('account_cancellation_delete_button'),
              onPressed: canSubmit ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF0D83),
                disabledBackgroundColor: const Color(
                  0xFFFF0D83,
                ).withValues(alpha: 0.38),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: isSubmitting
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
                        height: 20 / 16,
                      ),
                    ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RiskCheckboxIndicator(value: value),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                height: 15 / 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCheckboxIndicator extends StatelessWidget {
  const _RiskCheckboxIndicator({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: value ? const Color(0xFFFF0D83) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: value ? 1 : 0.45),
          width: 1,
        ),
      ),
      child: value
          ? const Icon(Icons.check, size: 10, color: Colors.white)
          : null,
    );
  }
}
