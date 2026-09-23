import 'package:drama_client/features/profile/presentation/pages/legal_placeholder_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scales legal placeholder copy for a narrow iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const LegalPlaceholderPage(title: 'Privacy'),
        ),
      ),
    );

    final copy = tester.widget<Text>(
      find.text('The full document will be available later'),
    );
    expect(copy.style!.fontSize, closeTo(14 * 320 / 375, 0.01));
  });
}
