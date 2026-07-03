import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/compact_count_formatter.dart';
import 'player_like_controller.dart';

/// 获取实时的点赞数 provider。
///
/// 只有当用户点击了点赞/取消点赞时，才在原始 likeCountLabel 基础上计算；
/// 进入页面时直接显示接口返回的 likeCountLabel。
final playerLikeCountProvider = Provider.family<String, (String, String)>((
  ref,
  args,
) {
  final (likeCountLabel, dramaId) = args;

  // 监听 PlayerLikeState 的变化
  final likeState = ref.watch(playerLikeControllerProvider(dramaId));

  // 只有当用户有点赞操作（likeCountDelta != 0）时，才在原始值基础上计算
  // 进入页面时直接显示接口返回的 likeCountLabel
  if (likeState.likeCountDelta == 0) {
    return likeCountLabel;
  }

  // 从原始的 likeCountLabel 中提取数字
  final originalCount = _extractCountFromLabel(likeCountLabel);

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
