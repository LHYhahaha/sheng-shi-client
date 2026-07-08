import 'dart:async';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import 'player_session_controller.dart';

enum PreparedPlaybackSessionKind { prepared, retained }

enum _WarmUpResult { firstFrame, timeout, cancelled }

typedef PlayerPrepareTimingLogger =
    void Function(
      String event, {
      String? itemId,
      String? source,
      String? details,
    });

/// 已经被播放器实例承载的相邻 item session。
///
/// `prepared` 表示向前预热的 next，`retained` 表示刚离开的 previous。两者都已经
/// 消耗 media player 资源，所以窗口必须小而明确，只服务自然滑动路径，不能当作
/// HLS 缓存层使用。
class PreparedPlaybackSession {
  PreparedPlaybackSession({
    required this.itemId,
    required this.source,
    required this.session,
    this.kind = PreparedPlaybackSessionKind.prepared,
    this.isOpened = false,
    this.hasFirstFrame = false,
    this.hasPlaybackAdvanced = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    StreamSubscription<Duration>? positionSubscription,
    StreamSubscription<int?>? widthSubscription,
  }) : _positionSubscription = positionSubscription,
       _widthSubscription = widthSubscription;

  /// prepared/retained session 对应的 item id。
  ///
  /// takeover 时必须精确匹配，不能按 source URL 命中；不同 item 可能临时共用测试 URL。
  final String itemId;

  /// 已解析的播放源。
  ///
  /// takeover 时直接复用它，避免重复 resolve/open。
  final PlaybackSource source;

  /// 已创建并可能已经 open 的播放器 session。
  ///
  /// 这个 session 持有真实解码资源，必须通过 prepare manager 释放，不能只从 window
  /// map 中移除。
  final PlayerPlaybackSession session;

  /// session 在窗口里的角色。
  ///
  /// prepared 是 next 预热，retained 是 previous 回滑保留；两者释放和日志含义不同。
  final PreparedPlaybackSessionKind kind;

  /// session 是否已经 open 过 source。
  ///
  /// prepared takeover 用它判断能否避免重复 open。
  bool isOpened;

  /// prepared session 是否已经收到首帧。
  ///
  /// 命中后会同步到 PlayerPlaybackState.hasFirstFrame，影响是否继续显示 loading。
  bool hasFirstFrame;

  /// prepared session 是否已有播放位置推进。
  ///
  /// 某些平台可能先 position 前进再收到 width；这个字段帮助判断 session 是否已经热起来。
  bool hasPlaybackAdvanced;

  /// retained previous 的播放位置快照。
  ///
  /// 回滑命中时用于恢复 UI 进度，不重新 seek。
  final Duration position;

  /// retained previous 的时长快照。
  final Duration duration;

  /// retained previous 的缓冲位置快照。
  final Duration bufferedPosition;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<int?>? _widthSubscription;

  Future<void> detachFirstFrameListener() async {
    final positionSubscription = _positionSubscription;
    final widthSubscription = _widthSubscription;
    _positionSubscription = null;
    _widthSubscription = null;
    await positionSubscription?.cancel();
    await widthSubscription?.cancel();
  }

  Future<void> dispose() async {
    await detachFirstFrameListener();
    await session.dispose();
  }
}

/// 管理 previous/current/next 范围内的 media-session 预热窗口。
///
/// 这里和 HLS preload 是两层能力：HLS preload 只发 HTTP 请求预热 playlist/segment，
/// prepare 会真的创建播放器、open source、等待首帧并处理音量。正因为成本高，
/// prepared media session window 不能随 HLS preload count 扩大；扩大窗口会让多个
/// player 同时持有解码器/音频焦点，后台释放和切页接管也会变得不可预测。
class PlayerPlaybackPrepareManager {
  PlayerPlaybackPrepareManager({
    required PlayerPlaybackSession Function() sessionFactory,
    this.maxWindowSessions = 11,
    this.warmUpTimeout = const Duration(milliseconds: 4000),
    this.timingLogger,
  }) : _sessionFactory = sessionFactory;

  /// 创建独立播放器 session 的工厂。
  ///
  /// 通过注入保证测试可替换，也避免 manager 自己知道 media_kit 具体实现。
  final PlayerPlaybackSession Function() _sessionFactory;

  /// prepared/retained window 最大 session 数。
  ///
  /// 当前有效保持 previous + next。调大意味着更多播放器实例和音频/内存风险。
  final int maxWindowSessions;

  /// warm-up 等待首帧的最长时间。
  ///
  /// 超时后仍会保留已 open session，但会 pause，避免一直静音播放消耗资源。
  final Duration warmUpTimeout;
  PlayerPrepareTimingLogger? timingLogger;
  final _window = <String, PreparedPlaybackSession>{};
  final _pendingSessions = <String, PlayerPlaybackSession>{};
  final _warmUpCancels = <String, Completer<void>>{};
  int _generation = 0;

  String? get preparedItemId => _window.keys.lastOrNull;
  List<String> get windowItemIds => List<String>.unmodifiable(_window.keys);

  Future<PreparedPlaybackSession?> prepare({
    required PlayerFeedItem item,
    required PlayerPlaybackSourceRepository sourceRepository,
  }) async {
    if (item.episode.isLocked ||
        item.episode.isUnavailable ||
        item.episode.videoSource == null) {
      // 付费锁、下架或缺 source 的 item 不能 prepare。prepare 会创建真实播放器，
      // 不能用“提前打开”绕过授权/可用性判断。
      return null;
    }

    final existing = _window.remove(item.id);
    if (existing != null) {
      _window[item.id] = existing;
      return existing;
    }

    final generation = ++_generation;
    PlayerPlaybackSession? session;
    StreamSubscription<Duration>? positionSubscription;
    StreamSubscription<int?>? widthSubscription;
    StreamSubscription<bool>? playingSubscription;
    StreamSubscription<bool>? bufferingSubscription;
    try {
      final source = await sourceRepository.resolve(item);
      if (generation != _generation) {
        return null;
      }
      session = _sessionFactory();
      _pendingSessions[item.id] = session;
      var hasFirstFrame = false;
      var hasPlaybackAdvanced = false;
      final firstFrameCompleter = Completer<void>();
      PreparedPlaybackSession? prepared;

      // 使用 position 检测首帧：如果 position > 0，说明视频已经开始播放，首帧已到达
      positionSubscription = session.positionStream.listen((position) {
        if (position > Duration.zero && !hasFirstFrame) {
          hasFirstFrame = true;
          prepared?.hasFirstFrame = true;
          _log(
            'prepare first frame received (position > 0)',
            itemId: item.id,
            source: source.playableSource,
            details: 'position=${position.inMilliseconds}ms',
          );
          if (!firstFrameCompleter.isCompleted) {
            firstFrameCompleter.complete();
          }
        }
        if (position > Duration.zero) {
          hasPlaybackAdvanced = true;
          prepared?.hasPlaybackAdvanced = true;
          _log(
            'prepare position advanced',
            itemId: item.id,
            source: source.playableSource,
            details: 'positionMs=${position.inMilliseconds}',
          );
        }
      });
      widthSubscription = session.widthStream.listen((width) {
        if (width == null || width <= 0 || hasFirstFrame) {
          return;
        }
        hasFirstFrame = true;
        prepared?.hasFirstFrame = true;
        _log(
          'prepare first frame received (width > 0)',
          itemId: item.id,
          source: source.playableSource,
          details: 'width=$width',
        );
        if (!firstFrameCompleter.isCompleted) {
          firstFrameCompleter.complete();
        }
      });
      playingSubscription = session.playingStream.listen((isPlaying) {
        _log(
          isPlaying
              ? 'prepare playingStream true'
              : 'prepare playingStream false',
          itemId: item.id,
          source: source.playableSource,
        );
      });
      bufferingSubscription = session.bufferingStream.listen((isBuffering) {
        _log(
          isBuffering ? 'prepare buffering start' : 'prepare buffering end',
          itemId: item.id,
          source: source.playableSource,
        );
      });
      final warmUpCancel = Completer<void>();
      _warmUpCancels[item.id] = warmUpCancel;
      _log(
        'prepare warm-up start',
        itemId: item.id,
        source: source.playableSource,
        details: _details([
          'playMuted=true',
          'timeoutMs=${warmUpTimeout.inMilliseconds}',
        ]),
      );
      // warm-up 必须静音播放到首帧或超时。media_kit 只有真正 open/play 后才会推进
      // 解码和 position stream；直接静态缓存 URL 无法覆盖首帧黑屏问题。
      await session.setVolume(0);
      _log(
        'prepare open start',
        itemId: item.id,
        source: source.playableSource,
      );
      await session.open(
        source.playableSource,
        play: true,
        // httpHeaders: source.httpHeaders,
      );
      _log(
        'prepare open completed',
        itemId: item.id,
        source: source.playableSource,
      );
      if (generation != _generation) {
        _pendingSessions.remove(item.id);
        _completeWarmUpCancel(item.id);
        await positionSubscription.cancel();
        await widthSubscription.cancel();
        await playingSubscription.cancel();
        await bufferingSubscription.cancel();
        await session.dispose();
        return null;
      }
      prepared = PreparedPlaybackSession(
        itemId: item.id,
        source: source,
        session: session,
        isOpened: true,
        hasFirstFrame: hasFirstFrame,
        hasPlaybackAdvanced: hasPlaybackAdvanced,
        positionSubscription: positionSubscription,
        widthSubscription: widthSubscription,
      );
      positionSubscription = null;
      widthSubscription = null;
      _pendingSessions.remove(item.id);
      await _put(prepared);
      await playingSubscription.cancel();
      await bufferingSubscription.cancel();
      playingSubscription = null;
      bufferingSubscription = null;
      unawaited(
        _finishWarmUp(
          itemId: item.id,
          generation: generation,
          firstFrame: firstFrameCompleter.future,
          cancel: warmUpCancel.future,
          session: session,
        ),
      );
      return prepared;
    } catch (_) {
      _pendingSessions.remove(item.id);
      _completeWarmUpCancel(item.id);
      await positionSubscription?.cancel();
      await widthSubscription?.cancel();
      await playingSubscription?.cancel();
      await bufferingSubscription?.cancel();
      if (session != null) {
        await session.dispose();
      }
      return null;
    }
  }

  PreparedPlaybackSession? takeIfMatches(String itemId) {
    final before = _windowItemsText;
    _completeWarmUpCancel(itemId);
    // take 会取消 warm-up pause，避免“被接管后又被后台 warm-up 任务 pause”。
    final session = _window.remove(itemId);
    _log(
      'prepare manager take',
      itemId: itemId,
      source: session?.source.playableSource,
      details: _details([
        'hit=${session != null}',
        if (session != null) 'kind=${session.kind.name}',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
    return session;
  }

  Future<void> retainPaused(PreparedPlaybackSession session) async {
    // retained previous 必须先 pause 再入窗，防止 current 与 previous 同时出声。
    await session.session.pause();
    await _put(session);
  }

  Future<void> releaseItem(
    String itemId, {
    String reason = 'release item',
  }) async {
    final before = _windowItemsText;
    _completeWarmUpCancel(itemId);
    final pending = _pendingSessions.remove(itemId);
    if (pending != null) {
      await pending.dispose();
    }
    final session = _window.remove(itemId);
    if (session != null) {
      await session.dispose();
    }
    _log(
      'prepare manager release item',
      itemId: itemId,
      source: session?.source.playableSource,
      details: _details([
        'kind=${session?.kind.name ?? 'none'}',
        'reason=$reason',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> retainOnly(Set<String> itemIds) async {
    final before = _windowItemsText;
    for (final key in List<String>.from(_window.keys)) {
      if (!itemIds.contains(key)) {
        await releaseItem(key, reason: 'retain only');
      }
    }
    _log(
      'prepare manager retain only',
      details: _details([
        'reason=retain only',
        'allowed=${itemIds.join(',')}',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> release() async {
    // 整窗释放会 bump generation，使未完成的 prepare/open 结果失效。不要只清 map，
    // 否则异步 warm-up 可能在释放后继续 pause/setVolume 已被接管的 session。
    _generation += 1;
    final before = _windowItemsText;
    for (final itemId in List<String>.from(_warmUpCancels.keys)) {
      _completeWarmUpCancel(itemId);
    }
    for (final session in List<PlayerPlaybackSession>.from(
      _pendingSessions.values,
    )) {
      await session.dispose();
    }
    _pendingSessions.clear();
    for (final session in List<PreparedPlaybackSession>.from(_window.values)) {
      await session.dispose();
    }
    _window.clear();
    _log(
      'prepare manager release all',
      details: _details([
        'reason=release all',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> _finishWarmUp({
    required String itemId,
    required int generation,
    required Future<void> firstFrame,
    required Future<void> cancel,
    required PlayerPlaybackSession session,
  }) async {
    _WarmUpResult result;
    try {
      result = await Future.any<_WarmUpResult>([
        firstFrame.then((_) => _WarmUpResult.firstFrame),
        Future<void>.delayed(warmUpTimeout).then((_) => _WarmUpResult.timeout),
        cancel.then((_) => _WarmUpResult.cancelled),
      ]);
    } catch (_) {
      result = _WarmUpResult.timeout;
    }

    final prepared = _window[itemId];
    if (result == _WarmUpResult.cancelled ||
        generation != _generation ||
        prepared?.session != session) {
      _log(
        'prepare warm-up cancelled',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: _details(['reason=cancelled_or_stale']),
      );
      return;
    }

    try {
      if (result == _WarmUpResult.timeout) {
        _log(
          'prepare warm-up timeout',
          itemId: itemId,
          source: prepared?.source.playableSource,
          details: 'timeoutMs=${warmUpTimeout.inMilliseconds}',
        );
      }
      _log(
        'prepare pause called',
        itemId: itemId,
        source: prepared?.source.playableSource,
      );
      // 首帧到达或超时后都要 pause 并恢复音量。保留打开好的 session 是为了接管快，
      // 不是让 next 在后台继续播放。
      await session.pause();
      await session.setVolume(100);
      _log(
        'prepare warm-up end',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: _details([
          'result=${result.name}',
          'firstFrameReady=${prepared?.hasFirstFrame ?? false}',
        ]),
      );
    } catch (error) {
      _log(
        'prepare warm-up failed',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: 'error=$error',
      );
    } finally {
      _warmUpCancels.remove(itemId);
    }
  }

  void _completeWarmUpCancel(String itemId) {
    final cancel = _warmUpCancels.remove(itemId);
    if (cancel != null && !cancel.isCompleted) {
      cancel.complete();
    }
  }

  Future<void> _put(PreparedPlaybackSession session) async {
    final before = _windowItemsText;
    final replaced = _window.remove(session.itemId);
    if (replaced != null && replaced.session != session.session) {
      await replaced.dispose();
    }
    _window[session.itemId] = session;
    // LRU 风格淘汰最旧 session，确保窗口不会因为快速滑动积累成播放器池。
    while (_window.length > maxWindowSessions) {
      final oldestKey = _window.keys.first;
      await releaseItem(oldestKey, reason: 'window overflow');
    }
    _log(
      'prepare manager put',
      itemId: session.itemId,
      source: session.source.playableSource,
      details: _details([
        'kind=${session.kind.name}',
        'reason=put',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  void _log(String event, {String? itemId, String? source, String? details}) {
    timingLogger?.call(event, itemId: itemId, source: source, details: details);
  }

  String get _windowItemsText => _window.keys.join(',');

  String _details(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(' ');
  }
}

class NoopPlayerPlaybackPrepareManager extends PlayerPlaybackPrepareManager {
  NoopPlayerPlaybackPrepareManager()
    : super(sessionFactory: _NoopPlaybackSession.new);

  @override
  Future<PreparedPlaybackSession?> prepare({
    required PlayerFeedItem item,
    required PlayerPlaybackSourceRepository sourceRepository,
  }) async {
    return null;
  }

  @override
  PreparedPlaybackSession? takeIfMatches(String itemId) => null;

  @override
  Future<void> retainPaused(PreparedPlaybackSession session) async {
    await session.session.pause();
  }

  @override
  Future<void> releaseItem(
    String itemId, {
    String reason = 'release item',
  }) async {}

  @override
  Future<void> retainOnly(Set<String> itemIds) async {}

  @override
  Future<void> release() async {}
}

class _NoopPlaybackSession implements PlayerPlaybackSession {
  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => const Stream<Duration>.empty();

  @override
  Stream<double> get rateStream => const Stream<double>.empty();

  @override
  Stream<int?> get widthStream => const Stream<int?>.empty();

  @override
  Stream<String> get errorStream => const Stream<String>.empty();

  @override
  Future<void> open(
    String source, {
    bool play = true,
    Duration? start,
    Map<String, String>? httpHeaders,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}
