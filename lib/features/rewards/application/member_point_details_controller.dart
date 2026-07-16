import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_points_repository_provider.dart';
import '../domain/member_point_details.dart';

class MemberPointDetailsState {
  const MemberPointDetailsState({
    this.items = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalNum = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<MemberPointDetailRecord> items;
  final int page;
  final int pageSize;
  final int totalNum;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  bool get hasMore => items.length < totalNum;

  MemberPointDetailsState copyWith({
    List<MemberPointDetailRecord>? items,
    int? page,
    int? pageSize,
    int? totalNum,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) {
    return MemberPointDetailsState(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalNum: totalNum ?? this.totalNum,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final memberPointDetailsControllerProvider =
    NotifierProvider<MemberPointDetailsController, MemberPointDetailsState>(
      MemberPointDetailsController.new,
    );

class MemberPointDetailsController extends Notifier<MemberPointDetailsState> {
  static const _defaultPageSize = 20;
  int _generation = 0;

  @override
  MemberPointDetailsState build() {
    return const MemberPointDetailsState(pageSize: _defaultPageSize);
  }

  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final page = await ref
          .read(memberPointsRepositoryProvider)
          .getPointDetails(page: 1, pageSize: _defaultPageSize);
      if (generation != _generation) return;
      state = state.copyWith(
        items: page.list,
        page: page.page,
        pageSize: page.pageSize,
        totalNum: page.totalNum,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final generation = _generation;
    final nextPage = state.page + 1;
    final currentItems = state.items;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await ref
          .read(memberPointsRepositoryProvider)
          .getPointDetails(page: nextPage, pageSize: state.pageSize);
      if (generation != _generation) return;
      state = state.copyWith(
        items: [...currentItems, ...page.list],
        page: page.page,
        pageSize: page.pageSize,
        totalNum: page.totalNum,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }
}
