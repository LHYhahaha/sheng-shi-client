import 'package:flutter/material.dart';

import 'app_peg_top_loader.dart';

/// Shared visual for pagination requests at the end of a scrollable list.
///
/// This widget intentionally contains no pagination behaviour; each feature
/// keeps its existing threshold, request, retry, and no-more-data logic.
class AppLoadMoreIndicator extends StatelessWidget {
  const AppLoadMoreIndicator({
    this.size = 10,
    this.padding = const EdgeInsets.symmetric(vertical: 0),
    this.isAnimating = true,
    super.key,
  }) : assert(size > 0);

  final double size;
  final EdgeInsetsGeometry padding;
  final bool isAnimating;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Center(
      child: AppPegTopLoader(size: size, isAnimating: isAnimating),
    ),
  );
}
