import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_cleanup_types.dart';

/// 用户收藏状态的本地同步层。
///
/// 它只保存本次登录期间最新的客户端收藏操作，用于覆盖服务端列表的最终一致性延迟；
/// 不是服务端数据的替代品。退出或切换账号时必须清空。
final userLibrarySyncControllerProvider =
    NotifierProvider<UserLibrarySyncController, UserLibrarySyncState>(
      UserLibrarySyncController.new,
    );

class UserLibrarySyncState {
  const UserLibrarySyncState({this.favoriteByDramaId = const {}});

  final Map<String, bool> favoriteByDramaId;

  bool? favoriteFor(String dramaId) => favoriteByDramaId[dramaId];
}

class UserLibrarySyncController extends Notifier<UserLibrarySyncState> {
  @override
  UserLibrarySyncState build() => const UserLibrarySyncState();

  /// 本地用户操作优先于随后到达的旧列表快照。
  void setFavorite({required String dramaId, required bool isFavorited}) {
    state = UserLibrarySyncState(
      favoriteByDramaId: Map<String, bool>.unmodifiable({
        ...state.favoriteByDramaId,
        dramaId: isFavorited,
      }),
    );
  }

  /// 仅在尚未有本地操作时采纳接口快照，避免旧回包使 UI 回退。
  void observeFavoriteFromServer({
    required String dramaId,
    required bool? isFavorited,
  }) {
    if (isFavorited == null || state.favoriteByDramaId.containsKey(dramaId)) {
      return;
    }
    setFavorite(dramaId: dramaId, isFavorited: isFavorited);
  }

  void resetForSessionCleanup(SessionCleanupReason reason) {
    state = const UserLibrarySyncState();
  }
}
