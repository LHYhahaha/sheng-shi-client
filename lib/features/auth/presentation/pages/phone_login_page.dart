import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../application/phone_login_config_provider.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';

class PhoneLoginPage extends ConsumerStatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  ConsumerState<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends ConsumerState<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  PhoneRegion? _country;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isSendingCode = false;
  bool _hasAcceptedTerms = false;
  bool _regionsRequested = false;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push(RoutePaths.userAgreement);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push(RoutePaths.privacyPolicy);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_regionsRequested) return;
    _regionsRequested = true;
    // 每次进入手机号页都必须重新获取地区、默认区号和校验规则。
    ref.invalidate(phoneRegionsProvider);
  }

  bool get _isPhoneValid => _normalizedPhoneNumber != null;

  bool get _hasPhoneNumber => _phoneController.text.trim().isNotEmpty;

  bool get _canRequestCode => _hasPhoneNumber && _secondsRemaining == 0;

  bool get _canSignIn =>
      _hasPhoneNumber && _codeController.text.trim().isNotEmpty;

  PhoneRegion get _selectedCountry {
    if (_country != null) return _country!;
    final regions = ref.read(phoneRegionsProvider).asData?.value ?? const [];
    for (final region in regions) {
      if (region.isDefault) return region;
    }
    if (regions.isNotEmpty) return regions.first;
    return const PhoneRegion(
      callingCode: '',
      isDefault: false,
      expressions: [],
      regionCode: '',
    );
  }

  String? get _normalizedPhoneNumber {
    final entered = _phoneController.text.trim();
    if (entered.isEmpty) return null;
    final number = entered.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\d+$').hasMatch(number)) return null;
    final country = _selectedCountry;
    final callingCode = country.callingCode;
    if (callingCode.isEmpty) return null;
    if ((callingCode.length + number.length) > 15) return null;
    if (!country.matches(number)) {
      return null;
    }
    return number;
  }

  Future<void> _requestCode() async {
    if (_secondsRemaining > 0 || _isSendingCode) return;
    final isPhoneValid = _isPhoneValid;
    _trackElementClick('phone_code_request_button', {
      'phone_validation_result': isPhoneValid ? 'passed' : 'failed',
    });
    if (!isPhoneValid) {
      ref.read(appToastProvider).error(context.l10n.phoneLoginInvalidPhone);
      return;
    }
    final number = _normalizedPhoneNumber!;
    setState(() => _isSendingCode = true);
    try {
      final result = await ref
          .read(phoneSmsServiceProvider)
          .sendCode(
            callingCode: _selectedCountry.callingCode,
            number: number,
            requestId: _newRequestId(),
          );
      if (!mounted) return;
      setState(() {
        _isSendingCode = false;
        _secondsRemaining = result.countdownSeconds;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      ref.read(appToastProvider).error(_sendCodeErrorMessage(error.message));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      ref.read(appToastProvider).error(context.l10n.phoneLoginSendCodeFailed);
      return;
    }
    if (!mounted || _secondsRemaining <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  String _newRequestId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  String _sendCodeErrorMessage(String key) => switch (key) {
    'login.sms.phone_invalid' => context.l10n.phoneLoginInvalidPhone,
    'login.sms.too_frequent' => context.l10n.phoneLoginTooFrequent,
    'login.sms.send_failed' => context.l10n.phoneLoginSendCodeFailed,
    'login.sms.code_invalid' => context.l10n.phoneLoginInvalidCode,
    'login.sms.code_expired' => context.l10n.phoneLoginExpiredCode,
    'login.phone.region_unsupported' =>
      context.l10n.phoneLoginRegionUnsupported,
    _ => context.l10n.phoneLoginSendCodeFailed,
  };

  void _signIn() {
    if (!_canSignIn) return;
    final number = _normalizedPhoneNumber;
    if (number == null) {
      ref.read(appToastProvider).error(context.l10n.phoneLoginInvalidPhone);
      return;
    }
    _trackElementClick('phone_login_submit_button', {
      'login_provider': 'phone',
    });
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .loginWithPhone(
            callingCode: _selectedCountry.callingCode,
            number: number,
            code: _codeController.text,
          ),
    );
  }

  void _trackElementClick(
    String elementName, [
    Map<String, Object?> parameters = const {},
  ]) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': elementName,
              ...parameters,
            }),
          ),
    );
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regionsState = ref.watch(phoneRegionsProvider);
    ref.listen(authControllerProvider, (previous, next) {
      final loginJustSucceeded =
          previous?.isLoggedIn != true && next.isLoggedIn;
      if (loginJustSucceeded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go(RoutePaths.profile);
          }
        });
        return;
      }
      final justFailed =
          previous?.failedAction != AuthFailureAction.login &&
          next.failedAction == AuthFailureAction.login;
      if (!justFailed || next.error is! ApiException) return;
      ref
          .read(appToastProvider)
          .error(_sendCodeErrorMessage((next.error! as ApiException).message));
    });
    final isSigningIn =
        ref.watch(authControllerProvider).pendingProvider ==
        AuthProviderType.phone;
    final l10n = context.l10n;
    if (regionsState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(child: Center(child: AppPegTopLoader())),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 键盘弹起后保留可滚动的最小内容高度，避免登录按钮被键盘遮挡。
              final contentHeight = constraints.maxHeight < 520.w
                  ? 520.w
                  : constraints.maxHeight;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: SizedBox(
                  height: contentHeight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.w),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppSecondaryPageBackButton(
                            onPressed: () => context.pop(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              children: [
                                const Spacer(flex: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20.w),
                                  child: Image.asset(
                                    'assets/images/profile/logo.png',
                                    key: const ValueKey('phone_login_logo'),
                                    width: 80.w,
                                    height: 80.w,
                                  ),
                                ),
                                SizedBox(height: 32.w),
                                _phoneField(),
                                SizedBox(height: 14.w),
                                _codeField(l10n),
                                SizedBox(height: 12.w),
                                _termsRow(l10n),
                                SizedBox(height: 34.w),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    key: const ValueKey('phone_sign_in_button'),
                                    onPressed: _canSignIn && !isSigningIn
                                        ? _signIn
                                        : null,
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 13.w,
                                      ),
                                      backgroundColor: AppColors.primary,
                                      disabledBackgroundColor: AppColors.white
                                          .withValues(alpha: 0.3),
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: Colors.white
                                          .withValues(alpha: .3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          4.w,
                                        ),
                                      ),
                                    ),
                                    child: isSigningIn
                                        ? SizedBox(
                                            width: 18.w,
                                            height: 18.w,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            l10n.phoneLoginSignIn,
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                const Spacer(flex: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _phoneField() => DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0XFF3A3A3A).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(4.w),
    ),
    child: Row(
      children: [
        TextButton(
          onPressed: _chooseCountry,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: EdgeInsets.fromLTRB(14.w, 13.w, 9.w, 13.w),
            shape: const RoundedRectangleBorder(),
          ),
          child: Row(
            children: [
              Text(
                '${_selectedCountry.regionCode.toUpperCase()} ${_selectedCountry.callingCodeLabel}',
                style: TextStyle(fontWeight: FontWeight(400)),
              ),
              SizedBox(width: 4.w),
              SvgPicture.asset(
                "assets/images/auth/login_drop_icon.svg",
                height: 6.w,
                width: 6.w,
              ),
            ],
          ),
        ),
        Container(
          width: 1.w,
          height: 24.w,
          color: Colors.white.withValues(alpha: .12),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('phone_number_field'),
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                15 - _selectedCountry.callingCode.length,
              ),
            ],
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _codeFocusNode.requestFocus(),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: context.l10n.phoneLoginPhoneHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _codeField(AppLocalizations l10n) => DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0XFF3A3A3A).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(4.w),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('phone_verification_code_field'),
            controller: _codeController,
            focusNode: _codeFocusNode,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dismissKeyboard(),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: l10n.phoneLoginCodeHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('phone_get_code_button'),
          onPressed: _canRequestCode && !_isSendingCode
              ? () {
                  _dismissKeyboard();
                  unawaited(_requestCode());
                }
              : null,
          style:
              TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF007A),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                splashFactory: NoSplash.splashFactory,
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          child: Text(
            _isSendingCode
                ? '...'
                : _secondsRemaining == 0
                ? l10n.phoneLoginGetCode
                : '${_secondsRemaining}s',
            style: TextStyle(fontWeight: FontWeight(400)),
          ),
        ),
      ],
    ),
  );

  Widget _termsRow(AppLocalizations l10n) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => setState(() => _hasAcceptedTerms = !_hasAcceptedTerms),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11.sp,
          height: 1.3,
        ),
        children: [
          TextSpan(text: l10n.phoneLoginAgreementPrefix),
          TextSpan(
            text: l10n.appCommonLegalTermsOfUse,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            recognizer: _termsRecognizer,
          ),
          TextSpan(text: l10n.phoneLoginAgreementConnector),
          TextSpan(
            text: l10n.appCommonLegalPrivacyPolicy,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            recognizer: _privacyRecognizer,
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseCountry() async {
    // BottomSheet builder 的 MediaQuery 会被路由调整；这里从原始 FlutterView
    // 读取窗口数据，避免状态栏 Insets 被 SafeArea/BottomSheet 二次处理。
    final windowMediaQuery = MediaQueryData.fromView(View.of(context));
    final sheetHeight =
        windowMediaQuery.size.height - windowMediaQuery.padding.top - 20;
    final regions = ref.read(phoneRegionsProvider).asData?.value ?? const [];
    if (!mounted) return;
    final choice = await showModalBottomSheet<PhoneRegion>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.w)),
      ),
      builder: (context) {
        return SizedBox(
          height: sheetHeight * 0.4,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 20.w),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(width: 40.w, height: 40.w),
                      Text(
                        context.l10n.phoneLoginChooseCountry,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight(510),
                        ),
                      ),

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox.square(
                          dimension: 40.w,
                          child: SvgPicture.asset(
                            "assets/images/player/close.svg",
                            width: 40.w,
                            height: 40.w,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.w),
                  Expanded(
                    child: regions.isEmpty
                        ? Center(
                            child: AppEmptyState(message: context.l10n.noData),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (final country in regions)
                                Builder(
                                  builder: (context) {
                                    final isSelected =
                                        country.regionCode ==
                                            _selectedCountry.regionCode &&
                                        country.callingCode ==
                                            _selectedCountry.callingCode;
                                    return Semantics(
                                      selected: isSelected,
                                      child: Material(
                                        key: ValueKey(
                                          'country_option_${country.regionCode}',
                                        ),
                                        color: isSelected
                                            ? const Color(0xFF3A3A3A)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          24.w,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            24.w,
                                          ),
                                          onTap: () =>
                                              Navigator.pop(context, country),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.w,
                                              vertical: 18.w,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    country.displayName,
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      height: 1.3,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  country.callingCodeLabel,
                                                  style: TextStyle(
                                                    height: 1.3,
                                                    fontSize: 16.sp,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight(400),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (choice != null) setState(() => _country = choice);
  }
}
