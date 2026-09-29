import 'package:drama_client/features/player/application/player_playback_recovery_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = PlayerPlaybackRecoveryPolicy();

  test('classifies transient transport failures as recoverable', () {
    expect(
      policy.classifyError('Connection timed out while loading segment'),
      PlayerPlaybackErrorKind.recoverableNetwork,
    );
  });

  test('classifies HTTP source failures as non-retriable source errors', () {
    expect(
      policy.classifyError('HLS request failed with HTTP 404'),
      PlayerPlaybackErrorKind.sourceResolve,
    );
  });

  test('only allows the initial automatic first-frame recovery', () {
    expect(
      policy.shouldAutoRetryFirstFrameTimeout(
        hasAlreadyRetried: false,
        isCurrentItem: true,
        hasSource: true,
        hasFirstFrame: false,
        isPaused: false,
      ),
      isTrue,
    );
    expect(
      policy.shouldAutoRetryFirstFrameTimeout(
        hasAlreadyRetried: true,
        isCurrentItem: true,
        hasSource: true,
        hasFirstFrame: false,
        isPaused: false,
      ),
      isFalse,
    );
  });
}
