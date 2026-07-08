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
        state.inFlightPlacements.contains(placement)) {
      return;
    }

    state = state.copyWith(
      inFlightPlacements: {...state.inFlightPlacements, placement},
    );

    try {
      final popup = await ref
          .read(popupRepositoryProvider)
          .fetchPopup(placement: placement);
      state = state.copyWith(
        requestedPlacements: {...state.requestedPlacements, placement},
        pendingPopup: _isDisplayablePopup(popup) ? popup : null,
        activePopup: null,
      );
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

  void dismissActivePopup() {
    if (state.activePopup == null) {
      return;
    }
    state = state.copyWith(activePopup: null);
  }

  void markPendingPopupImageReady(PopupConfig popup) {
    if (!identical(state.pendingPopup, popup)) {
      return;
    }
    state = state.copyWith(pendingPopup: null, activePopup: popup);
  }

  void discardPendingPopup(PopupConfig popup) {
    if (!identical(state.pendingPopup, popup)) {
      return;
    }
    state = state.copyWith(pendingPopup: null);
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
    if (currentPlacement != null) {
      await requestForPlacement(currentPlacement);
    }
  }

  DateTime _now() => ref.read(popupEntryNowProvider)();

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
    if (contentMode == 2) {
      return popup.shortDramaId != null && popup.shortDramaId! > 0;
    }
    return true;
  }

  bool _isBackgroundState(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }
}
