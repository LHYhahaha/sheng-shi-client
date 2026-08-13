import '../../../../features/drama/domain/drama.dart';

/// 单次稳定曝光批次中的首页预热候选。
class HomePreloadCandidate {
  const HomePreloadCandidate({
    required this.drama,
    required this.visibleFraction,
  });

  final Drama drama;
  final double visibleFraction;
}
