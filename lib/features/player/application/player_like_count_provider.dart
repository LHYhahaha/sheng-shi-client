import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/compact_count_formatter.dart';
import 'player_like_controller.dart';

/// 获取实时的点赞数 provider。
///
/// 计数基线来自当前页面的内容接口，乐观变化量只保留在当前页面状态中。
final playerLikeCountProvider = Provider.family<String, (String, int, String)>((
  ref,
  args,
) {
  final (likeCountLabel, favoriteCount, dramaId) = args;

  // 监听 PlayerLikeState 的变化
  final likeState = ref.watch(playerLikeControllerProvider(dramaId));

  final originalCount =
      likeState.serverFavoriteCount ??
      (favoriteCount > 0
          ? favoriteCount
          : _extractCountFromLabel(likeCountLabel));

  // 计算新的点赞数
  final newCount = (originalCount + likeState.likeCountDelta)
      .clamp(0, double.infinity)
      .toInt();

  // 格式化为显示文案
  return formatCompactCount(newCount, omitFractionForWholeNumber: true);
});

/// 从标签中提取数字。
/// 例如："1.2K" -> 1200, "100" -> 100
int _extractCountFromLabel(String label) {
  // 移除所有非数字和非小数点的字符
  final cleanLabel = label.replaceAll(RegExp(r'[^\d.]'), '');

  if (cleanLabel.isEmpty) {
    return 0;
  }

  // 检查是否有单位（K、M 等）
  if (label.contains('K') || label.contains('k')) {
    final num = double.tryParse(cleanLabel) ?? 0;
    return (num * 1000).toInt();
  } else if (label.contains('M') || label.contains('m')) {
    final num = double.tryParse(cleanLabel) ?? 0;
    return (num * 1000000).toInt();
  } else {
    return int.tryParse(cleanLabel) ?? 0;
  }
}
