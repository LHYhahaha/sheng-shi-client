import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 促销倒计时服务。
///
/// 管理一个共享的1小时倒计时，三个页面（会员开通、Store、播放页充值弹框）
/// 共享同一个计时器。进入任一页面时开始计时，离开后计时器继续运行。
/// 支持持久化，App重启后仍能继续倒计时。
class PromotionCountdownService {
  PromotionCountdownService();

  static const int _totalSeconds = 3600; // 1小时
  static const String _storageKey = 'promotion_countdown_start_time';

  DateTime? _startTime;
  Timer? _timer;
  final _listeners = <VoidCallback>{};

  /// 是否已开始计时。
  bool get isRunning => _startTime != null && !_isExpired;

  /// 是否已过期。
  bool get _isExpired {
    if (_startTime == null) return true;
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    return elapsed >= _totalSeconds;
  }

  /// 获取剩余秒数。
  int get remainingSeconds {
    if (_startTime == null) return 0;
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    final remaining = _totalSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// 从持久化存储加载开始时间。
  Future<void> loadStartTime() async {
    final preferences = await SharedPreferences.getInstance();
    final startTimeMs = preferences.getInt(_storageKey);
    if (startTimeMs != null) {
      _startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
      // 如果已过期，清除存储
      if (_isExpired) {
        await _clearStartTime();
        _startTime = null;
      }
    }
  }

  /// 开始计时（如果尚未开始）。
  Future<void> startIfNeeded() async {
    // 先尝试从持久化存储加载
    if (_startTime == null) {
      await loadStartTime();
    }

    if (_startTime == null || _isExpired) {
      _startTime = DateTime.now();
      await _saveStartTime();
      _startTimer();
    } else if (!_isExpired && _timer == null) {
      // 如果计时器未启动但时间未过期，重新启动计时器
      _startTimer();
    }
  }

  /// 保存开始时间到持久化存储。
  Future<void> _saveStartTime() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_storageKey, _startTime!.millisecondsSinceEpoch);
  }

  /// 清除持久化存储中的开始时间。
  Future<void> _clearStartTime() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  /// 重置计时器（用于测试或手动重置）。
  Future<void> reset() async {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    await _clearStartTime();
  }

  /// 添加监听器。
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除监听器。
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isExpired) {
        _timer?.cancel();
        _timer = null;
        _clearStartTime();
        _startTime = null;
      }
      _notifyListeners();
    });
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
  }
}

/// 全局促销倒计时服务 Provider。
final promotionCountdownServiceProvider =
    Provider<PromotionCountdownService>((ref) {
  final service = PromotionCountdownService();
  ref.onDispose(() => service.dispose());
  return service;
});
