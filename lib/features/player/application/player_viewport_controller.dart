import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_rebuild_diagnostics.dart';

final playerViewportControllerProvider =
    NotifierProvider.family<
      PlayerViewportController,
      PlayerViewportState,
      String
    >(PlayerViewportController.new);

enum PlayerViewportScrollPhase { idle, dragging, settling }

class PlayerViewportState {
  const PlayerViewportState({
    required this.scrollPhase,
    required this.currentIndex,
    required this.candidateIndex,
    required this.settledIndex,
    required this.generation,
    this.settledItemId,
  });

  const PlayerViewportState.initial()
    : scrollPhase = PlayerViewportScrollPhase.idle,
      currentIndex = 0,
      candidateIndex = 0,
      settledIndex = 0,
      settledItemId = null,
      generation = 0;

  final PlayerViewportScrollPhase scrollPhase;
  final int currentIndex;
  final int candidateIndex;
  final int settledIndex;
  final String? settledItemId;
  final int generation;

  PlayerViewportState copyWith({
    PlayerViewportScrollPhase? scrollPhase,
    int? currentIndex,
    int? candidateIndex,
    int? settledIndex,
    String? settledItemId,
    int? generation,
    bool clearSettledItemId = false,
  }) {
    return PlayerViewportState(
      scrollPhase: scrollPhase ?? this.scrollPhase,
      currentIndex: currentIndex ?? this.currentIndex,
      candidateIndex: candidateIndex ?? this.candidateIndex,
      settledIndex: settledIndex ?? this.settledIndex,
      settledItemId: clearSettledItemId
          ? null
          : settledItemId ?? this.settledItemId,
      generation: generation ?? this.generation,
    );
  }
}

class PlayerViewportController extends Notifier<PlayerViewportState> {
  PlayerViewportController(this.sessionKey);

  final String sessionKey;

  @override
  PlayerViewportState build() => const PlayerViewportState.initial();

  void initialize({required int index, required String? itemId}) {
    if (state.currentIndex == index &&
        state.candidateIndex == index &&
        state.settledIndex == index &&
        state.settledItemId == itemId &&
        state.scrollPhase == PlayerViewportScrollPhase.idle) {
      return;
    }
    state = state.copyWith(
      scrollPhase: PlayerViewportScrollPhase.idle,
      currentIndex: index,
      candidateIndex: index,
      settledIndex: index,
      settledItemId: itemId,
      generation: state.generation + 1,
    );
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettled',
      itemId: itemId,
      details:
          'session=$sessionKey index=$index generation=${state.generation}',
    );
  }

  void markScrollStart() {
    if (state.scrollPhase == PlayerViewportScrollPhase.dragging) {
      return;
    }
    state = state.copyWith(scrollPhase: PlayerViewportScrollPhase.dragging);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportScrollStart',
      details:
          'session=$sessionKey current=${state.currentIndex} candidate=${state.candidateIndex} generation=${state.generation}',
    );
  }

  void markPageChanged(int index) {
    if (state.candidateIndex == index && state.currentIndex == index) {
      return;
    }
    state = state.copyWith(currentIndex: index, candidateIndex: index);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportPageChanged',
      details:
          'session=$sessionKey index=$index phase=${state.scrollPhase.name} generation=${state.generation}',
    );
  }

  void markScrollEnd() {
    if (state.scrollPhase == PlayerViewportScrollPhase.settling) {
      return;
    }
    state = state.copyWith(scrollPhase: PlayerViewportScrollPhase.settling);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettling',
      details:
          'session=$sessionKey candidate=${state.candidateIndex} generation=${state.generation}',
    );
  }

  void settle({required int index, required String? itemId}) {
    if (state.settledIndex == index &&
        state.settledItemId == itemId &&
        state.scrollPhase == PlayerViewportScrollPhase.idle) {
      return;
    }
    state = state.copyWith(
      scrollPhase: PlayerViewportScrollPhase.idle,
      currentIndex: index,
      candidateIndex: index,
      settledIndex: index,
      settledItemId: itemId,
      generation: state.generation + 1,
    );
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettled',
      itemId: itemId,
      details:
          'session=$sessionKey index=$index generation=${state.generation}',
    );
  }
}
