import 'package:drama_client/app/presentation/widgets/novashort_splash_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scales the NovaShort launch identity on narrow screens', (
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
          child: const NovaShortSplashPage(),
        ),
      ),
    );

    expect(find.text('NovaShort'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.getSize(find.byType(Image)).width,
      closeTo(90 * 320 / 375, .01),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF0A0014),
    );
  });
}
