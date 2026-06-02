/// 播放器点赞本地缓存管理。
///
/// 用于缓存点赞状态和点赞数的变化，由于后端接口返回的数据没有动态变化，
/// 所以在本地记录用户的点赞操作，以便立即更新 UI。
class PlayerLikeCache {
  /// 点赞状态缓存。
  /// key: dramaId, value: 是否点赞
  static final Map<String, bool> _likeStatusCache = {};

  /// 点赞数变化缓存。
  /// key: dramaId, value: 点赞数相对于初始值的变化量
  static final Map<String, int> _likeCountDeltaCache = {};

  /// 初始点赞数缓存。
  /// key: dramaId, value: 服务端返回的初始点赞数
  static final Map<String, int> _initialLikeCountCache = {};

  /// 获取缓存的点赞状态。
  static bool? getCachedLikeStatus(String dramaId) {
    return _likeStatusCache[dramaId];
  }

  /// 获取缓存的点赞数变化。
  static int getCachedLikeCountDelta(String dramaId) {
    return _likeCountDeltaCache[dramaId] ?? 0;
  }

  /// 获取初始点赞数。
  static int getCachedInitialLikeCount(String dramaId) {
    return _initialLikeCountCache[dramaId] ?? 0;
  }

  /// 设置点赞状态。
  static void setLikeStatus(String dramaId, bool isLiked) {
    _likeStatusCache[dramaId] = isLiked;
  }

  /// 设置初始点赞数。
  /// 当从服务端获取到点赞数时，需要调用此方法更新缓存。
  static void setInitialLikeCount(String dramaId, int count) {
    _initialLikeCountCache[dramaId] = count;
  }

  /// 更新点赞数变化。
  /// 点赞时 +1，取消点赞时 -1，最小值为 0。
  static void updateLikeCountDelta(String dramaId, bool isLiked) {
    final currentDelta = _likeCountDeltaCache[dramaId] ?? 0;
    
    if (isLiked) {
      // 点赞：增加 1
      _likeCountDeltaCache[dramaId] = currentDelta + 1;
    } else {
      // 取消点赞：减少 1，最小值为 0
      _likeCountDeltaCache[dramaId] = (currentDelta - 1).clamp(0, double.infinity).toInt();
    }
  }

  /// 清除指定 dramaId 的缓存。
  static void clearCache(String dramaId) {
    _likeStatusCache.remove(dramaId);
    _likeCountDeltaCache.remove(dramaId);
    _initialLikeCountCache.remove(dramaId);
  }

  /// 清除所有缓存。
  static void clearAllCache() {
    _likeStatusCache.clear();
    _likeCountDeltaCache.clear();
    _initialLikeCountCache.clear();
  }

  /// 获取缓存的所有 dramaId。
  static Set<String> getCachedDramaIds() {
    return {..._likeStatusCache.keys, ..._likeCountDeltaCache.keys, ..._initialLikeCountCache.keys};
  }
}
