import 'package:drama_client/shared/theme/app_colors.dart';
import 'package:drama_client/shared/widgets/app_bottom_sheet_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses an opaque sheet surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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
}
