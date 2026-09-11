import '../../rewards/domain/reward_coins_check_in_claim_result.dart';
import '../../rewards/domain/reward_task.dart';
import '../domain/watch_reward_repository.dart';

/// One application-wide coordinator; claims are serialized across pages and
/// reward types. It has no wall-clock retry timer and never owns playback time.
class PlayerWatchRewardCoordinator {
  PlayerWatchRewardCoordinator({
    required WatchRewardRepository repository,
    required WatchRewardAttemptStore attemptStore,
    void Function(String userId, RewardCoinsCheckInClaimResult result)?
    onGranted,
  }) : _repository = repository,
       _attemptStore = attemptStore,
       _onGranted = onGranted;

  static const coinType = 'REWARD_TYPE_BONUS_COIN';
  static const pointType = 'REWARD_TYPE_MEMBER_POINT';
  final WatchRewardRepository _repository;
  final WatchRewardAttemptStore _attemptStore;
  final void Function(String userId, RewardCoinsCheckInClaimResult result)?
  _onGranted;
  final _history = <(String, String), Map<String, WatchRewardAttempt>>{};
  List<RewardTask> _tasks = [];
  String? _owner;
  (String, String)? _scope;
  int _seconds = 0;
  int _generation = 0;
  int? _fetchRetryAt;
  bool _needsFetch = false;
  bool _running = false;
  bool _rerun = false;
  bool _disposed = false;
  bool Function()? _isCurrent;
  void Function(RewardCoinsCheckInClaimResult)? _onSuccess;
  Future<void> _work = Future.value();

  /// Awaitable only for callers/tests that need current requests to settle.
  Future<void> get settled => _work;

  void update({
    required String owner,
    required String userId,
    required String dayKey,
    required int seconds,
    required bool visible,
    required bool Function() isCurrent,
    required void Function(RewardCoinsCheckInClaimResult) onSuccess,
  }) {
    if (_disposed) return;
    if (!visible || userId.isEmpty) {
      leave(owner);
      return;
    }
    final scope = (userId, dayKey);
    if (_owner != owner || _scope != scope) {
      ++_generation;
      _tasks = [];
      _needsFetch = true;
      _fetchRetryAt = null;
      _history.removeWhere((key, _) => key != scope);
    }
    _owner = owner;
    _scope = scope;
    _seconds = seconds;
    _isCurrent = isCurrent;
    _onSuccess = onSuccess;
    if (_fetchRetryAt != null && seconds >= _fetchRetryAt!) {
      _needsFetch = true;
      _fetchRetryAt = null;
    }
    _kick();
  }

  void leave(String owner) {
    if (_owner != owner) return;
    ++_generation;
    _owner = null;
    _isCurrent = null;
    _onSuccess = null;
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _owner = null;
    _onSuccess = null;
    _isCurrent = null;
  }

  bool get _active =>
      !_disposed && _owner != null && _isCurrent?.call() == true;

  bool _valid(int generation) => _active && generation == _generation;

  void _kick() {
    if (!_active) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    _work = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _rerun = false;
        await _drain();
      } while (_rerun && _active);
    } finally {
      _running = false;
    }
  }

  Future<void> _drain() async {
    while (_active) {
      final generation = _generation;
      final scope = _scope!;
      if (_needsFetch) {
        _needsFetch = false;
        try {
          _history[scope] ??= await _attemptStore.read(scope.$1, scope.$2);
          if (!_valid(generation)) continue;
          final tasks = await _repository.getWatchTasks();
          if (!_valid(generation)) continue;
          _tasks = tasks
              .where(
                (task) =>
                    task.targetValue > 0 &&
                    task.taskKey.trim().isNotEmpty &&
                    (task.rewardType == coinType ||
                        task.rewardType == pointType) &&
                    (task.cycleType == 'TASK_CYCLE_TYPE_DAILY' ||
                        task.cycleType == 'TASK_CYCLE_TYPE_ONCE'),
              )
              .toList();
        } catch (_) {
          if (!_valid(generation)) continue;
          // A transient list/storage failure is silent, with no per-tick storm.
          _fetchRetryAt = _seconds + 60;
          return;
        }
      }
      if (!_valid(generation)) continue;
      final history = _history[scope];
      if (history == null) return;
      final task = _nextTask(history);
      if (task == null) return;
      final previous = history[task.taskKey] ?? const WatchRewardAttempt();
      final attempt = WatchRewardAttempt(
        count: previous.count + 1,
        lastAttemptSeconds: _seconds,
      );
      history[task.taskKey] = attempt;
      try {
        // Persist the consumed attempt before dispatch, also bounding retries
        // after an uncertain response or an app restart.
        await _attemptStore.write(scope.$1, scope.$2, Map.of(history));
      } catch (_) {
        // Retain the consumed attempt in memory; retry only after another 60s.
        return;
      }
      // Reservation is not a request. Leaving or reaching a newer tier while
      // storage is pending must not consume one of the four network attempts.
      if (!_valid(generation) || !_isLatestTier(task)) {
        history[task.taskKey] = previous;
        try {
          await _attemptStore.write(scope.$1, scope.$2, Map.of(history));
        } catch (_) {}
        continue;
      }
      RewardCoinsCheckInClaimResult? result;
      try {
        result = await _repository.claim(task.taskKey);
      } catch (_) {
        // Business errors, network errors and non-success states all use the
        // same bounded retry schedule, without a failure toast.
      }
      // Only the exact wire enum CLAIM_STATUS_SUCCESS means granted.
      if (result?.status == 'CLAIM_STATUS_SUCCESS') {
        history[task.taskKey] = WatchRewardAttempt(
          count: attempt.count,
          lastAttemptSeconds: attempt.lastAttemptSeconds,
          succeeded: true,
        );
        try {
          await _attemptStore.write(scope.$1, scope.$2, Map.of(history));
        } catch (_) {
          // Keep success in memory; the refreshed server list is authoritative.
        }
        if (result!.rewardType == task.rewardType) {
          // Balance refresh belongs to the account, not the departing page.
          // The provider validates that this is still the signed-in account.
          try {
            _onGranted?.call(scope.$1, result);
          } catch (_) {}
        }
        if (_valid(generation) && result.rewardType == task.rewardType) {
          try {
            _onSuccess?.call(result);
          } catch (_) {}
        }
      }
      // Always reselect using the latest total. Never resurrect a lower tier,
      // even when the new tier has already been claimed or exhausted retries.
    }
  }

  bool _isLatestTier(RewardTask task) => !_tasks.any(
    (other) =>
        other.rewardType == task.rewardType &&
        other.targetValue <= _seconds &&
        other.targetValue > task.targetValue,
  );

  RewardTask? _nextTask(Map<String, WatchRewardAttempt> history) {
    final sorted = [..._tasks]
      ..sort((a, b) {
        final byTarget = a.targetValue.compareTo(b.targetValue);
        return byTarget != 0 ? byTarget : a.taskKey.compareTo(b.taskKey);
      });
    for (final task in sorted) {
      if (task.claimed ||
          task.targetValue + 10 > _seconds ||
          !_isLatestTier(task)) {
        continue;
      }
      final attempt = history[task.taskKey] ?? const WatchRewardAttempt();
      if (attempt.succeeded || attempt.count >= 4) continue;
      if (attempt.count > 0 && _seconds < attempt.lastAttemptSeconds + 60) {
        continue;
      }
      return task;
    }
    return null;
  }
}
