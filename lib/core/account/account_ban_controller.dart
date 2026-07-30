import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前进程内的账号封禁状态。
class AccountBanState {
  const AccountBanState({
    this.isBanned = false,
    this.isViewingFeedback = false,
    this.isRevalidating = false,
  });

  final bool isBanned;
  final bool isViewingFeedback;
  final bool isRevalidating;

  AccountBanState copyWith({
    bool? isBanned,
    bool? isViewingFeedback,
    bool? isRevalidating,
  }) {
    return AccountBanState(
      isBanned: isBanned ?? this.isBanned,
      isViewingFeedback: isViewingFeedback ?? this.isViewingFeedback,
      isRevalidating: isRevalidating ?? this.isRevalidating,
    );
  }
}

class AccountBanController extends Notifier<AccountBanState> {
  @override
  AccountBanState build() => const AccountBanState();

  /// 由全局网络入口调用。只有业务码 3116 会触发展示封禁态。
  void reportBusinessCode(int? businessCode) {
    if (businessCode != accountBannedBusinessCode || state.isBanned) {
      return;
    }
    state = state.copyWith(isBanned: true);
  }

  void openFeedback() {
    if (state.isBanned) {
      state = state.copyWith(isViewingFeedback: true);
    }
  }

  void closeFeedback() {
    if (state.isBanned && state.isViewingFeedback) {
      state = state.copyWith(isViewingFeedback: false);
    }
  }

  /// 反馈页退出后恢复遮罩，并开始等待重新登录和权益校验结果。
  bool beginRevalidation() {
    if (!state.isBanned || state.isRevalidating) {
      return false;
    }
    state = state.copyWith(isViewingFeedback: false, isRevalidating: true);
    return true;
  }

  /// 已重新认证并成功完成权益校验后，才解除封禁遮罩。
  void clearAfterVerification() {
    if (state.isBanned) {
      state = const AccountBanState();
    }
  }

  /// 重新认证或权益校验仍返回 3116/失败时，继续保留封禁遮罩。
  void completeRevalidationAsBanned() {
    if (state.isBanned && state.isRevalidating) {
      state = state.copyWith(isRevalidating: false);
    }
  }
}

const accountBannedBusinessCode = 3116;

final accountBanControllerProvider =
    NotifierProvider<AccountBanController, AccountBanState>(
      AccountBanController.new,
    );
