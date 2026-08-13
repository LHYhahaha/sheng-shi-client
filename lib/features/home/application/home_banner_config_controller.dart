import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dto/home_banner_response_dto.dart';
import '../data/remote/home_banner_remote_data_source.dart';

final homeBannerConfigControllerProvider =
    NotifierProvider<HomeBannerConfigController, HomeBannerConfigState>(
      HomeBannerConfigController.new,
    );

class HomeBannerConfigState {
  const HomeBannerConfigState({
    this.banners = const <HomeBannerDto>[],
    this.hasLoaded = false,
    this.unavailableBannerIds = const <String>{},
  });

  final List<HomeBannerDto> banners;
  final bool hasLoaded;
  final Set<String> unavailableBannerIds;

  List<HomeBannerDto> get visibleBanners => banners
      .where((banner) => !unavailableBannerIds.contains(banner.bannerId))
      .toList(growable: false);

  HomeBannerConfigState copyWith({
    List<HomeBannerDto>? banners,
    bool? hasLoaded,
    Set<String>? unavailableBannerIds,
  }) => HomeBannerConfigState(
    banners: banners ?? this.banners,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    unavailableBannerIds: unavailableBannerIds ?? this.unavailableBannerIds,
  );
}

/// 首页 Banner 配置：一个冷启动内最多请求一次，异常直接显示为空。
class HomeBannerConfigController extends Notifier<HomeBannerConfigState> {
  Future<void>? _loadOperation;

  @override
  HomeBannerConfigState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final wasReady = previous != null && !previous.isLoading;
      final isReady = !next.isLoading && next.error == null;
      if (!wasReady && isReady) {
        unawaited(loadOnce());
      }
    });
    Future.microtask(() {
      final auth = ref.read(authControllerProvider);
      if (!auth.isLoading && auth.error == null) {
        unawaited(loadOnce());
      }
    });
    return const HomeBannerConfigState();
  }

  Future<void> loadOnce() {
    if (state.hasLoaded) return Future<void>.value();
    final auth = ref.read(authControllerProvider);
    // 首帧创建首页时 device/session 尚未就绪，不能将被拒绝的请求当成一次有效加载。
    if (auth.isLoading || auth.error != null) return Future<void>.value();
    return _loadOperation ??= _load();
  }

  Future<void> _load() async {
    try {
      final response = await HomeBannerRemoteDataSource(
        apiClient: ref.read(apiClientProvider),
      ).fetchBanners();
      final seenIds = <String>{};
      final valid = response.banners
          .where((banner) {
            return seenIds.add(banner.bannerId) &&
                _isHttpUrl(banner.imageUrl) &&
                _isValidTarget(banner);
          })
          .toList(growable: false);
      state = state.copyWith(banners: valid, hasLoaded: true);
    } catch (_) {
      state = state.copyWith(banners: const <HomeBannerDto>[], hasLoaded: true);
    }
  }

  void disableBanner(String bannerId) {
    if (bannerId.isEmpty || state.unavailableBannerIds.contains(bannerId)) {
      return;
    }
    state = state.copyWith(
      unavailableBannerIds: {...state.unavailableBannerIds, bannerId},
    );
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  bool _isSupportedJumpType(String value) => const {
    'none',
    'internal_h5',
    'external_h5',
    'drama',
    'app_page',
  }.contains(value.trim().toLowerCase());

  bool _isValidTarget(HomeBannerDto banner) {
    final type = banner.jumpType.trim().toLowerCase();
    if (!_isSupportedJumpType(type)) return false;
    return switch (type) {
      'none' => true,
      'internal_h5' || 'external_h5' => banner.normalizedH5Url != null,
      'drama' => RegExp(r'^\d+$').hasMatch(banner.jumpParam.trim()),
      'app_page' => banner.jumpParam.trim().isNotEmpty,
      _ => false,
    };
  }
}
