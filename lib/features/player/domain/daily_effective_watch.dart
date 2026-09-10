import 'dart:convert';

/// Reward days always follow India Standard Time, independent of device zone.
abstract final class IndiaWatchDay {
  static const offset = Duration(hours: 5, minutes: 30);

  static String key(DateTime instant) {
    final india = instant.toUtc().add(offset);
    return '${india.year.toString().padLeft(4, '0')}-'
        '${india.month.toString().padLeft(2, '0')}-'
        '${india.day.toString().padLeft(2, '0')}';
  }

  static DateTime nextBoundary(DateTime instant) {
    final india = instant.toUtc().add(offset);
    return DateTime.utc(
      india.year,
      india.month,
      india.day + 1,
    ).subtract(offset);
  }
}

class WatchedRange {
  const WatchedRange(this.startMs, this.endMs);
  final int startMs;
  final int endMs;
}

/// Immutable persisted ledger. Media coverage and elapsed time are distinct.
class DailyEffectiveWatchSnapshot {
  DailyEffectiveWatchSnapshot({
    required this.userId,
    required this.dayKey,
    this.creditedMs = 0,
    Map<String, List<WatchedRange>> ranges = const {},
  }) : ranges = Map.unmodifiable({
         for (final entry in ranges.entries)
           entry.key: List<WatchedRange>.unmodifiable(entry.value),
       });

  final String userId;
  final String dayKey;
  final double creditedMs;
  final Map<String, List<WatchedRange>> ranges;
  int get totalEffectiveMs => creditedMs.floor();
  int get totalEffectiveSeconds => (creditedMs / 1000).floor();

  DailyEffectiveWatchSnapshot credit({
    required String dramaId,
    required String episodeId,
    required int startMs,
    required int endMs,
    required double elapsedMs,
  }) {
    if (startMs < 0 ||
        endMs <= startMs ||
        !elapsedMs.isFinite ||
        elapsedMs <= 0) {
      return this;
    }
    final key = jsonEncode([dramaId, episodeId]);
    final existing = ranges[key] ?? const <WatchedRange>[];
    var unseen = endMs - startMs;
    for (final range in existing) {
      final left = startMs > range.startMs ? startMs : range.startMs;
      final right = endMs < range.endMs ? endMs : range.endMs;
      if (right > left) unseen -= right - left;
    }
    if (unseen <= 0) return this;
    final ordered = [...existing, WatchedRange(startMs, endMs)]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final merged = <WatchedRange>[];
    for (final range in ordered) {
      if (merged.isEmpty || merged.last.endMs < range.startMs) {
        merged.add(range);
      } else if (range.endMs > merged.last.endMs) {
        final last = merged.removeLast();
        merged.add(WatchedRange(last.startMs, range.endMs));
      }
    }
    return DailyEffectiveWatchSnapshot(
      userId: userId,
      dayKey: dayKey,
      creditedMs: creditedMs + elapsedMs * unseen / (endMs - startMs),
      ranges: {...ranges, key: merged},
    );
  }
}

abstract interface class DailyEffectiveWatchRepository {
  Future<DailyEffectiveWatchSnapshot?> read(String userId, String dayKey);
  Future<void> write(DailyEffectiveWatchSnapshot snapshot);
}

class EffectiveWatchSample {
  const EffectiveWatchSample({
    required this.owner,
    required this.userId,
    required this.dramaId,
    required this.episodeId,
    required this.generation,
    required this.positionMs,
    required this.monotonic,
    required this.utc,
    required this.rate,
  });
  final String owner;
  final String userId;
  final String dramaId;
  final String episodeId;
  final int generation;
  final int positionMs;
  final Duration monotonic;
  final DateTime utc;
  final double rate;
}

class EffectiveWatchSegment {
  const EffectiveWatchSegment(this.start, this.end);
  final EffectiveWatchSample start;
  final EffectiveWatchSample end;
}

/// Only continuous, confirmed media progress can produce creditable segments.
class EffectiveWatchAccumulator {
  EffectiveWatchSample? _previous;

  void stop([String? owner]) {
    if (owner == null || _previous?.owner == owner) _previous = null;
  }

  EffectiveWatchSegment? observe(EffectiveWatchSample sample) {
    final previous = _previous;
    _previous = sample;
    if (previous == null ||
        previous.owner != sample.owner ||
        previous.userId != sample.userId ||
        previous.dramaId != sample.dramaId ||
        previous.episodeId != sample.episodeId ||
        previous.generation != sample.generation ||
        previous.rate != sample.rate ||
        !sample.rate.isFinite ||
        sample.rate <= 0) {
      return null;
    }
    final elapsed =
        (sample.monotonic - previous.monotonic).inMicroseconds / 1000;
    final wallElapsed =
        sample.utc.difference(previous.utc).inMicroseconds / 1000;
    final advance = sample.positionMs - previous.positionMs;
    // Position callbacks normally arrive well within one second. Long gaps,
    // clock jumps and implausible movement are never backfilled.
    if (elapsed <= 0 ||
        elapsed > 2500 ||
        advance <= 0 ||
        previous.positionMs < 0 ||
        (wallElapsed - elapsed).abs() > 250 ||
        (advance - elapsed * sample.rate).abs() > 500) {
      return null;
    }
    return EffectiveWatchSegment(previous, sample);
  }
}
