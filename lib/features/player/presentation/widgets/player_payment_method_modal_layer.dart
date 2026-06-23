import 'dart:async';

import 'package:flutter/material.dart';

import 'player_payment_method_sheet.dart';

/// Payment Method 叠层：独立 barrier + 底部滑入动画（O2.1 AppModal presenter 使用）。
class PlayerPaymentMethodModalLayer extends StatefulWidget {
  const PlayerPaymentMethodModalLayer({
    required this.sessionKey,
    required this.selection,
    required this.onDismissed,
    required this.onPurchaseSuccess,
    super.key,
  });

  final String sessionKey;
  final PlayerPaymentSelection selection;
  final ValueChanged<bool?> onDismissed;
  final VoidCallback onPurchaseSuccess;

  @override
  State<PlayerPaymentMethodModalLayer> createState() =>
      _PlayerPaymentMethodModalLayerState();
}

class _PlayerPaymentMethodModalLayerState
    extends State<PlayerPaymentMethodModalLayer>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 240);
  static const _reverseDuration = Duration(milliseconds: 180);

  late final AnimationController _controller;
  late final Animation<double> _barrierOpacity;
  late final Animation<Offset> _sheetOffset;
  var _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      reverseDuration: _reverseDuration,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _barrierOpacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _sheetOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss({bool? result = false}) async {
    if (_isDismissing) {
      return;
    }
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _barrierOpacity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => dismiss(result: null),
              child: const ColoredBox(color: Color(0x73000000)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _sheetOffset,
            child: PlayerPaymentMethodSheet(
              sessionKey: widget.sessionKey,
              selection: widget.selection,
              onDismiss: dismiss,
              onPurchaseSuccess: widget.onPurchaseSuccess,
            ),
          ),
        ),
      ],
    );
  }
}
