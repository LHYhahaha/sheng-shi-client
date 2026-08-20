import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/runtime/in_memory_install_id_storage.dart';
import 'package:drama_client/core/runtime/install_id_provider.dart';
import 'package:drama_client/features/popup/application/popup_entry_controller.dart';
import 'package:drama_client/features/popup/data/popup_repository.dart';
import 'package:drama_client/features/popup/data/popup_repository_provider.dart';
import 'package:drama_client/features/popup/domain/popup.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'requests each placement once during the same foreground cycle',
    () async {
      final repository = _RecordingPopupRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      await controller.requestForPlacement(
        PopupPlacementCode.recommendTabEnter,
      );

      expect(repository.calls, [
        PopupPlacementCode.homeEnter,
        PopupPlacementCode.recommendTabEnter,
      ]);
    },
  );

  test(
    'does not open a new cycle when app resumes within 30 minutes',
    () async {
      final repository = _RecordingPopupRepository();
      var now = DateTime(2026, 7, 7, 10);
      final container = _container(repository: repository, now: () => now);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      await controller.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 29));
      await controller.onLifecycleChanged(
        AppLifecycleState.resumed,
        currentPlacement: PopupPlacementCode.homeEnter,
      );

      expect(repository.calls, [PopupPlacementCode.homeEnter]);
    },
  );

  test(
    'opens a new cycle and requests current placement after 30 minute resume',
    () async {
      final repository = _RecordingPopupRepository();
      var now = DateTime(2026, 7, 7, 10);
      final container = _container(repository: repository, now: () => now);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      await controller.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 31));
      await controller.onLifecycleChanged(
        AppLifecycleState.resumed,
        currentPlacement: PopupPlacementCode.homeEnter,
      );

      expect(repository.calls, [
        PopupPlacementCode.homeEnter,
        PopupPlacementCode.homeEnter,
      ]);
    },
  );

  test('allows retry when a placement request fails', () async {
    final repository = _RecordingPopupRepository(failFirst: true);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(repository.calls, [
      PopupPlacementCode.homeEnter,
      PopupPlacementCode.homeEnter,
    ]);
  });

  test(
    'skips request without consuming placement when session is not ready',
    () async {
      final repository = _RecordingPopupRepository();
      final container = _container(repository: repository, requestReady: false);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);

      expect(repository.calls, isEmpty);
      expect(
        container.read(popupEntryControllerProvider).requestedPlacements,
        isEmpty,
      );
    },
  );

  test('does not expose popup when server returns empty data', () async {
    final repository = _RecordingPopupRepository(popup: null);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
  });

  test('does not expose popup when cover image is missing', () async {
    final repository = _RecordingPopupRepository(
      popup: const PopupConfig(contentMode: 1, popupImage: ''),
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
  });

  test(
    'does not expose auto recommendation popup without a drama result',
    () async {
      final repository = _RecordingPopupRepository(
        popup: const PopupConfig(
          contentMode: 2,
          popupImage: 'https://example.test/popup.jpg',
        ),
      );
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);

      expect(container.read(popupEntryControllerProvider).activePopup, isNull);
    },
  );

  test('does not expose h5 popup when h5 url is missing', () async {
    final repository = _RecordingPopupRepository(
      popup: const PopupConfig(
        contentMode: 1,
        popupImage: 'https://example.test/popup.jpg',
        jumpType: 2,
        frontPopupLimit: 1,
      ),
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
  });

  test('does not expose short drama popup when drama id is missing', () async {
    final repository = _RecordingPopupRepository(
      popup: const PopupConfig(
        contentMode: 1,
        popupImage: 'https://example.test/popup.jpg',
        jumpType: 3,
        frontPopupLimit: 1,
      ),
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
  });

  test('keeps displayable popup pending until image is ready', () async {
    final imagePopup = const PopupConfig(
      id: 12,
      contentMode: 1,
      popupImage: 'https://example.test/image.jpg',
      frontPopupLimit: 1,
    );
    final repository = _RecordingPopupRepository(popup: imagePopup);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      imagePopup,
    );
    expect(container.read(popupEntryControllerProvider).activePopup, isNull);

    controller.markPendingPopupImageReady(imagePopup);

    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
    expect(
      container.read(popupEntryControllerProvider).activePopup,
      imagePopup,
    );
    expect(repository.events, const [
      _RecordedPopupEvent(12, PopupEventType.show),
    ]);
  });

  test('discards pending popup when image preload fails', () async {
    final popup = const PopupConfig(
      contentMode: 1,
      popupImage: 'https://example.test/image.jpg',
      frontPopupLimit: 1,
    );
    final repository = _RecordingPopupRepository(popup: popup);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    controller.discardPendingPopup(popup);

    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
    expect(repository.events, isEmpty);
  });

  test('reports click event when image popup image is tapped', () async {
    final popup = const PopupConfig(
      id: 12,
      contentMode: 1,
      popupImage: 'https://example.test/image.jpg',
      frontPopupLimit: 1,
    );
    final repository = _RecordingPopupRepository(popup: popup);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);
    controller.markPendingPopupImageReady(popup);
    controller.tapActivePopupImage(popup);

    expect(repository.events, const [
      _RecordedPopupEvent(12, PopupEventType.show),
      _RecordedPopupEvent(12, PopupEventType.click),
    ]);
  });

  test('reports close event when active popup is closed by button', () async {
    final popup = const PopupConfig(
      id: 12,
      contentMode: 1,
      popupImage: 'https://example.test/image.jpg',
      frontPopupLimit: 1,
    );
    final repository = _RecordingPopupRepository(popup: popup);
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);
    controller.markPendingPopupImageReady(popup);
    controller.closeActivePopup();
    controller.closeActivePopup();

    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
    expect(repository.events, const [
      _RecordedPopupEvent(12, PopupEventType.show),
      _RecordedPopupEvent(12, PopupEventType.close),
    ]);
  });

  test(
    'keeps auto recommendation popup pending until image is ready',
    () async {
      final recommendationPopup = const PopupConfig(
        id: 99,
        contentMode: 2,
        popupImage: 'https://example.test/recommendation.jpg',
        shortDramaId: 99,
        frontPopupLimit: 1,
      );
      final recommendationRepository = _RecordingPopupRepository(
        popup: recommendationPopup,
      );
      final recommendationContainer = _container(
        repository: recommendationRepository,
      );
      addTearDown(recommendationContainer.dispose);

      final recommendationController = recommendationContainer.read(
        popupEntryControllerProvider.notifier,
      );
      await recommendationController.requestForPlacement(
        PopupPlacementCode.homeEnter,
      );

      expect(
        recommendationContainer.read(popupEntryControllerProvider).pendingPopup,
        recommendationPopup,
      );
      expect(
        recommendationContainer.read(popupEntryControllerProvider).activePopup,
        isNull,
      );

      recommendationController.markPendingPopupImageReady(recommendationPopup);

      expect(
        recommendationContainer.read(popupEntryControllerProvider).pendingPopup,
        isNull,
      );
      expect(
        recommendationContainer.read(popupEntryControllerProvider).activePopup,
        recommendationPopup,
      );
      expect(recommendationRepository.events, const [
        _RecordedPopupEvent(99, PopupEventType.show),
      ]);
    },
  );

  test(
    'continues through popup list using the temporary display count',
    () async {
      const firstPopup = PopupConfig(
        id: 1,
        contentMode: 1,
        popupImage: 'https://example.test/1.jpg',
        frontPopupLimit: 1,
      );
      const skippedPopup = PopupConfig(
        id: 2,
        contentMode: 1,
        popupImage: 'https://example.test/2.jpg',
        frontPopupLimit: 1,
      );
      const secondPopup = PopupConfig(
        id: 3,
        contentMode: 1,
        popupImage: 'https://example.test/3.jpg',
        frontPopupLimit: 2,
      );
      final repository = _RecordingPopupRepository(
        popups: const [firstPopup, skippedPopup, secondPopup],
      );
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);

      expect(
        container.read(popupEntryControllerProvider).pendingPopup,
        firstPopup,
      );

      controller.markPendingPopupImageReady(firstPopup);
      controller.closeActivePopup();

      expect(
        container.read(popupEntryControllerProvider).pendingPopup,
        secondPopup,
      );

      controller.discardPendingPopup(secondPopup);

      expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
      expect(container.read(popupEntryControllerProvider).activePopup, isNull);
      expect(repository.events, const [
        _RecordedPopupEvent(1, PopupEventType.show),
        _RecordedPopupEvent(1, PopupEventType.close),
      ]);
    },
  );

  test('shows unlimited popups in server order when limit is zero', () async {
    const firstPopup = PopupConfig(
      id: 1,
      contentMode: 1,
      popupImage: 'https://example.test/1.jpg',
      frontPopupLimit: 0,
    );
    const secondPopup = PopupConfig(
      id: 2,
      contentMode: 1,
      popupImage: 'https://example.test/2.jpg',
      frontPopupLimit: 0,
    );
    final repository = _RecordingPopupRepository(
      popups: const [firstPopup, secondPopup],
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      firstPopup,
    );

    controller.markPendingPopupImageReady(firstPopup);
    expect(
      container.read(popupEntryControllerProvider).activePopup,
      firstPopup,
    );
    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      secondPopup,
    );

    controller.markPendingPopupImageReady(secondPopup);
    controller.closeActivePopup();

    expect(
      container.read(popupEntryControllerProvider).activePopup,
      secondPopup,
    );
    expect(repository.events, const [
      _RecordedPopupEvent(1, PopupEventType.show),
      _RecordedPopupEvent(1, PopupEventType.close),
      _RecordedPopupEvent(2, PopupEventType.show),
    ]);
  });

  test(
    'shows preloaded next popup immediately after closing active popup',
    () async {
      const firstPopup = PopupConfig(
        id: 1,
        contentMode: 1,
        popupImage: 'https://example.test/1.jpg',
        frontPopupLimit: 1,
      );
      const secondPopup = PopupConfig(
        id: 2,
        contentMode: 1,
        popupImage: 'https://example.test/2.jpg',
        frontPopupLimit: 2,
      );
      final repository = _RecordingPopupRepository(
        popups: const [firstPopup, secondPopup],
      );
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      controller.markPendingPopupImageReady(firstPopup);

      expect(
        container.read(popupEntryControllerProvider).activePopup,
        firstPopup,
      );
      expect(
        container.read(popupEntryControllerProvider).pendingPopup,
        secondPopup,
      );

      controller.markPendingPopupImageReady(secondPopup);

      expect(
        container.read(popupEntryControllerProvider).activePopup,
        firstPopup,
      );
      expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);

      controller.closeActivePopup();

      expect(
        container.read(popupEntryControllerProvider).activePopup,
        secondPopup,
      );
      expect(repository.events, const [
        _RecordedPopupEvent(1, PopupEventType.show),
        _RecordedPopupEvent(1, PopupEventType.close),
        _RecordedPopupEvent(2, PopupEventType.show),
      ]);
    },
  );

  test('finishes active popup flow without showing later popups', () async {
    const firstPopup = PopupConfig(
      id: 1,
      contentMode: 1,
      popupImage: 'https://example.test/1.jpg',
      frontPopupLimit: 1,
    );
    const secondPopup = PopupConfig(
      id: 2,
      contentMode: 1,
      popupImage: 'https://example.test/2.jpg',
      frontPopupLimit: 2,
    );
    const thirdPopup = PopupConfig(
      id: 3,
      contentMode: 1,
      popupImage: 'https://example.test/3.jpg',
      frontPopupLimit: 3,
    );
    final repository = _RecordingPopupRepository(
      popups: const [firstPopup, secondPopup, thirdPopup],
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);
    controller.markPendingPopupImageReady(firstPopup);
    controller.closeActivePopup();
    controller.markPendingPopupImageReady(secondPopup);

    expect(
      container.read(popupEntryControllerProvider).activePopup,
      secondPopup,
    );
    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      thirdPopup,
    );

    controller.finishActivePopupFlow();

    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
    expect(repository.events, const [
      _RecordedPopupEvent(1, PopupEventType.show),
      _RecordedPopupEvent(1, PopupEventType.close),
      _RecordedPopupEvent(2, PopupEventType.show),
      _RecordedPopupEvent(2, PopupEventType.close),
    ]);

    controller.markPendingPopupImageReady(thirdPopup);

    expect(container.read(popupEntryControllerProvider).activePopup, isNull);
    expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);

    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(repository.calls, [PopupPlacementCode.homeEnter]);
  });

  test('does not count image preload failures in popup list flow', () async {
    const failedPopup = PopupConfig(
      id: 1,
      contentMode: 1,
      popupImage: 'https://example.test/failed.jpg',
      frontPopupLimit: 1,
    );
    const nextPopup = PopupConfig(
      id: 2,
      contentMode: 1,
      popupImage: 'https://example.test/next.jpg',
      frontPopupLimit: 1,
    );
    final repository = _RecordingPopupRepository(
      popups: const [failedPopup, nextPopup],
    );
    final container = _container(repository: repository);
    addTearDown(container.dispose);

    final controller = container.read(popupEntryControllerProvider.notifier);
    await controller.requestForPlacement(PopupPlacementCode.homeEnter);

    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      failedPopup,
    );

    controller.discardPendingPopup(failedPopup);

    expect(
      container.read(popupEntryControllerProvider).pendingPopup,
      nextPopup,
    );
    expect(repository.events, isEmpty);
  });

  test(
    'cancels active flow and consumes placement for current cycle',
    () async {
      const popup = PopupConfig(
        id: 1,
        contentMode: 1,
        popupImage: 'https://example.test/1.jpg',
        frontPopupLimit: 1,
      );
      final repository = _RecordingPopupRepository(popup: popup);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      controller.markPendingPopupImageReady(popup);

      expect(container.read(popupEntryControllerProvider).activePopup, popup);

      controller.cancelPlacementFlow(PopupPlacementCode.homeEnter);

      expect(container.read(popupEntryControllerProvider).activePopup, isNull);
      expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
      expect(
        container.read(popupEntryControllerProvider).requestedPlacements,
        contains(PopupPlacementCode.homeEnter),
      );

      await controller.requestForPlacement(PopupPlacementCode.homeEnter);

      expect(repository.calls, [PopupPlacementCode.homeEnter]);
    },
  );

  test(
    'ignores popup response when placement is cancelled while request is in flight',
    () async {
      const popup = PopupConfig(
        id: 1,
        contentMode: 1,
        popupImage: 'https://example.test/1.jpg',
        frontPopupLimit: 1,
      );
      final repository = _DelayedPopupRepository(popups: const [popup]);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      final request = controller.requestForPlacement(
        PopupPlacementCode.homeEnter,
      );

      expect(repository.calls, [PopupPlacementCode.homeEnter]);

      controller.cancelPlacementFlow(PopupPlacementCode.homeEnter);
      repository.complete();
      await request;

      expect(container.read(popupEntryControllerProvider).pendingPopup, isNull);
      expect(container.read(popupEntryControllerProvider).activePopup, isNull);
      expect(
        container.read(popupEntryControllerProvider).requestedPlacements,
        contains(PopupPlacementCode.homeEnter),
      );

      await controller.requestForPlacement(PopupPlacementCode.homeEnter);

      expect(repository.calls, [PopupPlacementCode.homeEnter]);
    },
  );

  test(
    'cancels every placement so a stale response cannot cover a new route',
    () async {
      const popup = PopupConfig(
        id: 1,
        contentMode: 1,
        popupImage: 'https://example.test/1.jpg',
        frontPopupLimit: 1,
      );
      final repository = _DelayedPopupRepository(popups: const [popup]);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      final request = controller.requestForPlacement(
        PopupPlacementCode.homeEnter,
      );

      controller.cancelAllPlacementFlows();
      repository.complete();
      await request;

      final state = container.read(popupEntryControllerProvider);
      expect(state.pendingPopup, isNull);
      expect(state.activePopup, isNull);
      expect(state.requestedPlacements, containsAll(PopupPlacementCode.values));
    },
  );

  test(
    'does not start another flow for the same placement while popup is active',
    () async {
      final popup = const PopupConfig(
        id: 12,
        contentMode: 1,
        popupImage: 'https://example.test/image.jpg',
        frontPopupLimit: 1,
      );
      final repository = _RecordingPopupRepository(popup: popup);
      var now = DateTime(2026, 7, 8, 10);
      final container = _container(repository: repository, now: () => now);
      addTearDown(container.dispose);

      final controller = container.read(popupEntryControllerProvider.notifier);
      await controller.requestForPlacement(PopupPlacementCode.homeEnter);
      controller.markPendingPopupImageReady(popup);
      await controller.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 31));
      await controller.onLifecycleChanged(
        AppLifecycleState.resumed,
        currentPlacement: PopupPlacementCode.homeEnter,
      );

      expect(repository.calls, [PopupPlacementCode.homeEnter]);
      expect(container.read(popupEntryControllerProvider).activePopup, popup);
    },
  );

  test('request gate follows request context token updates', () async {
    final storage = InMemoryInstallIdStorage();
    await storage.write('11111111-1111-4111-8111-111111111111');
    final container = ProviderContainer(
      overrides: [
        installIdStorageProvider.overrideWithValue(storage),
        installIdProvider.overrideWith(
          (ref) async => '11111111-1111-4111-8111-111111111111',
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(installIdProvider.future);
    expect(container.read(popupEntryRequestGateProvider), isFalse);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(const AuthTokenSnapshot(accessToken: 'token'));

    expect(container.read(popupEntryRequestGateProvider), isTrue);
  });
}

ProviderContainer _container({
  required PopupRepository repository,
  DateTime Function()? now,
  bool requestReady = true,
}) {
  return ProviderContainer(
    overrides: [
      popupRepositoryProvider.overrideWithValue(repository),
      popupEntryRequestGateProvider.overrideWithValue(requestReady),
      if (now != null) popupEntryNowProvider.overrideWithValue(now),
    ],
  );
}

class _RecordingPopupRepository implements PopupRepository {
  _RecordingPopupRepository({
    this.failFirst = false,
    this.popup = _sentinel,
    this.popups,
  });

  final bool failFirst;
  final Object? popup;
  final List<PopupConfig>? popups;
  final List<PopupPlacementCode> calls = [];
  final List<_RecordedPopupEvent> events = [];

  @override
  Future<List<PopupConfig>> fetchPopups({
    required PopupPlacementCode placement,
  }) async {
    calls.add(placement);
    if (failFirst && calls.length == 1) {
      throw StateError('network unavailable');
    }
    final configuredPopups = popups;
    if (configuredPopups != null) {
      return configuredPopups;
    }
    if (!identical(popup, _sentinel)) {
      final configuredPopup = popup as PopupConfig?;
      return configuredPopup == null
          ? const <PopupConfig>[]
          : [configuredPopup];
    }
    return [PopupConfig(placementCode: placement.apiValue)];
  }

  @override
  Future<void> reportPopupEvent({
    required int popupId,
    required PopupEventType eventType,
  }) async {
    events.add(_RecordedPopupEvent(popupId, eventType));
  }

  @override
  Future<PopupExitRecommendationSet> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  }) async {
    return const PopupExitRecommendationSet(recommendations: []);
  }

  static const Object _sentinel = Object();
}

class _DelayedPopupRepository implements PopupRepository {
  _DelayedPopupRepository({required this.popups});

  final List<PopupConfig> popups;
  final List<PopupPlacementCode> calls = [];
  final Completer<List<PopupConfig>> _completer =
      Completer<List<PopupConfig>>();

  void complete() {
    _completer.complete(popups);
  }

  @override
  Future<List<PopupConfig>> fetchPopups({
    required PopupPlacementCode placement,
  }) {
    calls.add(placement);
    return _completer.future;
  }

  @override
  Future<void> reportPopupEvent({
    required int popupId,
    required PopupEventType eventType,
  }) async {}

  @override
  Future<PopupExitRecommendationSet> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  }) async {
    return const PopupExitRecommendationSet(recommendations: []);
  }
}

class _RecordedPopupEvent {
  const _RecordedPopupEvent(this.popupId, this.eventType);

  final int popupId;
  final PopupEventType eventType;

  @override
  bool operator ==(Object other) {
    return other is _RecordedPopupEvent &&
        other.popupId == popupId &&
        other.eventType == eventType;
  }

  @override
  int get hashCode => Object.hash(popupId, eventType);

  @override
  String toString() {
    return '_RecordedPopupEvent(popupId: $popupId, eventType: $eventType)';
  }
}
