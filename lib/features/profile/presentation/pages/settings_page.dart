import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/runtime/app_version_provider.dart';
import '../../../../core/runtime/cellular_download_preference.dart';
import '../../../../shared/widgets/custom_switch.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_blocking_loading_overlay.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../../auth/application/auth_controller.dart';
import '../../data/settings_cache_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isLoggingOut = false;
  bool _cacheBusy = false;
  bool _isClearingCache = false;
  int _cacheBytes = 0;
  bool _confirmingCellularDownload = false;

  Future<void> _setCellularDownload(bool value) async {
    if (_confirmingCellularDownload ||
        _isLoggingOut ||
        !ref.read(cellularDownloadPreferenceProvider).hasValue) {
      return;
    }
    _confirmingCellularDownload = true;
    try {
      if (value) {
        final result = await ref
            .read(appModalServiceProvider)
            .showConfirm(
              ConfirmModalRequest(
                requestId: ref.read(appModalControllerProvider).nextRequestId(),
                source: AppModalSource.system,
                title: context.l10n.settingsCellularDownloadConfirm,
                message: '',
                confirmLabel: context.l10n.settingsClearCacheYes,
                cancelLabel: context.l10n.accountCancellationConfirmCancel,
                style: ConfirmModalStyle.compact,
              ),
            );
        if (!mounted || result != ConfirmResult.confirmed) return;
      }
      await ref
          .read(cellularDownloadPreferenceProvider.notifier)
          .setEnabled(value);
    } catch (_) {
      if (mounted) {
        ref
            .read(appToastProvider)
            .error(context.l10n.settingsPreferenceSaveError);
      }
    } finally {
      _confirmingCellularDownload = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshCache();
  }

  Future<void> _refreshCache() async {
    try {
      final bytes = await ref.read(settingsCacheServiceProvider).sizeBytes();
      if (mounted) setState(() => _cacheBytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _cacheBytes = 0);
    }
  }

  Future<void> _clearCache() async {
    if (_cacheBusy || _isLoggingOut) return;
    setState(() => _cacheBusy = true);
    try {
      final service = ref.read(settingsCacheServiceProvider);
      final bytes = await service.sizeBytes();
      if (!mounted) return;
      setState(() => _cacheBytes = bytes);
      if (bytes == 0) {
        ref.read(appToastProvider).info(context.l10n.settingsCacheEmpty);
        return;
      }
      final result = await ref
          .read(appModalServiceProvider)
          .showConfirm(
            ConfirmModalRequest(
              requestId: ref.read(appModalControllerProvider).nextRequestId(),
              source: AppModalSource.system,
              title: context.l10n.settingsClearCacheConfirm,
              message: '',
              confirmLabel: context.l10n.settingsClearCacheYes,
              cancelLabel: context.l10n.accountCancellationConfirmCancel,
              style: ConfirmModalStyle.compact,
            ),
          );
      if (result != ConfirmResult.confirmed || !mounted) return;
      setState(() => _isClearingCache = true);
      await service.clear();
    } catch (_) {
      if (mounted) {
        ref.read(appToastProvider).error(context.l10n.settingsCacheError);
      }
    } finally {
      if (mounted) {
        await _refreshCache();
        if (mounted) {
          setState(() {
            _cacheBusy = false;
            _isClearingCache = false;
          });
        }
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    final controller = ref.read(authControllerProvider.notifier);
    await controller.logout();

    if (!mounted) {
      return;
    }

    final nextState = ref.read(authControllerProvider);
    if (nextState.error == null && nextState.session.isGuest) {
      final message = context.l10n.authLogoutSuccess;
      ref.read(appToastProvider).success(message);
      context.go(RoutePaths.profile);
      return;
    }

    setState(() => _isLoggingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final isGuest = authState.session.isGuest;
    final cellularPreference = ref.watch(cellularDownloadPreferenceProvider);
    final allowCellularDownload = cellularPreference.asData?.value ?? false;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsHeader(title: l10n.profileSettings),
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(height: 12.w),
                      _SettingsRow(
                        key: const ValueKey(
                          'settings_account_cancellation_row',
                        ),
                        title: l10n.settingsDeleteAccount,
                        onTap: _isLoggingOut
                            ? () {}
                            : () =>
                                  context.push(RoutePaths.accountCancellation),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings_user_agreement_row'),
                        title: l10n.settingsUserAgreement,
                        onTap: _isLoggingOut
                            ? () {}
                            : () => context.push(RoutePaths.userAgreement),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings_privacy_policy_row'),
                        title: l10n.settingsPrivacyPolicy,
                        onTap: _isLoggingOut
                            ? () {}
                            : () => context.push(RoutePaths.privacyPolicy),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings_clear_cache_row'),
                        title: l10n.settingsClearCache,
                        onTap: _clearCache,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              SettingsCacheService.formatBytes(_cacheBytes),
                              style: TextStyle(
                                color: Color(0XFF818181).withValues(alpha: 0.7),
                                fontSize: 16.sp,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Image.asset(
                              "assets/images/profile/trash.png",
                              width: 24.w,
                              height: 24.w,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings_cellular_download_row'),
                        title: l10n.settingsCellularDownload,
                        onTap: () =>
                            _setCellularDownload(!allowCellularDownload),
                        trailing: CustomSwitch(
                          value: allowCellularDownload,
                          onChanged: cellularPreference.hasValue
                              ? _setCellularDownload
                              : null,
                        ),
                      ),
                      // _SettingsRow(
                      //   key: const ValueKey('settings_about_row'),
                      //   title: l10n.settingsAbout,
                      //   onTap: () =>
                      //       setState(() => _aboutEnabled = !_aboutEnabled),
                      //   trailing: CustomSwitch(
                      //     value: _aboutEnabled,
                      //     onChanged: (value) =>
                      //         setState(() => _aboutEnabled = value),
                      //   ),
                      // ),
                      // `logout()` switches the shared auth state to guest before this
                      // page navigates away. Keep the button mounted while the blocking
                      // overlay is visible so the screen does not visibly reflow during
                      // that short transition.
                      if (!isGuest || _isLoggingOut)
                        InkWell(
                          key: const ValueKey('settings_logout_button'),
                          onTap: _isLoggingOut ? null : _logout,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(vertical: 13.w),
                            margin: EdgeInsets.symmetric(
                              horizontal: 50.w,
                              vertical: 40.w,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.w),
                              color: const Color(
                                0xFFFFFFFF,
                              ).withValues(alpha: 0.12),
                            ),
                            child: Text(
                              context.l10n.settingsButtonLogout,
                              style: TextStyle(
                                color: Color(0XFFFF007A),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16.w, bottom: 16.w),
                  child: Text(
                    ref
                        .watch(packageInfoProvider)
                        .when(
                          data: (info) => 'V${info.version}',
                          loading: () => '',
                          error: (_, _) => '',
                        ),
                    key: const ValueKey('settings_app_version'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF818181).withValues(alpha: 0.7),
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoggingOut || _isClearingCache)
            const AppBlockingLoadingOverlay(),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSecondaryPageHeader(
      title: title,
      backButtonKey: const ValueKey('settings_back_button'),
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.profile);
        }
      },
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 52.w,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16.sp,
                    height: 22 / 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0XFF818181).withValues(alpha: 0.7),
                    size: 24.w,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
