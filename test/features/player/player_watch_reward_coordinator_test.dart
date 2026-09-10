import 'dart:async';

import 'package:drama_client/features/player/application/player_watch_reward_coordinator.dart';
import 'package:drama_client/features/player/data/shared_preferences_watch_reward_attempt_store.dart';
import 'package:drama_client/features/player/domain/watch_reward_repository.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_claim_result.dart';
import 'package:drama_client/features/rewards/domain/reward_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const coin = PlayerWatchRewardCoordinator.coinType;
const point = PlayerWatchRewardCoordinator.pointType;
RewardTask task(
  String key,
  int seconds, {
  String type = coin,
  bool claimed = false,
}) => RewardTask(
  claimed: claimed,
  completed: false,
  conditionText: '',
  cycleType: 'TASK_CYCLE_TYPE_DAILY',
  displayName: key,
  progressValue: 0,
  rewardMax: 10,
  rewardMin: 10,
  rewardType: type,
  targetValue: seconds,
  taskKey: key,
);
RewardCoinsCheckInClaimResult result(String status, {String type = coin}) =>
    RewardCoinsCheckInClaimResult(
      balance: 20,
      claimNo: 'c',
      grantedAt: '',
      rewardAmount: 10,
      rewardType: type,
      status: status,
    );

class Repository implements WatchRewardRepository {
  List<RewardTask> tasks = [task('300', 300)];
  final calls = <String>[];
  int listCalls = 0;
  bool failList = false;
  Future<List<RewardTask>> Function()? listHandler;
  Future<RewardCoinsCheckInClaimResult> Function(String)? claimHandler;
  @override
  Future<List<RewardTask>> getWatchTasks() async {
    listCalls++;
    if (failList) throw StateError('offline');
    return listHandler == null ? tasks : await listHandler!();
  }

  @override
  Future<RewardCoinsCheckInClaimResult> claim(String key) async {
    calls.add(key);
    return claimHandler == null
        ? result('CLAIM_STATUS_FAILED')
        : await claimHandler!(key);
  }
}

class Store implements WatchRewardAttemptStore {
  final data = <(String, String), Map<String, WatchRewardAttempt>>{};
  bool failWrite = false;
  Completer<void>? pendingWrite;
  @override
  Future<Map<String, WatchRewardAttempt>> read(String user, String day) async =>
      Map.of(data[(user, day)] ?? {});
  @override
  Future<void> write(
    String user,
    String day,
    Map<String, WatchRewardAttempt> attempts,
  ) async {
    await pendingWrite?.future;
    if (failWrite) throw StateError('disk');
    data[(user, day)] = Map.of(attempts);
  }
}

void main() {
  late Repository repository;
  late Store store;
  late PlayerWatchRewardCoordinator coordinator;
  late List<RewardCoinsCheckInClaimResult> successes;
  bool current = true;
  void update(
    int seconds, {
    String user = 'a',
    String day = '2026-09-10',
    String owner = 'player',
    bool visible = true,
  }) {
    coordinator.update(
      owner: owner,
      userId: user,
      dayKey: day,
      seconds: seconds,
      visible: visible,
      isCurrent: () => current,
      onSuccess: successes.add,
    );
  }

  setUp(() {
    repository = Repository();
    store = Store();
    current = true;
    successes = [];
    coordinator = PlayerWatchRewardCoordinator(
      repository: repository,
      attemptStore: store,
    );
  });
  tearDown(() => coordinator.dispose());

  test(
    '300, 360, 420, 480 and no fifth request; unchanged seconds never retry',
    () async {
      update(299);
      await coordinator.settled;
      expect(repository.listCalls, 1);
      expect(repository.calls, isEmpty);
      for (final seconds in [300, 359, 360, 419, 420, 479, 480, 481, 600]) {
        update(seconds);
        await coordinator.settled;
        update(seconds);
        await coordinator.settled;
      }
      expect(repository.calls, ['300', '300', '300', '300']);
      expect(successes, isEmpty);
    },
  );
  test('exceptions and all full non-success statuses silently retry', () async {
    for (final status in [
      'CLAIM_STATUS_PENDING',
      'CLAIM_STATUS_PROCESSING',
      'CLAIM_STATUS_RETRY',
      'CLAIM_STATUS_FAILED',
      'SUCCESS',
      'UNKNOWN',
    ]) {
      coordinator.dispose();
      repository.calls.clear();
      store.data.clear();
      coordinator = PlayerWatchRewardCoordinator(
        repository: repository,
        attemptStore: store,
      );
      repository.claimHandler = (_) async => result(status);
      update(300);
      await coordinator.settled;
      update(360);
      await coordinator.settled;
      expect(repository.calls.length, 2, reason: status);
      expect(successes, isEmpty, reason: status);
    }
    repository.claimHandler = (_) async => throw StateError('offline');
    update(420);
    await coordinator.settled;
    expect(repository.calls.length, 3);
    expect(successes, isEmpty);
  });
  test('threshold update in the finishing microtask is not lost', () async {
    update(299);
    await coordinator.settled;
    update(299); // no eligible task, drain is finishing
    update(300); // arrives before the finishing Future completes
    await coordinator.settled;
    expect(repository.calls, ['300']);
  });

  test(
    'old account success is persisted but never shown to new account',
    () async {
      final pending = Completer<RewardCoinsCheckInClaimResult>();
      repository.claimHandler = (_) => repository.calls.length == 1
          ? pending.future
          : Future.value(result('CLAIM_STATUS_FAILED'));
      update(300);
      await Future<void>.delayed(Duration.zero);
      update(300, user: 'b');
      pending.complete(result('CLAIM_STATUS_SUCCESS'));
      await coordinator.settled;
      expect(successes, isEmpty);
      expect(repository.calls, ['300', '300']);
      expect(store.data[('a', '2026-09-10')]!['300']!.succeeded, true);
      expect(store.data[('b', '2026-09-10')]!['300']!.succeeded, false);
    },
  );

  test('only CLAIM_STATUS_SUCCESS notifies once and stops retry', () async {
    repository.claimHandler = (_) async => result('CLAIM_STATUS_SUCCESS');
    update(300);
    await coordinator.settled;
    update(900);
    await coordinator.settled;
    coordinator.leave('player');
    update(900);
    await coordinator.settled;
    expect(repository.calls, ['300']);
    expect(successes.length, 1);
  });
  test(
    'next tier preempts old retry even when new task already claimed',
    () async {
      repository.tasks = [task('360', 360), task('300', 300)];
      update(300);
      await coordinator.settled;
      update(360);
      await coordinator.settled;
      update(420);
      await coordinator.settled;
      expect(repository.calls, ['300', '360', '360']);
      repository.tasks = [task('300', 300), task('360', 360, claimed: true)];
      coordinator.leave('player');
      update(480);
      await coordinator.settled;
      expect(repository.calls, ['300', '360', '360']);
    },
  );
  test(
    'coins and points advance independently, equal targets both claim',
    () async {
      repository.tasks = [
        task('coin300', 300),
        task('point300', 300, type: point),
        task('coin360', 360),
      ];
      repository.claimHandler = (key) async => result(
        'CLAIM_STATUS_SUCCESS',
        type: key.startsWith('point') ? point : coin,
      );
      update(360);
      await coordinator.settled;
      expect(repository.calls.toSet(), {'coin360', 'point300'});
      expect(successes.length, 2);
    },
  );
  test(
    'For You contributes seconds but cannot query or claim; player checks on entry',
    () async {
      update(350, owner: 'forYou', visible: false);
      await coordinator.settled;
      expect(repository.listCalls, 0);
      expect(repository.calls, isEmpty);
      update(350);
      await coordinator.settled;
      expect(repository.calls, ['300']);
      coordinator.leave('player');
      update(500, owner: 'forYou', visible: false);
      await coordinator.settled;
      expect(repository.calls, ['300']);
      update(500);
      await coordinator.settled;
      expect(repository.calls, ['300', '300']);
      // Late entry never sends all missed retry slots in a burst.
    },
  );
  test('retry budget survives page exit and coordinator restart', () async {
    for (final seconds in [300, 360, 420, 480]) {
      update(seconds);
      await coordinator.settled;
      coordinator.leave('player');
    }
    coordinator.dispose();
    coordinator = PlayerWatchRewardCoordinator(
      repository: repository,
      attemptStore: store,
    );
    update(900);
    await coordinator.settled;
    expect(repository.calls.length, 4);
    update(300, day: '2026-09-11');
    await coordinator.settled;
    expect(repository.calls.length, 5);
    update(300, user: 'b', day: '2026-09-11');
    await coordinator.settled;
    expect(repository.calls.length, 6);
  });
  test(
    'in-flight request is not duplicated; latest tier selected on completion',
    () async {
      final pending = Completer<RewardCoinsCheckInClaimResult>();
      repository.tasks = [task('300', 300), task('360', 360)];
      repository.claimHandler = (key) async =>
          key == '300' ? await pending.future : result('CLAIM_STATUS_FAILED');
      update(300);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 10; i++) {
        update(360);
      }
      expect(repository.calls, ['300']);
      pending.complete(result('CLAIM_STATUS_PENDING'));
      await coordinator.settled;
      expect(repository.calls, ['300', '360']);
    },
  );
  test(
    'leaving or background before response suppresses success toast',
    () async {
      final pending = Completer<RewardCoinsCheckInClaimResult>();
      repository.claimHandler = (_) => pending.future;
      update(300);
      await Future<void>.delayed(Duration.zero);
      current = false;
      coordinator.leave('player');
      pending.complete(result('CLAIM_STATUS_SUCCESS'));
      await coordinator.settled;
      expect(successes, isEmpty);
      current = true;
      update(500);
      await coordinator.settled;
      expect(repository.calls, ['300']);
    },
  );
  test(
    'stale user/day list cannot cause a claim or overwrite current tasks',
    () async {
      final pending = Completer<List<RewardTask>>();
      repository.listHandler = () => repository.listCalls == 1
          ? pending.future
          : Future.value([task('new', 300)]);
      update(300);
      await Future<void>.delayed(Duration.zero);
      update(300, user: 'b', day: '2026-09-11');
      pending.complete([task('old', 300)]);
      await coordinator.settled;
      expect(repository.calls, ['new']);
    },
  );
  test(
    'claimed tasks skip and backend completed false does not block client threshold',
    () async {
      repository.tasks = [
        task('claimed', 300, claimed: true),
        task('unclaimed', 300),
      ];
      update(300);
      await coordinator.settled;
      expect(repository.calls, ['unclaimed']);
    },
  );
  test(
    'list failure is silent and retried only after 60 additional effective seconds',
    () async {
      repository.failList = true;
      update(300);
      await coordinator.settled;
      update(359);
      await coordinator.settled;
      expect(repository.listCalls, 1);
      repository.failList = false;
      update(360);
      await coordinator.settled;
      expect(repository.listCalls, 2);
      expect(repository.calls, ['300']);
    },
  );
  test(
    'leaving during attempt persistence does not spend a network retry',
    () async {
      store.pendingWrite = Completer<void>();
      update(300);
      await Future<void>.delayed(Duration.zero);
      coordinator.leave('player');
      store.pendingWrite!.complete();
      await coordinator.settled;
      expect(repository.calls, isEmpty);
      expect(store.data[('a', '2026-09-10')]!['300']!.count, 0);
      update(300);
      await coordinator.settled;
      expect(repository.calls, ['300']);
    },
  );

  test(
    'grant event survives page exit while toast remains suppressed',
    () async {
      final grants = <String>[];
      coordinator.dispose();
      coordinator = PlayerWatchRewardCoordinator(
        repository: repository,
        attemptStore: store,
        onGranted: (userId, result) => grants.add(userId),
      );
      final pending = Completer<RewardCoinsCheckInClaimResult>();
      repository.claimHandler = (_) => pending.future;
      update(300);
      await Future<void>.delayed(Duration.zero);
      coordinator.leave('player');
      pending.complete(result('CLAIM_STATUS_SUCCESS'));
      await coordinator.settled;
      expect(grants, ['a']);
      expect(successes, isEmpty);
    },
  );

  test('storage failure prevents unrecorded requests', () async {
    store.failWrite = true;
    update(300);
    await coordinator.settled;
    expect(repository.calls, isEmpty);
    store.failWrite = false;
    update(359);
    await coordinator.settled;
    expect(repository.calls, isEmpty);
    update(360);
    await coordinator.settled;
    expect(repository.calls, ['300']);
  });
  test('wrong reward type success never presents a misleading toast', () async {
    repository.claimHandler = (_) async =>
        result('CLAIM_STATUS_SUCCESS', type: point);
    update(300);
    await coordinator.settled;
    update(360);
    await coordinator.settled;
    expect(successes, isEmpty);
    expect(repository.calls, ['300']);
  });
  test('attempt persistence is scoped by user and India date', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedPreferencesWatchRewardAttemptStore();
    await storage.write('a', '2026-09-10', {
      't': const WatchRewardAttempt(count: 4, lastAttemptSeconds: 480),
    });
    final restored = await SharedPreferencesWatchRewardAttemptStore().read(
      'a',
      '2026-09-10',
    );
    expect(restored['t']!.count, 4);
    expect(restored['t']!.lastAttemptSeconds, 480);
    expect(await storage.read('b', '2026-09-10'), isEmpty);
    expect(await storage.read('a', '2026-09-11'), isEmpty);
  });
}
