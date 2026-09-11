import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _Country _country = _countries.first;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _hasAcceptedTerms = false;

  bool get _isPhoneValid => _normalizedPhoneNumber != null;
  bool get _canRequestCode => _isPhoneValid && _secondsRemaining == 0;
  bool get _canSignIn =>
      _isPhoneValid &&
      _codeController.text.trim().isNotEmpty &&
      _hasAcceptedTerms;

  String? get _normalizedPhoneNumber {
    final entered = _phoneController.text.trim();
    if (entered.isEmpty) return null;
    final number = entered.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\d+$').hasMatch(number)) return null;
    final callingCode = _country.callingCode.replaceFirst('+', '');
    if ((callingCode.length + number.length) > 15) return null;
    return number;
  }

  void _requestCode() {
    if (!_canRequestCode) return;
    // TODO(real-api): 请求服务端发送验证码，成功回调后再开始倒计时。
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  void _signIn() {
    if (!_canSignIn) return;
    // TODO(real-api): 使用 $_country.callingCode$_normalizedPhoneNumber 与验证码登录。
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, safeBottom + 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AppSecondaryPageBackButton(
                  onPressed: () => context.pop(),
                ),
              ),
              const Spacer(flex: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/profile/logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const Spacer(flex: 5),
              _phoneField(),
              const SizedBox(height: 14),
              _codeField(l10n),
              const SizedBox(height: 12),
              _termsRow(l10n),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('phone_sign_in_button'),
                  onPressed: _canSignIn ? _signIn : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFF940044),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: .45,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(l10n.phoneLoginSignIn),
                ),
              ),
              const Spacer(flex: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneField() => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfacePanel,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        TextButton(
          onPressed: _chooseCountry,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text('${_country.label} ${_country.callingCode} ▾'),
        ),
        Container(
          width: 1,
          height: 22,
          color: Colors.white.withValues(alpha: .11),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('phone_number_field'),
            controller: _phoneController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.l10n.phoneLoginPhoneHint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _codeField(AppLocalizations l10n) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfacePanel,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('phone_verification_code_field'),
            controller: _codeController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.phoneLoginCodeHint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('phone_get_code_button'),
          onPressed: _canRequestCode ? _requestCode : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.textMuted,
          ),
          child: Text(
            _secondsRemaining == 0
                ? l10n.phoneLoginGetCode
                : '${_secondsRemaining}s',
          ),
        ),
      ],
    ),
  );

  Widget _termsRow(AppLocalizations l10n) => InkWell(
    onTap: () => setState(() => _hasAcceptedTerms = !_hasAcceptedTerms),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Icon(
            _hasAcceptedTerms
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: 14,
            color: _hasAcceptedTerms
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            l10n.phoneLoginAgreement,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _chooseCountry() async {
    final choice = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.phoneLoginChooseCountry,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              for (final country in _countries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    country.name,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Text(
                    country.callingCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, country),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) setState(() => _country = choice);
  }
}

class _Country {
  const _Country(this.name, this.label, this.callingCode);
  final String name;
  final String label;
  final String callingCode;
}

const _countries = [
  _Country('United States', 'US', '+1'),
  _Country('China', 'China', '+86'),
  _Country('Japan', 'Japan', '+81'),
];
