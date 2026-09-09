import 'dart:async';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/user_library/user_library_sync_controller.dart';
import 'package:drama_client/features/player/application/player_auto_favorite_tracker.dart';
import 'package:drama_client/features/player/application/player_like_controller.dart';
import 'package:drama_client/features/player/data/player_auto_favorite_history.dart';
import 'package:drama_client/features/player/data/player_remote_data_source_provider.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Remote extends PlayerRemoteDataSource {
  _Remote() : super(apiClient: ApiClient());
  int calls = 0;
  bool fail = false;
  bool followed = false;
  Completer<void>? pending;

  @override
  Future<bool> checkShortFollowStatus({required int dramaId}) async => followed;

  @override
  Future<void> followShort({required int dramaId}) async {
    calls++;
    if (fail) throw StateError('offline');
    await pending?.future;
  }

  @override
  Future<void> unfollowShort({required int dramaId}) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('continuous playback', () {
    late Duration now;
    late PlayerAutoFavoriteTracker tracker;
    setUp(() {
      now = Duration.zero;
      tracker = PlayerAutoFavoriteTracker(now: () => now);
    });
    bool play(
      int episode, {
      bool effective = true,
      String user = 'u',
      String drama = 'd',
    }) => tracker.observe(
      userId: user,
      dramaId: drama,
      episodeId: '$episode',
      episodeNumber: episode,
      effectivePlaying: effective,
    );

    test('inclusive threshold, only on a subsequent forward start', () {
      expect(play(1), false);
      now += const Duration(milliseconds: 119999);
      expect(play(2), false);
      now += const Duration(milliseconds: 1);
      expect(play(2), false);
      expect(play(3), true);
      expect(play(3), false);
    });

    test('second episode and forward jumps qualify; backward does not', () {
      play(1);
      now += const Duration(seconds: 121);
      expect(play(4), true);
      expect(play(1), false);
      expect(play(4), true);
    });

    test('pause, background, loading and trial do not accrue time', () {
      play(1);
      now += const Duration(seconds: 59);
      play(1, effective: false);
      now += const Duration(hours: 1);
      play(1);
      now += const Duration(seconds: 60);
      expect(play(2), false);
      play(3, effective: false);
      now += const Duration(minutes: 5);
      expect(play(4), false);
      now += const Duration(seconds: 1);
      expect(play(5), true);
    });

    test('trial does not count as an episode', () {
      play(1, effective: false);
      now += const Duration(seconds: 150);
      expect(play(2), false);
      now += const Duration(seconds: 121);
      expect(play(2), false);
      expect(play(3), true);
    });

    test(
      'repeated episode is deduplicated; identity and route reset statistics',
      () {
        play(1);
        now += const Duration(seconds: 121);
        tracker.pause();
        expect(play(1), false);
        expect(play(2, user: 'other'), false);
        expect(play(3, drama: 'other'), false);
        tracker.reset();
        expect(play(4), false);
      },
    );
  });

  group('automatic mutation', () {
    late _Remote remote;
    late ProviderContainer container;
    late PlayerLikeController controller;
    setUp(() {
      remote = _Remote();
      container = ProviderContainer(
        overrides: [playerRemoteDataSourceProvider.overrideWithValue(remote)],
      );
      container.listen(playerLikeControllerProvider('42'), (_, _) {});
      controller = container.read(playerLikeControllerProvider('42').notifier);
      addTearDown(container.dispose);
    });

    test(
      'waits for confirmation, deduplicates requests, persists across instances and unfollow',
      () async {
        remote.pending = Completer<void>();
        final request = controller.autoFavorite(
          userId: 'u',
          isCurrent: () => true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(remote.calls, 1);
        expect(
          container.read(playerLikeControllerProvider('42')).isLiked,
          false,
        );
        expect(
          await controller.autoFavorite(userId: 'u', isCurrent: () => true),
          false,
        );
        remote.pending!.complete();
        expect(await request, true);
        expect(
          container.read(playerLikeControllerProvider('42')).isLiked,
          true,
        );
        expect(
          container.read(playerLikeControllerProvider('42')).likeCountDelta,
          1,
        );
        expect(
          container.read(userLibrarySyncControllerProvider).favoriteFor('42'),
          true,
        );
        await controller.toggleLike();
        expect(await PlayerAutoFavoriteHistory().hasSucceeded('u', '42'), true);
        expect(
          await controller.autoFavorite(userId: 'u', isCurrent: () => true),
          false,
        );
        expect(remote.calls, 1);
        expect(
          await PlayerAutoFavoriteHistory().hasSucceeded('other', '42'),
          false,
        );
        expect(
          await PlayerAutoFavoriteHistory().hasSucceeded('u', '43'),
          false,
        );
      },
    );

    test('failure is silent and can retry', () async {
      remote.fail = true;
      expect(
        await controller.autoFavorite(userId: 'u', isCurrent: () => true),
        false,
      );
      expect(container.read(playerLikeControllerProvider('42')).error, null);
      expect(await PlayerAutoFavoriteHistory().hasSucceeded('u', '42'), false);
      remote.fail = false;
      expect(
        await controller.autoFavorite(userId: 'u', isCurrent: () => true),
        true,
      );
      expect(remote.calls, 2);
    });

    test(
      'existing favorite does not consume the automatic opportunity',
      () async {
        remote.followed = true;
        expect(
          await controller.autoFavorite(userId: 'u', isCurrent: () => true),
          false,
        );
        expect(remote.calls, 0);
        expect(
          await PlayerAutoFavoriteHistory().hasSucceeded('u', '42'),
          false,
        );
        await controller.toggleLike();
        expect(
          await controller.autoFavorite(userId: 'u', isCurrent: () => true),
          true,
        );
      },
    );

    test(
      'late success records original user without changing the new page',
      () async {
        var current = true;
        remote.pending = Completer<void>();
        final request = controller.autoFavorite(
          userId: 'u',
          isCurrent: () => current,
        );
        await Future<void>.delayed(Duration.zero);
        current = false;
        remote.pending!.complete();
        expect(await request, false);
        expect(await PlayerAutoFavoriteHistory().hasSucceeded('u', '42'), true);
        expect(
          container.read(playerLikeControllerProvider('42')).isLiked,
          false,
        );
      },
    );

    test(
      'provider invalidation during request does not overwrite fresh state',
      () async {
        remote.pending = Completer<void>();
        final request = controller.autoFavorite(
          userId: 'u',
          isCurrent: () => true,
        );
        await Future<void>.delayed(Duration.zero);
        container.invalidate(playerLikeControllerProvider('42'));
        expect(
          container.read(playerLikeControllerProvider('42')).isLiked,
          false,
        );
        remote.pending!.complete();
        expect(await request, false);
        expect(await PlayerAutoFavoriteHistory().hasSucceeded('u', '42'), true);
        expect(
          container.read(playerLikeControllerProvider('42')).isLiked,
          false,
        );
      },
    );
  });
}
