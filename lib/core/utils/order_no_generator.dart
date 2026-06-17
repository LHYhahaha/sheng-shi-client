import 'dart:math';

/// 订单号生成工具
///
/// 生成格式：userid + 时间戳 + 随机六位数
/// 例如：123456_1707051234567_123456
class OrderNoGenerator {
  OrderNoGenerator._();

  static final _random = Random();

  /// 生成客户端订单号
  ///
  /// 格式：{userId}_{timestamp}_{random6}
  /// - userId: 用户ID（如果为null则使用空字符串）
  /// - timestamp: 毫秒级时间戳
  /// - random6: 6位随机数（100000-999999）
  static String generate({int? userId}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(900000) + 100000; // 100000-999999

    if (userId != null) {
      return '${userId}_${timestamp}_$random';
    } else {
      // 如果用户ID为空，使用时间戳+随机数
      return '${timestamp}_$random';
    }
  }

  /// 生成带前缀的订单号
  ///
  /// 格式：{prefix}_{userId}_{timestamp}_{random6}
  /// 例如：ORD_123456_1707051234567_123456
  static String generateWithPrefix({
    required String prefix,
    int? userId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(900000) + 100000;

    if (userId != null) {
      return '${prefix}_${userId}_${timestamp}_$random';
    } else {
      return '${prefix}_${timestamp}_$random';
    }
  }
}
