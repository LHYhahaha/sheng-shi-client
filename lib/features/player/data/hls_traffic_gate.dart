import 'package:flutter/foundation.dart';

/// HLS 请求所属的播放场景。
///
/// For You 暂停时只冻结它尚未命中的远端请求；已完成的内存/磁盘缓存始终可读，
/// 当前普通播放器也不会受影响。
enum HlsTrafficOwner {
  forYou('for_you'),
  playback('playback');

  const HlsTrafficOwner(this.queryValue);

  final String queryValue;

  static HlsTrafficOwner fromQuery(String? value) {
    return value == forYou.queryValue ? forYou : playback;
  }
}

/// 本地代理的轻量网络闸门。
///
/// 它不清空缓存，也不取消已经被普通播放器加入的 singleflight；冻结只阻止 For You
/// 再发起新的远端 HLS 请求。返回 For You 后解除冻结，原 session 与缓存可继续复用。
class HlsTrafficGate {
  bool _forYouSuspended = false;

  bool allowsRemoteFetch(HlsTrafficOwner owner) {
    return owner != HlsTrafficOwner.forYou || !_forYouSuspended;
  }

  void suspendForYou() {
    if (_forYouSuspended) return;
    _forYouSuspended = true;
    _log('for_you_suspend');
  }

  void resumeForYou() {
    if (!_forYouSuspended) return;
    _forYouSuspended = false;
    _log('for_you_resume');
  }

  void _log(String event) {
    const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
    if (!shouldPrint) return;
    debugPrint(
      '${DateTime.now().toIso8601String()} session=hls-traffic-gate event=$event',
    );
  }
}
