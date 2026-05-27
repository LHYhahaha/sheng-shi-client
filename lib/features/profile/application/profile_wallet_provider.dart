import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/auth_controller.dart';
import '../data/profile_repository_provider.dart';

/// 我的页钱包数据状态。
class ProfileWalletState {
  const ProfileWalletState({
    required this.isLoading,
    required this.coin,
    required this.bonusCoin,
    required this.totalCoin,
    this.error,
  });

  const ProfileWalletState.initial()
    : isLoading = true,
      coin = 0,
      bonusCoin = 0,
      totalCoin = 0,
      error = null;

  final bool isLoading;
  final int coin;
  final int bonusCoin;
  final int totalCoin;
  final String? error;

  ProfileWalletState copyWith({
    bool? isLoading,
    int? coin,
    int? bonusCoin,
    int? totalCoin,
    String? error,
  }) {
    return ProfileWalletState(
      isLoading: isLoading ?? this.isLoading,
      coin: coin ?? this.coin,
      bonusCoin: bonusCoin ?? this.bonusCoin,
      totalCoin: totalCoin ?? this.totalCoin,
      error: error ?? this.error,
    );
  }
}

/// 我的页钱包数据控制器。
class ProfileWalletController extends Notifier<ProfileWalletState> {
  @override
  ProfileWalletState build() {
    // 自动监听用户变化，当用户登录时加载钱包数据
    ref.listen(
      authControllerProvider.select((state) => state.user?.id),
      (previous, next) {
        if (next != null && next != previous) {
          load(int.parse(next));
        }
      },
    );

    return const ProfileWalletState.initial();
  }

  /// 加载钱包数据。
  Future<void> load(int userId) async {
    state = const ProfileWalletState.initial();
    try {
      final data = await ref.read(profileRepositoryProvider).fetchWallet(userId);
      state = ProfileWalletState(
        isLoading: false,
        coin: data['coin'] as int? ?? 0,
        bonusCoin: data['bonusCoin'] as int? ?? 0,
        totalCoin: data['totalCoin'] as int? ?? 0,
      );
    } catch (e) {
      state = ProfileWalletState(
        isLoading: false,
        coin: 0,
        bonusCoin: 0,
        totalCoin: 0,
        error: e.toString(),
      );
    }
  }
}

/// 我的页钱包数据 provider。
final profileWalletProvider =
    NotifierProvider<ProfileWalletController, ProfileWalletState>(
  ProfileWalletController.new,
);
