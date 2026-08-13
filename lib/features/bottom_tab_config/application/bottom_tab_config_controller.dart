import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bottom_tab_config_remote_data_source_provider.dart';
import '../data/dto/bottom_tab_response_dto.dart';

final bottomTabConfigControllerProvider =
    NotifierProvider<BottomTabConfigController, BottomTabConfigState>(
      BottomTabConfigController.new,
    );

class BottomTabConfigState {
  const BottomTabConfigState({
    this.tabs = const <BottomTabDto>[],
    this.isLoading = false,
    this.hasLoaded = false,
    this.unavailableConfigIds = const <String>{},
  });

  final List<BottomTabDto> tabs;
  final bool isLoading;
  final bool hasLoaded;
  final Set<String> unavailableConfigIds;

  BottomTabConfigState copyWith({
    List<BottomTabDto>? tabs,
    bool? isLoading,
    bool? hasLoaded,
    Set<String>? unavailableConfigIds,
  }) {
    return BottomTabConfigState(
      tabs: tabs ?? this.tabs,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      unavailableConfigIds: unavailableConfigIds ?? this.unavailableConfigIds,
    );
  }
}

/// 冷启动期间只拉取一次的动态 Tab 配置。
///
/// 服务端已完成渠道匹配及同一位置的优先级决策；客户端只接受每个槽位的首个有效项。
class BottomTabConfigController extends Notifier<BottomTabConfigState> {
  Future<void>? _loadOperation;

  @override
  BottomTabConfigState build() => const BottomTabConfigState();

  Future<void> loadOnce() {
    if (state.hasLoaded) {
      return Future<void>.value();
    }
    return _loadOperation ??= _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await ref
          .read(bottomTabConfigRemoteDataSourceProvider)
          .fetchBottomTabs();
      final seenSlots = <String>{};
      final tabs = <BottomTabDto>[];
      for (final tab in response.tabs) {
        final slot = tab.replaceTab.trim().toLowerCase();
        if (!_isValid(tab) || !seenSlots.add(slot)) {
          continue;
        }
        tabs.add(tab);
      }
      state = state.copyWith(tabs: tabs, isLoading: false, hasLoaded: true);
    } catch (_) {
      // 请求失败、超时或数据不合法时完整降级到客户端默认 Tab。
      state = state.copyWith(
        tabs: const <BottomTabDto>[],
        isLoading: false,
        hasLoaded: true,
      );
    }
  }

  BottomTabDto? tabForSlot(String slot) {
    final normalizedSlot = slot.trim().toLowerCase();
    for (final tab in state.tabs) {
      if (tab.replaceTab.trim().toLowerCase() == normalizedSlot &&
          !state.unavailableConfigIds.contains(tab.tabConfigId)) {
        return tab;
      }
    }
    return null;
  }

  /// 任一状态 Icon 加载失败时仅禁用该条配置，恢复对应客户端默认 Tab。
  void disableTab(String tabConfigId) {
    if (tabConfigId.isEmpty ||
        state.unavailableConfigIds.contains(tabConfigId)) {
      return;
    }
    state = state.copyWith(
      unavailableConfigIds: {...state.unavailableConfigIds, tabConfigId},
    );
  }

  bool _isValid(BottomTabDto tab) {
    // 命中槽位且 H5 地址非空时立即替换内容；图标和标题各自独立降级，
    // 不应阻断 H5 页面，避免用户先看到客户端默认页再切换的闪动。
    return _supportedSlots.contains(tab.replaceTab.trim().toLowerCase()) &&
        tab.h5Url.trim().isNotEmpty;
  }
}

const _supportedSlots = <String>{
  'home',
  'recommend_tab',
  'member_tab',
  'favorites',
  'profile',
};
