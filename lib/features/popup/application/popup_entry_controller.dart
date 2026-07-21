import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../data/popup_repository_provider.dart';
import '../domain/popup.dart';

class PopupEntryState {
  const PopupEntryState({
    this.requestedPlacements = const <PopupPlacementCode>{},
    this.inFlightPlacements = const <PopupPlacementCode>{},
    this.pendingPopup,
    this.activePopup,
    this.backgroundedAt,
  });

  final Set<PopupPlacementCode> requestedPlacements;
  final Set<PopupPlacementCode> inFlightPlacements;
  final PopupConfig? pendingPopup;
  final PopupConfig? activePopup;
  final DateTime? backgroundedAt;

  PopupEntryState copyWith({
    Set<PopupPlacementCode>? requestedPlacements,
    Set<PopupPlacementCode>? inFlightPlacements,
    Object? pendingPopup = _sentinel,
    Object? activePopup = _sentinel,
    Object? backgroundedAt = _sentinel,
  }) {
    return PopupEntryState(
      requestedPlacements: requestedPlacements ?? this.requestedPlacements,
      inFlightPlacements: inFlightPlacements ?? this.inFlightPlacements,
      pendingPopup: identical(pendingPopup, _sentinel)
          ? this.pendingPopup
          : pendingPopup as PopupConfig?,
      activePopup: identical(activePopup, _sentinel)
          ? this.activePopup
          : activePopup as PopupConfig?,
      backgroundedAt: identical(backgroundedAt, _sentinel)
          ? this.backgroundedAt
          : backgroundedAt as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}

final popupEntryNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final popupEntryRequestGateProvider = Provider<bool>((ref) {
  final context = ref.watch(apiRequestContextProvider);
  return context.deviceId != 'install-id-pending' &&
      context.accessToken != null &&
      context.accessToken!.isNotEmpty;
});

final popupEntryControllerProvider =
    NotifierProvider<PopupEntryController, PopupEntryState>(
      PopupEntryController.new,
    );

class PopupEntryController extends Notifier<PopupEntryState> {
  static const backgroundRefreshThreshold = Duration(minutes: 30);

  List<PopupConfig> _flowPopups = const <PopupConfig>[];
  int _flowIndex = 0;
  int _flowDisplayedCount = 0;
  PopupPlacementCode? _flowPlacement;
  PopupConfig? _readyPopup;
  final Set<PopupPlacementCode> _cancelledPlacements = <PopupPlacementCode>{};

  @override
  PopupEntryState build() {
    return const PopupEntryState();
  }

  Future<void> requestForPlacement(PopupPlacementCode placement) async {
    if (!ref.read(popupEntryRequestGateProvider)) {
      debugPrint(
        '[PopupEntryController] Skip popup request for ${placement.apiValue}: '
        'session is not ready.',
      );
      return;
    }

    if (state.requestedPlacements.contains(placement) ||
        state.inFlightPlacements.contains(placement) ||
        _flowPlacement == placement) {
      return;
    }

    _cancelledPlacements.remove(placement);
    state = state.copyWith(
      inFlightPlacements: {...state.inFlightPlacements, placement},
    );

    try {
      final popups = await ref
          .read(popupRepositoryProvider)
          .fetchPopups(placement: placement);
      if (_cancelledPlacements.contains(placement)) {
        state = state.copyWith(
          requestedPlacements: {...state.requestedPlacements, placement},
        );
        return;
      }
      state = state.copyWith(
        requestedPlacements: {...state.requestedPlacements, placement},
        pendingPopup: null,
        activePopup: null,
      );
      _startPopupFlow(placement, popups);
    } catch (error) {
      debugPrint(
        '[PopupEntryController] Popup request failed for '
        '${placement.apiValue}: $error',
      );
    } finally {
      state = state.copyWith(
        inFlightPlacements: {
          for (final item in state.inFlightPlacements)
            if (item != placement) item,
        },
      );
    }
  }

  void cancelPlacementFlow(PopupPlacementCode placement) {
    _cancelledPlacements.add(placement);
    state = state.copyWith(
      requestedPlacements: {...state.requestedPlacements, placement},
    );
    if (_flowPlacement != placement) {
      return;
    }
    _flowPopups = const <PopupConfig>[];
    _flowIndex = 0;
    _flowDisplayedCount = 0;
    _flowPlacement = null;
    _readyPopup = null;
    state = state.copyWith(pendingPopup: null, activePopup: null);
  }

  void dismissActivePopup() {
    if (state.activePopup == null) {
      return;
    }
    state = state.copyWith(activePopup: null);
    _showReadyPopupOrAdvance();
  }

  void markPendingPopupImageReady(PopupConfig popup) {
    if (!identical(state.pendingPopup, popup)) {
      return;
    }
    state = state.copyWith(pendingPopup: null);
    if (state.activePopup != null) {
      _readyPopup = popup;
      return;
    }
    _showPopup(popup);
    _advancePopupFlow();
  }

  void discardPendingPopup(PopupConfig popup) {
    if (!identical(state.pendingPopup, popup)) {
      return;
    }
    state = state.copyWith(pendingPopup: null);
    _advancePopupFlow();
  }

  void closeActivePopup() {
    final popup = state.activePopup;
    if (popup == null) {
      return;
    }
    state = state.copyWith(activePopup: null);
    unawaited(_reportPopupEvent(popup, PopupEventType.close));
    _showReadyPopupOrAdvance();
  }

  void tapActivePopupImage(PopupConfig popup) {
    if (!identical(state.activePopup, popup) || popup.contentMode != 1) {
      return;
    }
    unawaited(_reportPopupEvent(popup, PopupEventType.click));
  }

  void finishActivePopupFlow() {
    if (state.activePopup == null &&
        state.pendingPopup == null &&
        _readyPopup == null &&
        _flowPlacement == null) {
      return;
    }
    _finishPopupFlow();
    state = state.copyWith(activePopup: null);
  }

  Future<void> onLifecycleChanged(
    AppLifecycleState lifecycleState, {
    PopupPlacementCode? currentPlacement,
  }) async {
    if (_isBackgroundState(lifecycleState)) {
      state = state.copyWith(backgroundedAt: state.backgroundedAt ?? _now());
      return;
    }

    if (lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final backgroundedAt = state.backgroundedAt;
    state = state.copyWith(backgroundedAt: null);
    if (backgroundedAt == null) {
      return;
    }

    if (_now().difference(backgroundedAt) <= backgroundRefreshThreshold) {
      return;
    }

    state = state.copyWith(requestedPlacements: const <PopupPlacementCode>{});
    _cancelledPlacements.clear();
    if (currentPlacement != null) {
      await requestForPlacement(currentPlacement);
    }
  }

  DateTime _now() => ref.read(popupEntryNowProvider)();

  void _startPopupFlow(PopupPlacementCode placement, List<PopupConfig> popups) {
    _flowPopups = popups;
    _flowIndex = 0;
    _flowDisplayedCount = 0;
    _flowPlacement = placement;
    _readyPopup = null;
    _advancePopupFlow();
  }

  void _advancePopupFlow() {
    if (_readyPopup != null || state.pendingPopup != null) {
      return;
    }
    while (_flowIndex < _flowPopups.length) {
      final popup = _flowPopups[_flowIndex];
      _flowIndex++;
      if (_isDisplayablePopup(popup)) {
        state = state.copyWith(pendingPopup: popup);
        return;
      }
    }
    if (state.activePopup != null) {
      return;
    }
    _finishPopupFlow();
  }

  void _finishPopupFlow() {
    _flowPopups = const <PopupConfig>[];
    _flowIndex = 0;
    _flowDisplayedCount = 0;
    _flowPlacement = null;
    _readyPopup = null;
    state = state.copyWith(pendingPopup: null);
  }

  void _showReadyPopupOrAdvance() {
    final readyPopup = _readyPopup;
    if (readyPopup == null) {
      _advancePopupFlow();
      return;
    }
    _readyPopup = null;
    _showPopup(readyPopup);
    _advancePopupFlow();
  }

  void _showPopup(PopupConfig popup) {
    state = state.copyWith(activePopup: popup);
    _flowDisplayedCount++;
    unawaited(_reportPopupEvent(popup, PopupEventType.show));
  }

  Future<void> _reportPopupEvent(
    PopupConfig popup,
    PopupEventType eventType,
  ) async {
    final popupId = popup.id;
    if (popupId == null) {
      return;
    }
    try {
      await ref
          .read(popupRepositoryProvider)
          .reportPopupEvent(popupId: popupId, eventType: eventType);
    } catch (error) {
      debugPrint(
        '[PopupEntryController] Popup event report failed for '
        '$popupId/${eventType.apiValue}: $error',
      );
    }
  }

  bool _isDisplayablePopup(PopupConfig? popup) {
    if (popup == null) {
      return false;
    }
    final contentMode = popup.contentMode;
    if (contentMode != 1 && contentMode != 2) {
      return false;
    }
    if (popup.popupImage == null || popup.popupImage!.trim().isEmpty) {
      return false;
    }
    if (popup.jumpType == 2 &&
        (popup.h5Url == null || popup.h5Url!.trim().isEmpty)) {
      return false;
    }
    if (popup.jumpType == 3 &&
        (popup.shortDramaId == null || popup.shortDramaId! <= 0)) {
      return false;
    }
    if (contentMode == 2) {
      if (popup.shortDramaId == null || popup.shortDramaId! <= 0) {
        return false;
      }
    }
    final frontPopupLimit = popup.frontPopupLimit;
    // 服务端约定 0 表示前台弹窗数量不受限制；多个此类弹窗仍按接口顺序
    // 进入当前 flow。正数则表示当前 flow 中允许展示的最大数量。
    return frontPopupLimit == 0 ||
        (frontPopupLimit != null &&
            frontPopupLimit > 0 &&
            _flowDisplayedCount < frontPopupLimit);
  }

  bool _isBackgroundState(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }
}
