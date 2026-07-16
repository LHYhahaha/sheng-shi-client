import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

void showAppCenterToast(
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  BotToast.showCustomText(
    duration: duration,
    onlyOne: true,
    align: Alignment.center,
    toastBuilder: (_) => _AppCenterToast(message: message),
  );
}

class _AppCenterToast extends StatelessWidget {
  const _AppCenterToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('app_center_toast'),
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3740),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
