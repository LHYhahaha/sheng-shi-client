import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/home_repository_provider.dart';
import '../domain/home_data.dart';

/// 首页数据加载状态。
class HomeDataState {
  const HomeDataState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  /// 首页数据。
  final HomeData? data;

  /// 是否正在加载。
  final bool isLoading;

  /// 加载错误。
  final Object? error;

  bool get hasError => error != null;

  HomeDataState copyWith({
    HomeData? data,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return HomeDataState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 首页数据加载控制器。
///
/// 负责从远程接口加载首页数据。
/// 采用与 ProfilePage 相同的模式：监听 AuthState 判断登录状态，
/// 当用户登录时自动加载首页数据。
final homeDataControllerProvider =
    NotifierProvider<HomeDataController, HomeDataState>(
  HomeDataController.new,
);

class HomeDataController extends Notifier<HomeDataState> {
  bool _loadAttempted = false;

  @override
  HomeDataState build() {
    // 监听 AuthState，当用户登录时自动加载数据
    ref.listen(authControllerProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      final isLoggedIn = next.isLoggedIn;
      
      print('[HomeDataController] Auth state changed: wasLoggedIn=$wasLoggedIn, isLoggedIn=$isLoggedIn, _loadAttempted=$_loadAttempted');
      
      // 从未登录变为已登录时，自动加载数据
      if (!wasLoggedIn && isLoggedIn && !_loadAttempted) {
        print('[HomeDataController] User logged in, loading home data...');
        _loadAttempted = true;
        loadHomeData();
      }
    });

    return const HomeDataState();
  }

  /// 加载首页数据。
  Future<void> loadHomeData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(homeRepositoryProvider);
      final homeData = await repository.getHomeData();
      
      print('[HomeDataController] loadHomeData success');
      print('[HomeDataController]   tabs count: ${homeData.tabs.length}');
      
      state = state.copyWith(
        data: homeData,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      print('[HomeDataController] loadHomeData error: $error');
      state = state.copyWith(
        isLoading: false,
        error: error,
      );
    }
  }

  /// 重试加载首页数据。
  Future<void> retry() async {
    await loadHomeData();
  }
}
