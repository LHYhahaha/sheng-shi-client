import 'package:drama_client/shared/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scales its label from the design width on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => Scaffold(
            body: AppPrimaryButton(label: 'Continue', onPressed: () {}),
          ),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Continue'));
    expect(label.style?.fontSize, closeTo(14 * 320 / 375, 0.01));
  });
}
