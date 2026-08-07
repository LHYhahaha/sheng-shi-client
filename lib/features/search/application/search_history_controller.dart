import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../data/search_history_repository_provider.dart';

class SearchHistoryState {
  const SearchHistoryState({
    this.userKey,
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final String? userKey;
  final List<String> items;
  final bool isLoading;
  final Object? error;
}

final searchHistoryControllerProvider =
    NotifierProvider<SearchHistoryController, SearchHistoryState>(
      SearchHistoryController.new,
    );

class SearchHistoryController extends Notifier<SearchHistoryState> {
  static const maxItems = 20;

  int _generation = 0;

  @override
  SearchHistoryState build() {
    ref.listen(
      authControllerProvider.select((state) => _userKey(state.session)),
      (previous, next) {
        if (previous != next) {
          unawaited(_load(next));
        }
      },
    );
    Future.microtask(
      () => _load(_userKey(ref.read(authControllerProvider).session)),
    );
    return const SearchHistoryState(isLoading: true);
  }

  Future<void> add(String value) async {
    final keyword = value.trim();
    final userKey = state.userKey;
    if (keyword.isEmpty || userKey == null) return;

    final items = [
      keyword,
      ...state.items.where((item) => item != keyword),
    ].take(maxItems).toList(growable: false);
    await _persist(userKey, items);
  }

  Future<void> remove(String value) async {
    final userKey = state.userKey;
    if (userKey == null) return;
    final items = state.items
        .where((item) => item != value)
        .toList(growable: false);
    await _persist(userKey, items);
  }

  Future<void> clear() async {
    final userKey = state.userKey;
    if (userKey == null) return;

    final previousItems = state.items;
    final generation = ++_generation;
    state = SearchHistoryState(userKey: userKey);
    try {
      await ref.read(searchHistoryRepositoryProvider).clear(userKey);
    } catch (error) {
      if (generation != _generation || state.userKey != userKey) return;
      state = SearchHistoryState(
        userKey: userKey,
        items: previousItems,
        error: error,
      );
    }
  }

  Future<void> _load(String? userKey) async {
    final generation = ++_generation;
    if (userKey == null) {
      state = const SearchHistoryState();
      return;
    }

    state = SearchHistoryState(userKey: userKey, isLoading: true);
    try {
      final items = await ref
          .read(searchHistoryRepositoryProvider)
          .read(userKey);
      if (generation != _generation) return;
      state = SearchHistoryState(userKey: userKey, items: items);
    } catch (error) {
      if (generation != _generation) return;
      state = SearchHistoryState(userKey: userKey, error: error);
    }
  }

  Future<void> _persist(String userKey, List<String> items) async {
    final previousItems = state.items;
    final generation = ++_generation;
    state = SearchHistoryState(userKey: userKey, items: items);
    try {
      await ref.read(searchHistoryRepositoryProvider).write(userKey, items);
    } catch (error) {
      if (generation != _generation || state.userKey != userKey) return;
      state = SearchHistoryState(
        userKey: userKey,
        items: previousItems,
        error: error,
      );
    }
  }

  static String? _userKey(AuthSession session) {
    final userId = session.user?.userId.trim();
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }
    final guestId = session.guestId?.trim();
    if (guestId != null && guestId.isNotEmpty) {
      return 'guest:$guestId';
    }
    final sessionId = session.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      return 'session:$sessionId';
    }
    return null;
  }
}
