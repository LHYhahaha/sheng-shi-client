import 'dart:async';

import 'package:drama_client/features/gift/application/gift_drama_link_cache.dart';
import 'package:drama_client/features/gift/domain/gift_link_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates prefetch and reads within the TTL', () async {
    var calls = 0;
    final completer = Completer<GiftLinkData>();
    final gift = _gift();
    var now = DateTime(2026, 8, 27, 12);
    final cache = GiftDramaLinkCache(
      loader: ({required dramaId}) {
        calls++;
        return completer.future;
      },
      clock: () => now,
    );

    cache.prefetch(42);
    final fromTap = cache.get(42);

    expect(calls, 1);
    completer.complete(gift);
    expect(await fromTap, same(gift));

    now = now.add(const Duration(minutes: 4, seconds: 59));
    await cache.get(42);
    expect(calls, 1);
  });

  test('refreshes after expiry and after invalidation', () async {
    var calls = 0;
    var now = DateTime(2026, 8, 27, 12);
    final cache = GiftDramaLinkCache(
      loader: ({required dramaId}) async {
        calls++;
        return _gift();
      },
      clock: () => now,
    );

    await cache.get(42);
    now = now.add(const Duration(minutes: 5));
    await cache.get(42);
    cache.invalidate(42);
    await cache.get(42);

    expect(calls, 3);
  });

  test('does not cache failed responses', () async {
    var calls = 0;
    final cache = GiftDramaLinkCache(
      loader: ({required dramaId}) {
        calls++;
        return Future<GiftLinkData>.error(StateError('network'));
      },
    );

    await expectLater(cache.get(42), throwsStateError);
    await expectLater(cache.get(42), throwsStateError);
    expect(calls, 2);
  });

  test('refreshes on player re-entry even while cached', () async {
    var calls = 0;
    final cache = GiftDramaLinkCache(
      loader: ({required dramaId}) async {
        calls++;
        return _gift();
      },
    );

    await cache.get(42);
    await cache.refresh(42);

    expect(calls, 2);
  });
}

GiftLinkData _gift() => const GiftLinkData(
  available: true,
  benefitDays: 3,
  reGrantAt: '',
  remainCount: 2,
  shareCode: 'code',
  shareUrl: 'https://example.test',
  totalCount: 3,
  usedCount: 1,
  visible: true,
);
