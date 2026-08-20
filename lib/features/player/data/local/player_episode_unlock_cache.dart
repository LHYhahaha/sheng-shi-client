/// 剧集解锁状态本地缓存。
///
/// 用于记录已解锁的剧集，避免UI闪烁（先显示锁定再显示解锁）。
class PlayerEpisodeUnlockCache {
  /// 解锁状态缓存。
  /// key: "dramaId:episodeId", value: 是否已解锁
  static final Map<String, bool> _unlockStatusCache = {};

  /// 获取缓存的解锁状态。
  static bool? getCachedUnlockStatus(String dramaId, String episodeId) {
    final key = _buildKey(dramaId, episodeId);
    return _unlockStatusCache[key];
  }

  /// 设置解锁状态。
  static void setUnlockStatus(
    String dramaId,
    String episodeId,
    bool isUnlocked,
  ) {
    final key = _buildKey(dramaId, episodeId);
    _unlockStatusCache[key] = isUnlocked;
  }

  /// 检查剧集是否已解锁（优先使用缓存）。
  /// 如果缓存中没有，则根据 episode.isLocked 判断。
  static bool isEpisodeUnlocked(
    String dramaId,
    String episodeId,
    bool isLocked,
  ) {
    final cachedStatus = getCachedUnlockStatus(dramaId, episodeId);
    if (cachedStatus != null) {
      return cachedStatus;
    }
    return !isLocked;
  }

  /// 清除指定剧集的缓存。
  static void clearCache(String dramaId, String episodeId) {
    final key = _buildKey(dramaId, episodeId);
    _unlockStatusCache.remove(key);
  }

  /// 详情接口返回的权益状态是权威数据。会员到期等服务端权益变化后，不能让
  /// 同一部剧旧会话留下的“已解锁”缓存继续覆盖新的 `is_unlocked` 结果。
  static void clearDramaCache(String dramaId) {
    final prefix = '$dramaId:';
    _unlockStatusCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 清除所有缓存。
  static void clearAllCache() {
    _unlockStatusCache.clear();
  }

  /// 获取缓存的所有键值。
  static Set<String> getCachedKeys() {
    return _unlockStatusCache.keys.toSet();
  }

  /// 构建缓存键。
  static String _buildKey(String dramaId, String episodeId) {
    return '$dramaId:$episodeId';
  }
}
