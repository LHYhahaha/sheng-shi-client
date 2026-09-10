import 'dart:async';
import 'dart:convert';

import 'package:drama_client/core/auth/user_info_store.dart';
import 'package:drama_client/features/player/application/daily_effective_watch_controller.dart';
import 'package:drama_client/features/player/data/shared_preferences_daily_effective_watch_repository.dart';
import 'package:drama_client/features/player/domain/daily_effective_watch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends UserInfoStore {
  @override
  UserInfoSnapshot build() => const UserInfoSnapshot(userId: 'a');
  void change(String? user) => state = UserInfoSnapshot(userId: user);
}

class _Repository implements DailyEffectiveWatchRepository {
  final values = <(String, String), DailyEffectiveWatchSnapshot>{};
  bool failWrite = false;
  Completer<void>? pendingRead;
  @override
  Future<DailyEffectiveWatchSnapshot?> read(String user, String day) async {
    await pendingRead?.future;
    return values[(user, day)];
  }

  @override
  Future<void> write(DailyEffectiveWatchSnapshot snapshot) async {
    if (failWrite) throw StateError('disk unavailable');
    values[(snapshot.userId, snapshot.dayKey)] = snapshot;
  }
}

void main() {
  test(
    'IST day uses UTC instant including device offsets and year boundary',
    () {
      expect(
        IndiaWatchDay.key(DateTime.parse('2026-09-11T02:29:59+08:00')),
        '2026-09-10',
      );
      expect(
        IndiaWatchDay.key(DateTime.parse('2026-09-10T18:30:00Z')),
        '2026-09-11',
      );
      expect(
        IndiaWatchDay.key(DateTime.parse('2026-09-11T00:00:00+05:30')),
        '2026-09-11',
      );
      expect(
        IndiaWatchDay.nextBoundary(DateTime.utc(2026, 12, 31, 18, 30)),
        DateTime.utc(2027, 1, 1, 18, 30),
      );
    },
  );

  test(
    'interval union retains skipped holes and credits only unseen proportion',
    () {
      var ledger = DailyEffectiveWatchSnapshot(
        userId: 'a',
        dayKey: '2026-09-10',
      );
      void credit(int start, int end, double elapsed) {
        ledger = ledger.credit(
          dramaId: 'd',
          episodeId: 'e',
          startMs: start,
          endMs: end,
          elapsedMs: elapsed,
        );
      }

      credit(0, 20000, 10000); // 2x
      credit(10000, 30000, 10000); // half repeated
      expect(ledger.totalEffectiveMs, 15000);
      credit(40000, 45000, 10000); // 0.5x
      credit(0, 45000, 45000); // only the 30–40 second hole is new
      expect(ledger.totalEffectiveMs, 35000);
      credit(0, 45000, 90000);
      expect(ledger.totalEffectiveMs, 35000);
      expect(ledger.ranges.values.single.length, 1);
      expect(ledger.ranges.values.single.single.endMs, 45000);
    },
  );

  test(
    'fractional elapsed credit survives many small overlapping segments',
    () {
      var ledger = DailyEffectiveWatchSnapshot(
        userId: 'a',
        dayKey: '2026-09-10',
      );
      for (var i = 0; i < 1000; i++) {
        ledger = ledger.credit(
          dramaId: 'd',
          episodeId: 'e',
          startMs: i,
          endMs: i + 1,
          elapsedMs: 0.5,
        );
      }
      expect(ledger.totalEffectiveMs, 500);
    },
  );

  group('continuous media samples', () {
    late EffectiveWatchAccumulator tracker;
    late int time;
    setUp(() {
      tracker = EffectiveWatchAccumulator();
      time = 0;
    });
    EffectiveWatchSegment? sample(
      int position, {
      int dt = 1000,
      String owner = 'player',
      int generation = 1,
      double rate = 1,
      int clockOffset = 0,
    }) {
      time += dt;
      return tracker.observe(
        EffectiveWatchSample(
          owner: owner,
          userId: 'a',
          dramaId: 'd',
          episodeId: 'e',
          generation: generation,
          positionMs: position,
          monotonic: Duration(milliseconds: time),
          utc: DateTime.utc(
            2026,
            9,
            10,
          ).add(Duration(milliseconds: time + clockOffset)),
          rate: rate,
        ),
      );
    }

    test('seeks, stalls, long gaps and clock jumps do not accrue', () {
      expect(sample(0), null);
      expect(sample(1000), isNotNull);
      expect(sample(1000), null);
      expect(sample(2000), isNotNull);
      expect(sample(60000), null);
      expect(sample(61000, generation: 2), null);
      expect(sample(62000, dt: 30000, generation: 2), null);
      expect(sample(63000, generation: 2, clockOffset: 10000), null);
    });
    test(
      'pause and owner switch start fresh; stale owner cannot stop current',
      () {
        sample(0);
        sample(1000);
        tracker.stop('player');
        expect(sample(2000), null);
        expect(sample(3000, owner: 'forYou'), null);
        tracker.stop('player');
        expect(sample(4000, owner: 'forYou'), isNotNull);
      },
    );
    test('speed changes reset baseline and preserve actual elapsed time', () {
      sample(0, rate: 2);
      final fast = sample(2000, rate: 2)!;
      expect(
        fast.end.monotonic - fast.start.monotonic,
        const Duration(seconds: 1),
      );
      expect(sample(2500, rate: 0.5), null);
      expect(sample(3000, rate: 0.5), isNotNull);
      expect(sample(0, rate: 0.5), null); // loop
    });
  });

  group('global cache', () {
    late ProviderContainer container;
    late DailyEffectiveWatchController controller;
    late _Repository repository;
    late DateTime now;
    late int monotonic;
    setUp(() {
      now = DateTime.utc(2026, 9, 10, 12);
      monotonic = 0;
      repository = _Repository();
      container = ProviderContainer(
        overrides: [
          userInfoStoreProvider.overrideWith(_User.new),
          dailyEffectiveWatchRepositoryProvider.overrideWithValue(repository),
          dailyEffectiveWatchClockProvider.overrideWithValue(() => now),
        ],
      );
      controller = container.read(
        dailyEffectiveWatchControllerProvider.notifier,
      );
    });
    tearDown(() => container.dispose());
    void sample(
      int position, {
      int dt = 1000,
      String user = 'a',
      String owner = 'player',
      double rate = 1,
    }) {
      now = now.add(Duration(milliseconds: dt));
      monotonic += dt;
      controller.observe(
        owner: owner,
        userId: user,
        dramaId: 'd',
        episodeId: 'e',
        generation: 1,
        position: Duration(milliseconds: position),
        rate: rate,
        monotonic: Duration(milliseconds: monotonic),
      );
    }

    int getTotal() =>
        container.read(dailyEffectiveWatchControllerProvider).totalEffectiveMs;

    test(
      'For You and player share replay exclusion; 2x and 0.5x use wall time',
      () async {
        sample(0, rate: 2, owner: 'forYou');
        sample(2000, rate: 2, owner: 'forYou');
        controller.stop('forYou');
        sample(0, rate: 0.5);
        for (var pos = 500; pos <= 2500; pos += 500) {
          sample(pos, rate: 0.5);
        }
        await controller.flush();
        expect(
          getTotal(),
          2000,
        ); // 1s first viewing + 1s new 500ms at half speed
      },
    );
    test('midnight splits segment and resets daily coverage', () async {
      now = DateTime.utc(2026, 9, 10, 18, 29, 59, 500);
      sample(0, dt: 0);
      sample(1000);
      await controller.flush();
      expect(repository.values[('a', '2026-09-10')]!.totalEffectiveMs, 500);
      expect(getTotal(), 500);
      expect(
        container.read(dailyEffectiveWatchControllerProvider).dayKey,
        '2026-09-11',
      );
      controller.stop('player');
      sample(0);
      sample(1000);
      await controller.flush();
      expect(getTotal(), 1000); // only today's not-yet-seen first half
    });
    test('queued loading and account switch cannot mix users', () async {
      repository.pendingRead = Completer<void>();
      sample(0);
      sample(1000);
      (container.read(userInfoStoreProvider.notifier) as _User).change('b');
      sample(0, user: 'b');
      sample(1000, user: 'b');
      sample(2000, user: 'a'); // stale callback is rejected
      repository.pendingRead!.complete();
      await controller.flush();
      expect(getTotal(), 1000);
      expect(repository.values[('a', '2026-09-10')]!.totalEffectiveMs, 1000);
      expect(repository.values[('b', '2026-09-10')]!.totalEffectiveMs, 1000);
      (container.read(userInfoStoreProvider.notifier) as _User).change(null);
      await controller.flush();
      expect(
        container.read(dailyEffectiveWatchControllerProvider).ready,
        false,
      );
      (container.read(userInfoStoreProvider.notifier) as _User).change('a');
      await controller.flush();
      expect(getTotal(), 1000);
    });
    test(
      'failed persistence remains dirty and retries without losing totals',
      () async {
        repository.failWrite = true;
        sample(0);
        sample(1000);
        await controller.flush();
        expect(getTotal(), 1000);
        expect(repository.values, isEmpty);
        repository.failWrite = false;
        await controller.flush();
        expect(repository.values.values.single.totalEffectiveMs, 1000);
      },
    );
    test(
      'foreground refresh at IST boundary clears stale visible total',
      () async {
        sample(0);
        sample(1000);
        controller.stop('player');
        await controller.flush();
        now = DateTime.utc(2026, 9, 10, 18, 30);
        await controller.flush();
        expect(getTotal(), 0);
      },
    );
  });

  group('SharedPreferences persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    test('restart restores elapsed time and exact dedup intervals', () async {
      final repository = SharedPreferencesDailyEffectiveWatchRepository();
      final ledger =
          DailyEffectiveWatchSnapshot(userId: 'a', dayKey: '2026-09-10').credit(
            dramaId: 'd',
            episodeId: 'e',
            startMs: 0,
            endMs: 2000,
            elapsedMs: 1000.5,
          );
      await repository.write(ledger);
      final restored = (await SharedPreferencesDailyEffectiveWatchRepository()
          .read('a', '2026-09-10'))!;
      expect(restored.creditedMs, 1000.5);
      expect(
        restored
            .credit(
              dramaId: 'd',
              episodeId: 'e',
              startMs: 0,
              endMs: 3000,
              elapsedMs: 3000,
            )
            .creditedMs,
        2000.5,
      );
      expect(await repository.read('b', '2026-09-10'), null);
    });
    test(
      'malformed or overlapping coverage is rejected, old days expire',
      () async {
        final prefs = await SharedPreferences.getInstance();
        const key = 'player.daily_effective_watch.v1.a.2026-09-10';
        await prefs.setString(key, '{broken');
        final repository = SharedPreferencesDailyEffectiveWatchRepository();
        expect(await repository.read('a', '2026-09-10'), null);
        await prefs.setString(
          key,
          jsonEncode({
            'version': 1,
            'dayPolicy': 'india-ist-v1',
            'userId': 'a',
            'dayKey': '2026-09-10',
            'creditedMs': 1,
            'ranges': {
              jsonEncode(['d', 'e']): [
                [0, 1000],
                [500, 1500],
              ],
            },
          }),
        );
        expect(await repository.read('a', '2026-09-10'), null);
        await repository.write(
          DailyEffectiveWatchSnapshot(userId: 'a', dayKey: '2026-09-03'),
        );
        await repository.write(
          DailyEffectiveWatchSnapshot(userId: 'a', dayKey: '2026-09-10'),
        );
        expect(await repository.read('a', '2026-09-03'), null);
      },
    );
  });
}
