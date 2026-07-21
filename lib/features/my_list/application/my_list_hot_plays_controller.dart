import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/runtime/api_lang_provider.dart';
import '../../search/data/search_repository_provider.dart';
import '../../search/domain/search_rankings.dart';

final myListHotPlaysControllerProvider =
    NotifierProvider<MyListHotPlaysController, MyListHotPlaysState>(
      MyListHotPlaysController.new,
    );

class MyListHotPlaysState {
  const MyListHotPlaysState({
    this.dramas = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SearchRankDrama> dramas;
  final bool isLoading;
  final Object? error;

  bool get shouldShow => dramas.length >= MyListHotPlaysController.maxItems;
}

/// Loads only the hot-play ranking used below both My List tabs.
class MyListHotPlaysController extends Notifier<MyListHotPlaysState> {
  static const maxItems = 6;

  int _generation = 0;

  @override
  MyListHotPlaysState build() {
    ref.listen(appLocaleControllerProvider.select(apiLangFromLocale), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) {
        return;
      }
      unawaited(load());
    });
    return const MyListHotPlaysState();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = MyListHotPlaysState(dramas: state.dramas, isLoading: true);

    try {
      final ranking = await ref.read(searchRepositoryProvider).getHotPlays();
      if (generation != _generation) {
        return;
      }
      state = MyListHotPlaysState(
        dramas: List<SearchRankDrama>.unmodifiable(
          ranking.dramas.take(maxItems),
        ),
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      // Keep stale content during a refresh failure; with no content the
      // section stays hidden as required.
      state = MyListHotPlaysState(dramas: state.dramas, error: error);
    }
  }
}
