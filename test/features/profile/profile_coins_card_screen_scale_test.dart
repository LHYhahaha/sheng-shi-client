import 'package:drama_client/features/profile/application/profile_controller.dart';
import 'package:drama_client/features/profile/presentation/widgets/profile_coins_card.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile top-up button scales on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
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
          body: ProfileCoinsCard(
            coins: const ProfileCoinsState(
              balance: 10,
              topUpEnabled: true,
              walletEnabled: true,
            ),
            onTopUpTap: () {},
            onWalletTap: () {},
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile_top_up_entry'))).height,
      closeTo(34 * 320 / 375, .01),
    );
  });
}
