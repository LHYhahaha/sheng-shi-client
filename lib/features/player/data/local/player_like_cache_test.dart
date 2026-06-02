import 'package:flutter_test/flutter_test.dart';

import 'player_like_cache.dart';

void main() {
  group('PlayerLikeCache', () {
    setUp(() {
      PlayerLikeCache.clearAllCache();
    });

    test('getCachedLikeStatus returns null for uncached dramaId', () {
      expect(PlayerLikeCache.getCachedLikeStatus('123'), isNull);
    });

    test('setLikeStatus and getCachedLikeStatus work correctly', () {
      PlayerLikeCache.setLikeStatus('123', true);
      expect(PlayerLikeCache.getCachedLikeStatus('123'), isTrue);

      PlayerLikeCache.setLikeStatus('123', false);
      expect(PlayerLikeCache.getCachedLikeStatus('123'), isFalse);
    });

    test('getCachedLikeCountDelta returns 0 for uncached dramaId', () {
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);
    });

    test('updateLikeCountDelta increments when liking', () {
      PlayerLikeCache.updateLikeCountDelta('123', true);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 1);

      PlayerLikeCache.updateLikeCountDelta('123', true);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 2);
    });

    test('updateLikeCountDelta decrements when unliking', () {
      PlayerLikeCache.updateLikeCountDelta('123', true);
      PlayerLikeCache.updateLikeCountDelta('123', true);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 2);

      PlayerLikeCache.updateLikeCountDelta('123', false);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 1);

      PlayerLikeCache.updateLikeCountDelta('123', false);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);
    });

    test('updateLikeCountDelta does not go below 0', () {
      PlayerLikeCache.updateLikeCountDelta('123', false);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);

      PlayerLikeCache.updateLikeCountDelta('123', false);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);
    });

    test('clearCache removes specific dramaId', () {
      PlayerLikeCache.setLikeStatus('123', true);
      PlayerLikeCache.updateLikeCountDelta('123', true);

      PlayerLikeCache.clearCache('123');

      expect(PlayerLikeCache.getCachedLikeStatus('123'), isNull);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);
    });

    test('clearAllCache removes all data', () {
      PlayerLikeCache.setLikeStatus('123', true);
      PlayerLikeCache.setLikeStatus('456', false);
      PlayerLikeCache.updateLikeCountDelta('123', true);

      PlayerLikeCache.clearAllCache();

      expect(PlayerLikeCache.getCachedLikeStatus('123'), isNull);
      expect(PlayerLikeCache.getCachedLikeStatus('456'), isNull);
      expect(PlayerLikeCache.getCachedLikeCountDelta('123'), 0);
    });

    test('getCachedDramaIds returns all cached dramaIds', () {
      PlayerLikeCache.setLikeStatus('123', true);
      PlayerLikeCache.setLikeStatus('456', false);
      PlayerLikeCache.updateLikeCountDelta('789', true);

      final ids = PlayerLikeCache.getCachedDramaIds();

      expect(ids, containsAll(['123', '456', '789']));
    });
  });
}
