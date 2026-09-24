import 'package:drama_client/features/auth/application/phone_login_config_provider.dart';
import 'package:drama_client/features/auth/presentation/pages/phone_login_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlights the selected country in the country picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneRegionsProvider.overrideWith(
            (ref) async => const [
              PhoneRegion(
                callingCode: '63',
                isDefault: true,
                expressions: [],
                regionCode: 'ph',
              ),
              PhoneRegion(
                callingCode: '86',
                isDefault: false,
                expressions: [],
                regionCode: 'cn',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              ScreenUtilInit(designSize: const Size(375, 812), child: child),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PhoneLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PH +63'));
    await tester.pumpAndSettle();

    final selectedCountry = tester.widget<Material>(
      find.byKey(const ValueKey('country_option_ph')),
    );
    final unselectedCountry = tester.widget<Material>(
      find.byKey(const ValueKey('country_option_cn')),
    );
    expect(selectedCountry.color, const Color(0xFF3A3A3A));
    expect(unselectedCountry.color, Colors.transparent);
  });

  testWidgets('phone login logo scales on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneRegionsProvider.overrideWith(
            (ref) async => const [
              PhoneRegion(
                callingCode: '1',
                isDefault: true,
                expressions: [],
                regionCode: 'us',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              ScreenUtilInit(designSize: const Size(375, 812), child: child),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PhoneLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('phone_login_logo'))).width,
      closeTo(80 * 320 / 375, .01),
    );
  });
}
