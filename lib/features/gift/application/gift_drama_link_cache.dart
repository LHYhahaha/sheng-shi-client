import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gift_remote_data_source_provider.dart';
import '../domain/gift_link_data.dart';

/// 分享赠剧资格的短时缓存。
///
/// 分享码和剩余次数会变化，因此只在很短时间内复用；同一剧集的预取和点击请求
/// 共享同一个 Future，避免重复生成链接或并发请求。
class GiftDramaLinkCache {
  GiftDramaLinkCache({
    required GiftDramaLinkLoader loader,
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _loader = loader,
       _clock = clock ?? DateTime.now;

  final GiftDramaLinkLoader _loader;
  final Duration ttl;
  final DateTime Function() _clock;
  final Map<int, _GiftDramaLinkCacheEntry> _entries = {};
  final Map<int, Future<GiftLinkData>> _inFlight = {};
  final Map<int, int> _versions = {};
  int _clearEpoch = 0;

  Future<GiftLinkData> get(int dramaId) {
    final inFlight = _inFlight[dramaId];
    if (inFlight != null) return inFlight;
    final now = _clock();
    final cached = _entries[dramaId];
    if (cached != null && now.difference(cached.createdAt) < ttl) {
      return Future<GiftLinkData>.value(cached.data);
    }
    return _request(dramaId);
  }

  /// 即使缓存仍有效也请求最新资格；同剧集在途请求会被复用。
  Future<GiftLinkData> refresh(int dramaId) =>
      _inFlight[dramaId] ?? _request(dramaId);

  Future<GiftLinkData>? inFlightFor(int dramaId) => _inFlight[dramaId];

  Future<GiftLinkData> _request(int dramaId) {
    final requestVersion = _versions[dramaId] ?? 0;
    final requestClearEpoch = _clearEpoch;
    late final Future<GiftLinkData> request;
    request = _loader(dramaId: dramaId)
        .then((data) {
          if ((_versions[dramaId] ?? 0) == requestVersion &&
              _clearEpoch == requestClearEpoch) {
            _entries[dramaId] = _GiftDramaLinkCacheEntry(
              data: data,
              createdAt: _clock(),
            );
          }
          return data;
        })
        .whenComplete(() {
          if (identical(_inFlight[dramaId], request)) {
            _inFlight.remove(dramaId);
          }
        });
    _inFlight[dramaId] = request;
    return request;
  }

  void prefetch(int dramaId) {
    unawaited(get(dramaId).then<void>((_) {}, onError: (_, _) {}));
  }

  void invalidate(int dramaId) {
    _entries.remove(dramaId);
    _inFlight.remove(dramaId);
    _versions.update(dramaId, (version) => version + 1, ifAbsent: () => 1);
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
    _versions.clear();
    _clearEpoch++;
  }
}

typedef GiftDramaLinkLoader =
    Future<GiftLinkData> Function({required int dramaId});

final giftDramaLinkCacheProvider = Provider<GiftDramaLinkCache>((ref) {
  final source = ref.watch(giftRemoteDataSourceProvider);
  return GiftDramaLinkCache(loader: source.getDramaGiftLink);
});

class _GiftDramaLinkCacheEntry {
  const _GiftDramaLinkCacheEntry({required this.data, required this.createdAt});

  final GiftLinkData data;
  final DateTime createdAt;
}
