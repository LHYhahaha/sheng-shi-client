import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';

/// User Agreement / Privacy Policy 占位页（正式内容后续接入）。
class LegalPlaceholderPage extends StatelessWidget {
  const LegalPlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            AppSecondaryPageHeader(
              title: title,
              backButtonKey: const ValueKey('legal_placeholder_back_button'),
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.settings);
                }
              },
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 24.w, 16.w, 24.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.settingsLegalPlaceholder,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 14.sp,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
