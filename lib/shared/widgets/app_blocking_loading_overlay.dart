import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_peg_top_loader.dart';

class AppBlockingLoadingOverlay extends StatelessWidget {
  const AppBlockingLoadingOverlay({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.45),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppPegTopLoader(size: 20),
                  if (label != null && label!.isNotEmpty) ...[
                    SizedBox(height: 20.w),
                    Text(
                      label!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
