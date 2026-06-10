import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/home_repository_provider.dart';
import '../domain/home_data.dart';

/// 首页数据加载状态。
class HomeDataState {
  const HomeDataState({this.data, this.isLoading = false, this.error});

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
/// 采用与 ProfilePage 相同的模式：监听 AuthState 判断 session 是否就绪，
/// 游客/正式账号只要有有效 token 都可以加载首页数据。
final homeDataControllerProvider =
    NotifierProvider<HomeDataController, HomeDataState>(HomeDataController.new);

class HomeDataController extends Notifier<HomeDataState> {
  bool _loadAttempted = false;

  @override
  HomeDataState build() {
    // 监听 AuthState，当认证初始化完成时自动加载数据。
    ref.listen(authControllerProvider, (previous, next) {
      final wasReady = previous != null && !previous.isLoading;
      final isReady = !next.isLoading && next.error == null;

      print(
        '[HomeDataController] Auth state changed: wasReady=$wasReady, isReady=$isReady, isLoggedIn=${next.isLoggedIn}, _loadAttempted=$_loadAttempted',
      );

      if (!wasReady && isReady && !_loadAttempted) {
        print('[HomeDataController] Auth session ready, loading home data...');
        _loadAttempted = true;
        Future.microtask(loadHomeData);
      }
    });

    Future.microtask(() {
      final authState = ref.read(authControllerProvider);
      if (!authState.isLoading && authState.error == null && !_loadAttempted) {
        print('[HomeDataController] Auth already ready, loading home data...');
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
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  /// 重试加载首页数据。
  Future<void> retry() async {
    _loadAttempted = true;
    await loadHomeData();
  }
}
