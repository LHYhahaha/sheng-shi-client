import 'dart:async';

import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/entitlement_feature_config.dart';
import 'package:drama_client/features/entitlement/domain/episode_access_decision.dart';
import 'package:drama_client/features/entitlement/domain/entitlement_repository.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'load failure falls back to guest-safe state without throwing',
    () async {
      final container = ProviderContainer(
        overrides: [
          entitlementRepositoryProvider.overrideWith((ref) {
            throw StateError('entitlement service unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(entitlementControllerProvider.notifier).load();

      final state = container.read(entitlementControllerProvider);
      expect(state.isGuest, isTrue);
      expect(state.isMember, isFalse);
      expect(state.coinBalance, 0);
    },
  );

  test('coalesces concurrent entitlement refreshes', () async {
    final repository = _DelayedEntitlementRepository();
    final container = ProviderContainer(
      overrides: [entitlementRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(entitlementControllerProvider.notifier);

    final first = controller.refreshFromServer();
    await repository.started.future;
    final second = controller.refreshFromServer();

    expect(repository.fetchCalls, 1);
    repository.complete();
    await Future.wait([first, second]);
    expect(repository.fetchCalls, 1);
  });

  group('EntitlementController decision matrix', () {
    test('free episode allows guest/member/non-member', () async {
      for (final repository in <MockEntitlementRepository>[
        MockEntitlementRepository.guest(),
        MockEntitlementRepository.loggedInNonMemberLowCoins(),
        MockEntitlementRepository.loggedInMember(),
      ]) {
        final container = _containerWith(repository);
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('found-you-ep-1'),
        );

        expect(decision.type, EpisodeAccessDecisionType.allowPlay);
        expect(
          container.read(entitlementControllerProvider).pendingUnlock,
          isNull,
        );
      }
    });

    test('membership episode allows member', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInMember(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('heart-thief-ep-1'),
      );

      expect(decision.type, EpisodeAccessDecisionType.allowPlay);
    });

    test(
      'member can play coins episode without coin deduction decision',
      () async {
        final container = _containerWith(
          MockEntitlementRepository.loggedInMember(),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('found-you-ep-6'),
        );

        expect(decision.type, EpisodeAccessDecisionType.allowPlay);
        expect(decision.balance, 20);
        expect(decision.operationId, isNull);
        expect(
          container.read(entitlementControllerProvider).pendingUnlock,
          isNull,
        );
      },
    );

    test('membership episode sends non-member to membership', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('heart-thief-ep-1'),
      );

      expect(decision.type, EpisodeAccessDecisionType.goMembership);
      expect(decision.reason, 'membership_required');
      expect(
        container.read(entitlementControllerProvider).pendingUnlock?.episodeId,
        'heart-thief-ep-1',
      );
    });

    test(
      'ad-unlocked membership episode allows a non-member to play',
      () async {
        final container = _containerWith(
          MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        controller.updateAfterAdUnlock(episodeId: 'heart-thief-ep-1');
        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('heart-thief-ep-1'),
        );

        expect(decision.type, EpisodeAccessDecisionType.allowPlay);
        expect(
          container.read(entitlementControllerProvider).pendingUnlock,
          isNull,
        );
      },
    );

    test(
      'coin episode already unlocked allows play and does not deduct',
      () async {
        final container = _containerWith(
          MockEntitlementRepository.partialUnlocks(),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('found-you-ep-4'),
        );
        expect(decision.type, EpisodeAccessDecisionType.allowPlay);

        final beforeBalance = container
            .read(entitlementControllerProvider)
            .coinBalance;
        final unlockDecision = await controller.unlockWithCoins(
          dramaId: 'found-you',
          episodeId: 'found-you-ep-4',
          itemId: 'found-you-0-ep-4',
          price: 30,
          operationId: 'already-unlocked-op',
        );

        expect(unlockDecision.type, EpisodeAccessDecisionType.allowPlay);
        expect(
          container.read(entitlementControllerProvider).coinBalance,
          beforeBalance,
        );
        expect(
          container
              .read(entitlementControllerProvider)
              .unlockedEpisodeIds
              .contains('found-you-ep-4'),
          isTrue,
        );
      },
    );

    test(
      'coin episode enough balance and auto on returns auto unlock and play',
      () async {
        final container = _containerWith(
          MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('found-you-ep-5'),
        );

        expect(decision.type, EpisodeAccessDecisionType.autoUnlockAndPlay);
        expect(decision.operationId, 'coin-unlock:found-you:found-you-ep-5');
        expect(decision.balance, 4000);
        expect(decision.reason, 'auto_unlock_enabled');
      },
    );

    test(
      'coin episode enough balance and auto off returns coin dialog',
      () async {
        final container = _containerWith(
          MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
        );
        addTearDown(container.dispose);
        final controller = container.read(
          entitlementControllerProvider.notifier,
        );
        await controller.load();

        final decision = controller.evaluateAccessFromFixture(
          mockEntitlementEpisodeFixture('found-you-ep-5'),
        );

        expect(decision.type, EpisodeAccessDecisionType.showCoinUnlockDialog);
        expect(decision.reason, 'auto_unlock_disabled');
      },
    );

    test('coin episode auto unlock off returns coin dialog', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-5'),
      );

      expect(decision.type, EpisodeAccessDecisionType.showCoinUnlockDialog);
      expect(decision.reason, 'auto_unlock_disabled');
    });

    test('coin episode insufficient balance returns recharge dialog', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberLowCoins(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-5'),
      );

      expect(decision.type, EpisodeAccessDecisionType.showRechargeDialog);
      expect(decision.balance, 10);
      expect(decision.reason, 'insufficient_coins');
    });

    test('coin unlock disabled waits unlock', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
        config: const EntitlementFeatureConfig(enableCoinUnlock: false),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-5'),
      );

      expect(decision.type, EpisodeAccessDecisionType.waitUnlock);
      expect(decision.reason, 'coin_unlock_disabled');
    });

    test('unavailable episode waits unlock', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-unavailable'),
      );

      expect(decision.type, EpisodeAccessDecisionType.waitUnlock);
      expect(decision.reason, 'episode_unavailable');
    });

    test('unavailable episode is still blocked for member', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInMember(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-unavailable'),
      );

      expect(decision.type, EpisodeAccessDecisionType.waitUnlock);
      expect(decision.reason, 'episode_unavailable');
    });
  });

  group('EntitlementController actions', () {
    test('unlockWithCoins deducts once and adds unlocked episode', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = await controller.unlockWithCoins(
        dramaId: 'found-you',
        episodeId: 'found-you-ep-5',
        itemId: 'found-you-0-ep-5',
        price: 50,
        operationId: 'unlock-ep-5',
      );

      final state = container.read(entitlementControllerProvider);
      expect(decision.type, EpisodeAccessDecisionType.allowPlay);
      expect(state.coinBalance, 3950);
      expect(state.unlockedEpisodeIds, contains('found-you-ep-5'));
      expect(state.inFlightUnlockEpisodeId, isNull);
      expect(state.lastUnlockError, isNull);
    });

    test('same operationId does not double deduct', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      for (var i = 0; i < 2; i++) {
        await controller.unlockWithCoins(
          dramaId: 'found-you',
          episodeId: 'found-you-ep-6',
          itemId: 'found-you-0-ep-6',
          price: 80,
          operationId: 'same-op',
        );
      }

      final state = container.read(entitlementControllerProvider);
      expect(state.coinBalance, 3920);
      expect(state.unlockedEpisodeIds, contains('found-you-ep-6'));
    });

    test('deduct failure does not add unlocked episode', () async {
      final container = _containerWith(
        MockEntitlementRepository.deductFailsOnce(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      final decision = await controller.unlockWithCoins(
        dramaId: 'found-you',
        episodeId: 'found-you-ep-5',
        itemId: 'found-you-0-ep-5',
        price: 50,
        operationId: 'fail-once',
      );

      final state = container.read(entitlementControllerProvider);
      expect(decision.type, EpisodeAccessDecisionType.waitUnlock);
      expect(decision.reason, 'coin_deduction_failed');
      expect(state.coinBalance, 4000);
      expect(state.unlockedEpisodeIds, isNot(contains('found-you-ep-5')));
      expect(state.inFlightUnlockEpisodeId, isNull);
      expect(state.lastUnlockError, isA<StateError>());
    });

    test('setAutoUnlockEnabled updates state', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      await controller.setAutoUnlockEnabled(true);

      expect(
        container.read(entitlementControllerProvider).autoUnlockEnabled,
        isTrue,
      );
    });

    test('grantMockMembership updates isMember', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberLowCoins(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      await controller.grantMockMembership(source: 'membership-mock-success');

      final state = container.read(entitlementControllerProvider);
      expect(state.isGuest, isFalse);
      expect(state.isMember, isTrue);
    });

    test('grantMockCoins updates coinBalance', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberLowCoins(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      await controller.grantMockCoins(
        amount: 200,
        source: 'recharge-mock-success',
      );

      expect(container.read(entitlementControllerProvider).coinBalance, 210);
    });

    test('clearPendingUnlock removes pending target', () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberLowCoins(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      controller.evaluateAccessFromFixture(
        mockEntitlementEpisodeFixture('found-you-ep-5'),
      );
      expect(
        container.read(entitlementControllerProvider).pendingUnlock,
        isNotNull,
      );

      controller.clearPendingUnlock();

      expect(
        container.read(entitlementControllerProvider).pendingUnlock,
        isNull,
      );
    });
  });

  test(
    'ad unlock marks the episode as unlocked for subsequent access checks',
    () async {
      final container = _containerWith(
        MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
      );
      addTearDown(container.dispose);
      final controller = container.read(entitlementControllerProvider.notifier);
      await controller.load();

      controller.updateAfterAdUnlock(episodeId: 'found-you-ep-5');

      expect(
        container
            .read(entitlementControllerProvider)
            .isEpisodeUnlocked('found-you-ep-5'),
        isTrue,
      );
    },
  );

  test('future feature switches default false except coin unlock', () {
    const config = EntitlementFeatureConfig();

    expect(config.enableCoinUnlock, isTrue);
    expect(config.enableAdUnlock, isFalse);
    expect(config.enableWholeDramaPurchase, isFalse);
    expect(config.enableCouponUnlock, isFalse);
    expect(config.enableLimitedFree, isFalse);
    expect(config.enableServerDrivenEntitlement, isFalse);
    expect(config.enableCrossDeviceEntitlementSync, isFalse);
    expect(config.enableEntitlementDebugPanel, isFalse);
    expect(config.enableAutoUnlockPromptRemember, isFalse);
  });
}

class _DelayedEntitlementRepository implements EntitlementRepository {
  final started = Completer<void>();
  final _result = Completer<UserEntitlementState>();
  int fetchCalls = 0;

  void complete() => _result.complete(const UserEntitlementState.guest());

  @override
  Future<UserEntitlementState> fetchState() async {
    fetchCalls += 1;
    started.complete();
    return _result.future;
  }

  @override
  Future<UserEntitlementState> grantMockCoins({
    required int amount,
    required String source,
  }) => _result.future;

  @override
  Future<UserEntitlementState> grantMockMembership({required String source}) =>
      _result.future;

  @override
  Future<UserEntitlementState> setAutoUnlockEnabled(bool enabled) =>
      _result.future;

  @override
  Future<UserEntitlementState> unlockEpisodeWithCoins({
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  }) => _result.future;
}

ProviderContainer _containerWith(
  MockEntitlementRepository repository, {
  EntitlementFeatureConfig config = const EntitlementFeatureConfig(),
}) {
  return ProviderContainer(
    overrides: [
      entitlementRepositoryProvider.overrideWithValue(repository),
      entitlementFeatureConfigProvider.overrideWithValue(config),
    ],
  );
}

extension on EntitlementController {
  EpisodeAccessDecision evaluateAccessFromFixture(
    MockEntitlementEpisodeFixture fixture,
  ) {
    return evaluateAccess(
      dramaId: fixture.dramaId,
      episodeId: fixture.episodeId,
      itemId: fixture.itemId,
      unlockType: fixture.unlockType,
      price: fixture.price,
      isUnavailable: fixture.isUnavailable,
    );
  }
}
