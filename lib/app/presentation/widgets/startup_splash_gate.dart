import 'dart:async';

import 'package:flutter/widgets.dart';

import 'novashort_splash_page.dart';

/// Keeps the launch identity visible long enough to avoid a flash of content.
class StartupSplashGate extends StatefulWidget {
  const StartupSplashGate({required this.child, super.key});

  final Widget child;

  @override
  State<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<StartupSplashGate> {
  static const _minimumVisibleDuration = Duration(milliseconds: 1400);
  Timer? _timer;
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumVisibleDuration, () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const NovaShortSplashPage() : widget.child;
  }
}
