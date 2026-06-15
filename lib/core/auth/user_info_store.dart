import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/dto/user_info_dto.dart';
import 'user_info_storage.dart';
import 'user_info_storage_provider.dart';

final userInfoStoreProvider = NotifierProvider<UserInfoStore, UserInfoSnapshot>(
  UserInfoStore.new,
);

/// 用户信息快照。
class UserInfoSnapshot {
  const UserInfoSnapshot({
    this.userId,
    this.showId,
    this.nickname,
    this.avatar,
    this.language,
    this.status,
    this.vipExpireAt,
    this.coin,
    this.bonusCoin,
    this.autoUnlock,
  });

  const UserInfoSnapshot.empty()
    : userId = null,
      showId = null,
      nickname = null,
      avatar = null,
      language = null,
      status = null,
      vipExpireAt = null,
      coin = null,
      bonusCoin = null,
      autoUnlock = null;

  final int? userId;
  final String? showId;
  final String? nickname;
  final String? avatar;
  final String? language;
  final int? status;
  final String? vipExpireAt;
  final int? coin;
  final int? bonusCoin;
  final int? autoUnlock;

  bool get isEmpty =>
      userId == null &&
      showId == null &&
      nickname == null &&
      avatar == null &&
      language == null &&
      status == null &&
      vipExpireAt == null &&
      coin == null &&
      bonusCoin == null &&
      autoUnlock == null;

  bool get hasUserInfo => showId != null || nickname != null;

  Map<String, Object?> toJson() {
    return {
      'userId': userId,
      'showId': showId,
      'nickname': nickname,
      'avatar': avatar,
      'language': language,
      'status': status,
      'vipExpireAt': vipExpireAt,
      'coin': coin,
      'bonusCoin': bonusCoin,
      'autoUnlock': autoUnlock,
    };
  }

  factory UserInfoSnapshot.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const UserInfoSnapshot.empty();
    }

    return UserInfoSnapshot(
      userId: _nullableInt(json['userId']),
      showId:
          _nullableString(json['showId']) ?? _nullableString(json['showid']),
      nickname: _nullableString(json['nickname']),
      avatar: _nullableString(json['avatar']),
      language: _nullableString(json['language']),
      status: _nullableInt(json['status']),
      vipExpireAt: _nullableString(json['vipExpireAt']),
      coin: _nullableInt(json['coin']),
      bonusCoin: _nullableInt(json['bonusCoin']),
      autoUnlock: _nullableInt(json['autoUnlock']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  static int? _nullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

/// 用户信息应用层唯一读写入口。
class UserInfoStore extends Notifier<UserInfoSnapshot> {
  bool _hydrateFinished = false;
  late final Future<void> _hydrateFuture;

  @override
  UserInfoSnapshot build() {
    _hydrateFuture = _hydrateFromStorage();
    return const UserInfoSnapshot.empty();
  }

  UserInfoStorage get _storage => ref.read(userInfoStorageProvider);

  UserInfoSnapshot get snapshot => state;

  Future<void> _hydrateFromStorage() async {
    if (_hydrateFinished) {
      return;
    }
    _hydrateFinished = true;

    final stored = await _storage.read();
    if (stored != null && !stored.isEmpty) {
      state = stored;
    }
  }

  /// 等待初始化完成
  Future<void> waitForHydration() => _hydrateFuture;

  Future<void> save(UserInfoDto userInfo) async {
    _hydrateFinished = true;
    final snapshot = UserInfoSnapshot(
      userId: userInfo.userId,
      showId: userInfo.showId,
      nickname: userInfo.nickname,
      avatar: userInfo.avatar,
      language: userInfo.language,
      status: userInfo.status,
      vipExpireAt: userInfo.vipExpireAt,
      coin: userInfo.coin,
      bonusCoin: userInfo.bonusCoin,
      autoUnlock: userInfo.autoUnlock,
    );
    await _storage.write(snapshot);
    state = snapshot;
  }

  /// 从 Map 保存用户信息（用于 ApiClient 内部重新登录后保存用户信息）
  Future<void> saveFromMap(Map<String, dynamic> data) async {
    _hydrateFinished = true;
    final snapshot = UserInfoSnapshot(
      userId: _parseInt(data['userId']),
      showId: _parseString(data['showId']) ?? _parseString(data['showid']),
      nickname: _parseString(data['nickname']),
      avatar: _parseString(data['avatar']),
      language: _parseString(data['language']),
      status: _parseInt(data['status']),
      vipExpireAt: _parseString(data['vipExpireAt']),
      coin: _parseInt(data['coin']),
      bonusCoin: _parseInt(data['bonusCoin']),
      autoUnlock: _parseInt(data['autoUnlock']),
    );
    await _storage.write(snapshot);
    state = snapshot;
  }

  Future<void> clear() async {
    _hydrateFinished = true;
    await _storage.clear();
    state = const UserInfoSnapshot.empty();
  }

  static String? _parseString(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
