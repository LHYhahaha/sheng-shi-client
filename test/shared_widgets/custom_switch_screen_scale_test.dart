import 'package:drama_client/shared/widgets/custom_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom switch scales with the screen width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            ScreenUtilInit(designSize: const Size(375, 812), child: child),
        home: Scaffold(body: CustomSwitch(value: false, onChanged: (_) {})),
      ),
    );

    expect(
      tester.getSize(find.byType(AnimatedContainer)).width,
      closeTo(48 * 320 / 375, .01),
    );
  });
}
