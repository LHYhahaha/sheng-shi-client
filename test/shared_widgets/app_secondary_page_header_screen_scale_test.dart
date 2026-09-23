import 'package:drama_client/shared/widgets/app_secondary_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('secondary page header scales on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            ScreenUtilInit(designSize: const Size(375, 812), child: child),
        home: Scaffold(
          body: AppSecondaryPageHeader(title: 'Title', onBack: () {}),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppSecondaryPageHeader)).height,
      closeTo(56 * 320 / 375, .01),
    );
  });
}
