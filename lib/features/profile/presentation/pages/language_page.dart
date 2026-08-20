import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/active/app_active_reporter.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/locale/app_locale_controller.dart';
import '../../application/language_options_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_blocking_loading_overlay.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_retry_button.dart';

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  String? _tempSelectedLanguageCode;
  bool _isSwitching = false;

  String _getEffectiveLanguageCode() {
    final currentLocale = ref.read(appLocaleControllerProvider);
    return _tempSelectedLanguageCode ??
        AppLocaleController.languageCodeFromLocale(currentLocale);
  }

  void _onLanguageSelected(String languageCode) {
    if (_isSwitching) {
      return;
    }
    setState(() {
      _tempSelectedLanguageCode = languageCode;
    });
  }

  Future<void> _onDone() async {
    if (_isSwitching) {
      return;
    }

    final selectedLanguageCode = _tempSelectedLanguageCode;
    if (selectedLanguageCode != null) {
      final languageCode = AppLocaleController.canonicalLanguageCode(
        selectedLanguageCode,
      );
      setState(() {
        _isSwitching = true;
      });

      final localeController = ref.read(appLocaleControllerProvider.notifier);
      try {
        await ref
            .read(i18nControllerProvider.notifier)
            .switchLanguage(languageCode);
        await localeController.selectAndSave(
          AppLocaleController.localeForLanguageCode(languageCode),
        );
        // 切换完成后以新的 Accept-Language 请求活跃上报；上报器会自行读取
        // 当前 FCM token，已拿到时自动携带 pushToken，且失败不阻塞返回页面。
        unawaited(ref.read(appActiveReporterProvider).reportAppLaunch());
      } finally {
        if (mounted) {
          setState(() {
            _isSwitching = false;
          });
        }
      }
    }

    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.profile);
    }
  }

  void _onBack() {
    if (_isSwitching) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguageCode = _getEffectiveLanguageCode();
    final currentLocale = ref.watch(appLocaleControllerProvider);
    final currentLanguageCode = AppLocaleController.languageCodeFromLocale(
      currentLocale,
    );
    final languageOptions = ref.watch(languageOptionsProvider);
    final showDoneButton =
        _tempSelectedLanguageCode != null &&
        _tempSelectedLanguageCode != currentLanguageCode;

    return PopScope(
      canPop: !_isSwitching,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isSwitching,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LanguageHeader(
                      title: context.l10n.languagePageTitle,
                      onBack: _onBack,
                      onDone: _onDone,
                      showDoneButton: showDoneButton,
                    ),
                    Expanded(
                      child: languageOptions.when(
                        loading: () => const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        error: (_, _) => _LanguageOptionsError(
                          onRetry: () =>
                              ref.invalidate(languageOptionsProvider),
                        ),
                        data: (options) {
                          if (options.isEmpty) {
                            return Center(
                              child: AppEmptyState(
                                message: context.l10n.noData,
                              ),
                            );
                          }
                          return ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final option in options)
                                _LanguageOption(
                                  label: option.label,
                                  selected: selectedLanguageCode == option.code,
                                  onTap: () => _onLanguageSelected(option.code),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSwitching)
              AppBlockingLoadingOverlay(label: context.l10n.loading),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionsError extends StatelessWidget {
  const _LanguageOptionsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.networkError,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppRetryButton(onPressed: onRetry, label: context.l10n.retry),
        ],
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  const _LanguageHeader({
    required this.title,
    required this.onBack,
    required this.onDone,
    required this.showDoneButton,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onDone;
  final bool showDoneButton;

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
              onPressed: onBack,
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
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (showDoneButton)
            Positioned(
              right: 6,
              child: TextButton(
                onPressed: onDone,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  minimumSize: WidgetStateProperty.all(const Size(40, 40)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.languagePageButton,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textPrimary,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
