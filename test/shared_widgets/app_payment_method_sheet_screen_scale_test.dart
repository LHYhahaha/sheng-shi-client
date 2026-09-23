import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/shared/widgets/app_payment_method_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scales the payment close button from the design width', (
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
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => Scaffold(
            body: AppPaymentMethodSheet(
              orderTitle: '300 Coins',
              totalLabel: r'$2.99',
              statusLabel: 'Processing',
              isProcessing: false,
              isComplete: false,
              onBuyNow: () {},
              onClose: () {},
              paymentMethods: const [],
              selectedPaymentMethodId: null,
              onPaymentMethodSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SvgPicture)).width,
      closeTo(40 * 320 / 375, 0.01),
    );
  });
}
