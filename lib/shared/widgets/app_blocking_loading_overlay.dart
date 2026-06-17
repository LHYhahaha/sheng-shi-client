import 'package:flutter/material.dart';

class AppBlockingLoadingOverlay extends StatelessWidget {
  const AppBlockingLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
