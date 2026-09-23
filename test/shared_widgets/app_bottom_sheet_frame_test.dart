import 'package:drama_client/shared/theme/app_colors.dart';
import 'package:drama_client/shared/widgets/app_bottom_sheet_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses an opaque sheet surface', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const Scaffold(
            backgroundColor: Colors.red,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomSheetFrame(
                title: 'Confirm membership',
                children: [Text('Body')],
              ),
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Material>(
      find.byKey(const ValueKey('app_bottom_sheet_frame_surface')),
    );

    expect(surface.color, AppColors.surface);
    expect(surface.clipBehavior, Clip.antiAlias);
    expect(
      surface.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
  });

  testWidgets('scales the sheet handle from the design width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomSheetFrame(
                title: 'Confirm membership',
                children: [Text('Body')],
              ),
            ),
          ),
        ),
      ),
    );

    final handle = tester.widget<Container>(find.byType(Container));
    expect(handle.constraints?.maxWidth, closeTo(36 * 320 / 375, 0.01));
  });
}
