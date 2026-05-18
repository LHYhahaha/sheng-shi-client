import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 测试可覆盖的注销页倒计时时长（秒）。
final accountCancellationCountdownProvider = Provider<int>(
  (ref) => 9,
  name: 'accountCancellationCountdown',
);

final accountCancellationControllerProvider =
    NotifierProvider.autoDispose<
      AccountCancellationController,
      AccountCancellationState
    >(AccountCancellationController.new);

class AccountCancellationState {
  const AccountCancellationState({
    required this.acceptedRisk,
    required this.remainingSeconds,
    required this.isSubmitting,
    this.error,
  });

  const AccountCancellationState.initial({required int countdownSeconds})
    : acceptedRisk = false,
      remainingSeconds = countdownSeconds,
      isSubmitting = false,
      error = null;

  final bool acceptedRisk;
  final int remainingSeconds;
  final bool isSubmitting;
  final Object? error;

  bool get countdownFinished => remainingSeconds <= 0;

  bool get canSubmit => acceptedRisk && countdownFinished && !isSubmitting;

  AccountCancellationState copyWith({
    bool? acceptedRisk,
    int? remainingSeconds,
    bool? isSubmitting,
    Object? error,
    bool clearError = false,
  }) {
    return AccountCancellationState(
      acceptedRisk: acceptedRisk ?? this.acceptedRisk,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountCancellationController extends Notifier<AccountCancellationState> {
  Timer? _countdownTimer;

  @override
  AccountCancellationState build() {
    ref.onDispose(_cancelCountdown);
    final seconds = ref.watch(accountCancellationCountdownProvider);
    _beginCountdownIfNeeded(seconds);
    return AccountCancellationState.initial(countdownSeconds: seconds);
  }

  void setAcceptedRisk(bool value) {
    state = state.copyWith(acceptedRisk: value, clearError: true);
  }

  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }

  void setError(Object? error) {
    state = state.copyWith(error: error, isSubmitting: false);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void _beginCountdownIfNeeded(int seconds) {
    _cancelCountdown();
    if (seconds <= 0) {
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        state = state.copyWith(remainingSeconds: 0);
        timer.cancel();
        _countdownTimer = null;
        return;
      }
      state = state.copyWith(remainingSeconds: next);
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }
}
