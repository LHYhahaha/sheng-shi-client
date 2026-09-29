import 'dart:async';

import 'package:drama_client/features/player/application/player_playback_recovery_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes retries for the same playback task', () async {
    final coordinator = PlayerPlaybackRecoveryCoordinator(
      retryDelays: const [Duration.zero, Duration.zero],
    );
    addTearDown(coordinator.dispose);
    final attempts = <int>[];

    expect(
      coordinator.scheduleRetry(
        taskKey: 'for-you:episode-1:source-a',
        onRetry: attempts.add,
      ),
      isTrue,
    );
    expect(
      coordinator.scheduleRetry(
        taskKey: 'for-you:episode-1:source-a',
        onRetry: attempts.add,
      ),
      isFalse,
    );

    await Future<void>.delayed(Duration.zero);

    expect(attempts, [1]);
    expect(
      coordinator.scheduleRetry(
        taskKey: 'for-you:episode-1:source-a',
        onRetry: attempts.add,
      ),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
    expect(attempts, [1, 2]);
  });

  test('cancels a pending retry when the playback task changes', () async {
    final retryCompleter = Completer<void>();
    final coordinator = PlayerPlaybackRecoveryCoordinator(
      retryDelays: const [Duration(milliseconds: 10)],
    );
    addTearDown(coordinator.dispose);

    coordinator.scheduleRetry(
      taskKey: 'for-you:episode-1:source-a',
      onRetry: (_) => retryCompleter.complete(),
    );
    coordinator.cancel(taskKey: 'for-you:episode-1:source-a');

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(retryCompleter.isCompleted, isFalse);
  });
}
