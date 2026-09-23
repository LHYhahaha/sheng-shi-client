import 'package:drama_client/features/store/domain/store_package.dart';
import 'package:drama_client/features/store/presentation/widgets/store_coin_package_card.dart';
import 'package:drama_client/features/store/presentation/widgets/store_vip_package_card.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coin package card shrinks proportionally on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            ScreenUtilInit(designSize: const Size(375, 812), child: child),
        home: Scaffold(
          body: StoreCoinPackageCard(
            package: const StorePackage(
              id: 'coins-300',
              kind: StorePackageKind.coins,
              title: '300',
              priceLabel: r'$2.99',
            ),
            selected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AnimatedContainer)).height,
      closeTo(85 * 320 / 375, .01),
    );
  });

  testWidgets('VIP package card shrinks proportionally on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
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
          home: Scaffold(
            body: StoreVipPackageCard(
              package: const StorePackage(
                id: 'weekly',
                kind: StorePackageKind.vip,
                title: 'Weekly VIP',
                priceLabel: r'$4.99',
              ),
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AnimatedContainer)).height,
      closeTo(159 * 320 / 375, .01),
    );
  });
}
