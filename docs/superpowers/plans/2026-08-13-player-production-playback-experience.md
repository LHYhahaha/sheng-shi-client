# Player Production Playback Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the short-drama player production-ready for watched-progress reopen, Home/My List entry speed, and smooth vertical swipe playback.

**Architecture:** Keep the current direct remote HLS path and previous/current/next media-session window. Add a typed entry intent and resume-progress resolution layer so local/list progress can start playback immediately while remote progress only corrects safe stale state. Keep HLS preload conservative and budgeted so adjacent warming does not steal bandwidth from the current item.

**Tech Stack:** Flutter, Riverpod, GoRouter, media_kit/media_kit_video, SharedPreferences, existing player timing trace.

## Global Constraints

- Do not productionize local HLS proxy/cache in this phase.
- Do not expand prepared media session count beyond one next and one previous.
- Do not block first frame on `/api/user/watch/progress`.
- Do not let adjacent HLS preload start before the current item has first frame.
- Preserve locked, unavailable, and missing-source boundaries.
- Preserve Android stable/low-end performance policy caps.
- Keep source URLs out of ordinary UI; timing logs may include them only behind `PLAYER_TIMING_LOGS=true`.
- Release-device validation must use `--dart-define=PLAYER_TIMING_LOGS=true`.

---

## File Structure

- Create `lib/features/player/domain/initial_playback_intent.dart`
  - Defines the typed route/list/Home entry intent and progress source enum.
- Modify `lib/app/router/app_router.dart`
  - Reads `InitialPlaybackIntent` from `GoRouterState.extra` and passes it to `PlayerPage`.
- Modify `lib/features/player/presentation/pages/player_page.dart`
  - Accepts the intent, applies local/list progress before remote progress, and records timing.
- Modify `lib/features/home/presentation/pages/home_page.dart`
  - Builds Home route intents and later attaches local progress when Task 2 adds the resolver.
- Modify `lib/features/my_list/domain/my_list_item.dart`
  - Exposes watch progress fields if the DTO already has them or Task 3 adds them.
- Modify `lib/features/my_list/data/dto/play_history_item_dto.dart`
  - Parses watch progress seconds and duration seconds when returned by the backend.
- Modify `lib/features/my_list/data/mapper/my_list_mapper.dart`
  - Maps DTO progress fields into `MyListItem`.
- Modify `lib/features/my_list/presentation/pages/my_list_page.dart`
  - Sends list progress through `InitialPlaybackIntent`.
- Modify `lib/features/player/application/player_playback_controller.dart`
  - Coordinates prepared-hit plus resume-seek and adds preload budget timing.
- Modify `lib/features/player/data/hls_playlist_preloader.dart`
  - Stops segment preheat before exceeding budget where possible.
- Test files:
  - `test/features/player/initial_playback_intent_test.dart`
  - `test/features/player/player_page_initial_intent_test.dart`
  - `test/features/player/player_playback_controller_test.dart`
  - `test/features/player/hls_playlist_preloader_test.dart`
  - `test/features/my_list/my_list_mapper_test.dart`

---

### Task 1: Typed Player Entry Intent

**Files:**
- Create: `lib/features/player/domain/initial_playback_intent.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Test: `test/features/player/initial_playback_intent_test.dart`

**Interfaces:**
- Produces: `InitialPlaybackIntent`, `InitialPlaybackProgress`, `InitialPlaybackProgressSource`
- Consumes: existing `PlayerPage` route parameters and `ForYouPlayerHandoff`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drama_client/features/player/domain/initial_playback_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intent carries initial progress only when resumable', () {
    final intent = InitialPlaybackIntent.singleDrama(
      dramaId: '799',
      episodeId: '14327',
      trigger: 'play_history_item',
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      progress: InitialPlaybackProgress(
        position: const Duration(seconds: 35),
        duration: const Duration(seconds: 126),
        source: InitialPlaybackProgressSource.list,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(900),
      ),
    );

    expect(intent.targetItemId, 'single:799:14327');
    expect(intent.progress?.canResume, isTrue);
    expect(intent.progress?.source, InitialPlaybackProgressSource.list);
  });

  test('near-ended progress is not resumable', () {
    final progress = InitialPlaybackProgress(
      position: const Duration(seconds: 125),
      duration: const Duration(seconds: 126),
      source: InitialPlaybackProgressSource.local,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(900),
    );

    expect(progress.canResume, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/initial_playback_intent_test.dart`

Expected: FAIL because `initial_playback_intent.dart` does not exist.

- [ ] **Step 3: Add the domain model**

```dart
enum InitialPlaybackProgressSource { local, remote, list, handoff }

class InitialPlaybackProgress {
  const InitialPlaybackProgress({
    required this.position,
    required this.duration,
    required this.source,
    required this.updatedAt,
  });

  final Duration position;
  final Duration duration;
  final InitialPlaybackProgressSource source;
  final DateTime updatedAt;

  bool get canResume {
    if (position <= Duration.zero || duration <= Duration.zero) {
      return false;
    }
    return position < duration - const Duration(seconds: 2);
  }
}

class InitialPlaybackIntent {
  const InitialPlaybackIntent({
    required this.dramaId,
    required this.episodeId,
    required this.trigger,
    required this.userActionAt,
    this.progress,
  });

  factory InitialPlaybackIntent.singleDrama({
    required String dramaId,
    required String episodeId,
    required String trigger,
    required DateTime userActionAt,
    InitialPlaybackProgress? progress,
  }) {
    return InitialPlaybackIntent(
      dramaId: dramaId,
      episodeId: episodeId,
      trigger: trigger,
      userActionAt: userActionAt,
      progress: progress,
    );
  }

  final String dramaId;
  final String episodeId;
  final String trigger;
  final DateTime userActionAt;
  final InitialPlaybackProgress? progress;

  String get targetItemId => 'single:$dramaId:$episodeId';
}
```

- [ ] **Step 4: Wire router and PlayerPage without behavior changes**

In `app_router.dart`, when `state.extra is InitialPlaybackIntent`, pass it into `PlayerPage`.

In `PlayerPage`, add an optional `initialIntent` parameter and keep existing `dramaId`, `episodeId`, and trigger behavior intact.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/player/initial_playback_intent_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/domain/initial_playback_intent.dart lib/app/router/app_router.dart lib/features/player/presentation/pages/player_page.dart test/features/player/initial_playback_intent_test.dart
git commit -m "feat: add typed player entry intent"
```

---

### Task 2: Home Local Progress Priority

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Test: `test/features/player/player_page_initial_intent_test.dart`

**Interfaces:**
- Consumes: `InitialPlaybackIntent.singleDrama(...)`
- Consumes: `PlaybackProgressRepository.getProgress(String itemId)`
- Produces: Home route extras that target the local progress episode when available.

- [ ] **Step 1: Write the failing test**

Create a widget/provider test that seeds `PlaybackProgressRepository` with `single:799:14327` at 35s, simulates a Home card tap for drama `799`, and expects the route intent episode id to be `14327`.

```dart
testWidgets('home tap prefers local watched episode progress', (tester) async {
  final progress = PlaybackProgress(
    itemId: 'single:799:14327',
    position: const Duration(seconds: 35),
    duration: const Duration(seconds: 126),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );

  final intent = await resolveHomePlaybackIntentForTest(
    dramaId: '799',
    fallbackEpisodeId: '1',
    trigger: 'home_card_tap',
    localProgress: progress,
    userActionAt: DateTime.fromMillisecondsSinceEpoch(1200),
  );

  expect(intent.episodeId, '14327');
  expect(intent.progress?.source, InitialPlaybackProgressSource.local);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/player_page_initial_intent_test.dart`

Expected: FAIL because the resolver/test hook does not exist.

- [ ] **Step 3: Add a small resolver helper near Home entry code**

Add a helper that converts a local `PlaybackProgress?` into `InitialPlaybackIntent`. Keep it side-effect free so it is easy to test.

```dart
InitialPlaybackIntent buildHomePlaybackIntent({
  required String dramaId,
  required String fallbackEpisodeId,
  required String trigger,
  required DateTime userActionAt,
  PlaybackProgress? localProgress,
}) {
  final local = localProgress;
  if (local != null && local.canResume) {
    final parts = local.itemId.split(':');
    final episodeId = parts.length == 3 ? parts[2] : fallbackEpisodeId;
    return InitialPlaybackIntent.singleDrama(
      dramaId: dramaId,
      episodeId: episodeId,
      trigger: trigger,
      userActionAt: userActionAt,
      progress: InitialPlaybackProgress(
        position: local.position,
        duration: local.duration,
        source: InitialPlaybackProgressSource.local,
        updatedAt: local.updatedAt,
      ),
    );
  }
  return InitialPlaybackIntent.singleDrama(
    dramaId: dramaId,
    episodeId: fallbackEpisodeId,
    trigger: trigger,
    userActionAt: userActionAt,
  );
}
```

- [ ] **Step 4: Use helper on Home card tap**

On Home card tap:

1. Record `tappedAt`.
2. Read `playbackProgressRepositoryProvider`.
3. Probe known local item ids for this drama if available. If the repository cannot list by drama, keep fallback route and let Task 3/remote/list paths cover direct episode.
4. Push `RoutePaths.playerLocation(...)` with `extra: intent`.

Do not add remote API calls to Home tap.

- [ ] **Step 5: PlayerPage applies initial progress before remote progress**

When `initialIntent.progress?.canResume == true`, set `_resumeProgress` and call `_playbackController.setPendingResumeProgress(...)` before `_loadFeedForTiming`.

Record timing:

```dart
_playbackController.recordPlaybackTiming(
  'initial intent progress applied',
  itemId: initialIntent.targetItemId,
  details: 'source=${initialIntent.progress!.source.name}',
);
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/player/player_page_initial_intent_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart lib/features/player/presentation/pages/player_page.dart test/features/player/player_page_initial_intent_test.dart
git commit -m "feat: prefer local playback progress on player entry"
```

---

### Task 3: My List Progress-Carrying Entry

**Files:**
- Modify: `lib/features/my_list/data/dto/play_history_item_dto.dart`
- Modify: `lib/features/my_list/domain/my_list_item.dart`
- Modify: `lib/features/my_list/data/mapper/my_list_mapper.dart`
- Modify: `lib/features/my_list/presentation/pages/my_list_page.dart`
- Test: `test/features/my_list/my_list_mapper_test.dart`

**Interfaces:**
- Consumes: backend fields `watchSecond` and `durationSecond` if present.
- Produces: `InitialPlaybackIntent` with `InitialPlaybackProgressSource.list`.

- [ ] **Step 1: Write the failing mapper test**

```dart
test('play history maps watch progress for player intent', () {
  final dto = PlayHistoryItemDto.fromJson({
    'dramaId': 799,
    'episodeId': 14327,
    'title': 'Drama',
    'coverUrl': 'https://example.com/cover.jpg',
    'watchSecond': 35,
    'durationSecond': 126,
  });

  final item = const MyListMapper().mapPlayHistoryItem(dto);

  expect(item.episodeId, 14327);
  expect(item.watchSecond, 35);
  expect(item.durationSecond, 126);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/my_list/my_list_mapper_test.dart`

Expected: FAIL until DTO/domain fields are added.

- [ ] **Step 3: Add fields**

Add nullable integer fields:

```dart
final int? watchSecond;
final int? durationSecond;
```

Parse them with `JsonFieldParser.optionalInt`.

- [ ] **Step 4: Build list progress intent on click**

In `_openItem`, when `watchSecond > 0 && durationSecond > 0`, set:

```dart
progress: InitialPlaybackProgress(
  position: Duration(seconds: item.watchSecond!),
  duration: Duration(seconds: item.durationSecond!),
  source: InitialPlaybackProgressSource.list,
  updatedAt: DateTime.now(),
)
```

Pass this through `context.push(..., extra: intent)`.

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/features/my_list/my_list_mapper_test.dart
flutter test test/features/player/player_page_initial_intent_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/my_list/data/dto/play_history_item_dto.dart lib/features/my_list/domain/my_list_item.dart lib/features/my_list/data/mapper/my_list_mapper.dart lib/features/my_list/presentation/pages/my_list_page.dart test/features/my_list/my_list_mapper_test.dart
git commit -m "feat: pass play history progress into player"
```

---

### Task 4: Remote Progress As Safe Correction

**Files:**
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Test: `test/features/player/player_page_initial_intent_test.dart`

**Interfaces:**
- Consumes: `_startupRemoteWatchProgress`
- Produces: safe remote correction behavior that does not block first frame and does not rewind active playback to stale progress.

- [ ] **Step 1: Write failing tests**

Add tests for:

1. Initial local/list progress starts playback without waiting for remote progress.
2. Remote progress for same item applies only if playback has not advanced beyond remote position.
3. Remote progress for another item does not switch episode after playback has started.

```dart
test('remote progress does not override advanced local playback', () async {
  final decision = shouldApplyRemoteResumeCorrectionForTest(
    currentItemId: 'single:799:14327',
    currentPosition: const Duration(seconds: 50),
    hasFirstFrame: true,
    remoteItemId: 'single:799:14327',
    remotePosition: const Duration(seconds: 35),
  );

  expect(decision, RemoteResumeCorrectionDecision.skipStale);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/player_page_initial_intent_test.dart`

Expected: FAIL until the decision helper exists.

- [ ] **Step 3: Extract correction decision helper**

Create a pure helper inside `player_page.dart` or a focused private file:

```dart
enum RemoteResumeCorrectionDecision { applySeek, switchBeforePlayback, skipStale }
```

Decision rules:

- Same item and current position <= remote position + 1s: `applySeek`
- Different item and playback not started: `switchBeforePlayback`
- Otherwise: `skipStale`

- [ ] **Step 4: Apply helper in `_applyStartupRemoteResumeProgress`**

Keep remote fetch asynchronous. Do not wait longer than the existing budget for first startup path. If remote is late, apply only through the helper.

Record timing:

- `remote resume correction applied`
- `remote resume correction skipped stale`
- `remote resume correction switched before playback`

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/player/player_page_initial_intent_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/presentation/pages/player_page.dart test/features/player/player_page_initial_intent_test.dart
git commit -m "feat: make remote progress a safe playback correction"
```

---

### Task 5: Prepared Hit Plus Resume Seek

**Files:**
- Modify: `lib/features/player/application/player_playback_controller.dart`
- Test: `test/features/player/player_playback_controller_test.dart`

**Interfaces:**
- Consumes: `PreparedPlaybackSession`
- Produces: prepared takeover remains preferred even when resume progress exists.

- [ ] **Step 1: Write failing test**

```dart
test('prepared hit is retained when pending resume progress exists', () async {
  final container = _createContainerWithPreparedSession();
  final controller = container.read(
    playerPlaybackControllerProvider('single:799:1').notifier,
  );
  controller.setPendingResumeProgress(
    PlaybackProgress(
      itemId: 'single:799:14328',
      position: const Duration(seconds: 35),
      duration: const Duration(seconds: 126),
      updatedAt: DateTime.now(),
    ),
  );

  await controller.playItem(_item(id: 'single:799:14328'));

  final report = controller.exportTimingReport();
  expect(report, contains('prepared hit next'));
  expect(report, contains('resume seek after prepared hit'));
  expect(report, isNot(contains('prepared session skipped for resume start')));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/player_playback_controller_test.dart --name "prepared hit is retained"`

Expected: FAIL because current behavior skips prepared when pending resume progress exists.

- [ ] **Step 3: Change takeover logic**

Replace the branch that disposes prepared on pending resume with:

1. Take prepared session.
2. Replace current session.
3. If resume progress can resume, seek after takeover.
4. Log `resume seek after prepared hit`.

Keep cold fallback open using `start: resumeStart`.

- [ ] **Step 4: Run targeted tests**

Run:

```bash
flutter test test/features/player/player_playback_controller_test.dart --name "prepared hit"
flutter test test/features/player/player_playback_controller_test.dart --name "resume"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/application/player_playback_controller.dart test/features/player/player_playback_controller_test.dart
git commit -m "fix: preserve prepared session hits with resume progress"
```

---

### Task 6: HLS Preload Budget Hardening

**Files:**
- Modify: `lib/features/player/data/hls_playlist_preloader.dart`
- Test: `test/features/player/hls_playlist_preloader_test.dart`

**Interfaces:**
- Consumes: `maxPreheatBytes`
- Produces: preloader stops before fetching another segment if the known or projected segment size would exceed the budget.

- [ ] **Step 1: Write failing test**

```dart
test('preloader does not fetch second segment after first segment reaches budget', () async {
  final client = RecordingHlsPlaylistHttpClient({
    Uri.parse('https://cdn.example.com/index.m3u8'): HlsPlaylistHttpResponse(
      statusCode: 200,
      body: '#EXTM3U\n#EXTINF:2,\nseg1.ts\n#EXTINF:2,\nseg2.ts\n',
    ),
    Uri.parse('https://cdn.example.com/seg1.ts'): HlsPlaylistHttpResponse(
      statusCode: 200,
      body: 'a' * 1200,
      contentLength: 1200,
    ),
    Uri.parse('https://cdn.example.com/seg2.ts'): HlsPlaylistHttpResponse(
      statusCode: 200,
      body: 'b' * 1200,
      contentLength: 1200,
    ),
  });
  final preloader = HlsPlaylistPreloader(
    client: client,
    maxPreheatBytes: 1200,
  );

  await preloader.prefetch('https://cdn.example.com/index.m3u8');

  expect(client.requestedUris, isNot(contains(Uri.parse('https://cdn.example.com/seg2.ts'))));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/hls_playlist_preloader_test.dart --name "does not fetch second segment"`

Expected: FAIL if second segment is fetched.

- [ ] **Step 3: Implement budget stop**

Before each segment fetch:

```dart
if (segmentBytesPreheated >= maxPreheatBytes) {
  diagnostics.add('segment preheat max bytes reached');
  break;
}
```

After each segment fetch, if bytes reached or exceeded budget, break before next segment. If response headers expose length before body in the future, skip over-budget segment before downloading it.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/player/hls_playlist_preloader_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/data/hls_playlist_preloader.dart test/features/player/hls_playlist_preloader_test.dart
git commit -m "fix: enforce hls preload byte budget"
```

---

### Task 7: Release-Device Timing Matrix

**Files:**
- Modify: `scripts/device_player_manual_scroll_test.sh`
- Modify: `docs/player/player-experience-architecture-plan.md`

**Interfaces:**
- Consumes: release APK built with `PLAYER_TIMING_LOGS=true`
- Produces: reproducible validation matrix for Home, watched reopen, My List, For You, swipe next, and swipe previous.

- [ ] **Step 1: Add scripted scenarios**

Extend the script with labels:

- `home_cold_entry`
- `home_watched_reopen`
- `my_list_history_entry`
- `for_you_first_entry`
- `for_you_swipe_next`
- `for_you_swipe_previous`
- `single_swipe_next`
- `single_swipe_previous`

- [ ] **Step 2: Add log extraction**

After logcat pull, extract timing lines matching:

```text
trace start|first frame received|prepared hit next|retained hit previous|window miss fallback open|resume seek|preload end|remote resume|local progress|list progress
```

- [ ] **Step 3: Run release build**

Run:

```bash
flutter build apk --release --dart-define=PLAYER_TIMING_LOGS=true
```

Expected: APKs generated under `build/app/outputs/flutter-apk/`.

- [ ] **Step 4: Install and run manual matrix**

Run:

```bash
adb install -r build/app/outputs/flutter-apk/app-haha-release.apk
scripts/device_player_manual_scroll_test.sh
```

Expected: script produces log, recording, and timing extracts.

- [ ] **Step 5: Document results**

Update `docs/player/player-experience-architecture-plan.md` with a small matrix:

```markdown
| Scenario | First frame | Window hit | Normal open | Resume source | Notes |
| --- | ---: | --- | --- | --- | --- |
| Home watched reopen |  |  |  | local/list/remote |  |
```

- [ ] **Step 6: Commit**

```bash
git add scripts/device_player_manual_scroll_test.sh docs/player/player-experience-architecture-plan.md
git commit -m "test: add player production timing matrix"
```

---

## Self-Review

**Spec coverage:** The plan covers watched reopen speed, list entry speed, vertical swipe smoothness, progress correctness, preload control, and production validation. HLS re-encoding/CDN work is intentionally outside client implementation but remains a release dependency for cold first-frame targets.

**Placeholder scan:** No task uses TBD/TODO/fill-in placeholders. Each task has files, interfaces, tests, implementation steps, and verification commands.

**Type consistency:** `InitialPlaybackIntent`, `InitialPlaybackProgress`, and `InitialPlaybackProgressSource` are introduced in Task 1 and reused consistently in later tasks. Remote correction helper names are scoped to Task 4 and can be private or test-visible.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-13-player-production-playback-experience.md`. Two execution options:

1. Subagent-Driven (recommended) - dispatch a fresh subagent per task, review between tasks, fast iteration.
2. Inline Execution - execute tasks in this session using executing-plans, batch execution with checkpoints.

Choose one before implementation.
