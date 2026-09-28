# Playback Experience Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make For You playback deterministic across feed prefetch, tab/lifecycle changes, normal-player handoff, and native-surface recovery through one session-scoped coordinator.

**Architecture:** Add a per-session `PlaybackExperienceCoordinator` that owns desired target, effective visibility, handoff ordering, and health classification. Existing feed, viewport, runtime, and playback controllers retain their current data, entitlement, and media responsibilities; AppShell and PlayerPage become event sources instead of issuing competing recovery commands.

**Tech Stack:** Flutter, Dart, Riverpod `NotifierProvider.family`, media_kit, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-28-playback-experience-coordinator-design.md`

## Global Constraints

- Keep `PlayerPlaybackController` as the only owner of media-kit sessions, HLS source opens, surface objects, and source-level retry.
- Do not add native player sessions, change iOS's two-session cap, replace media_kit, or enable the local HLS proxy.
- Feed prefetch may load data while hidden but must never open media while hidden.
- A start, resume, or recovery command must be idempotent for its target and command generation.
- Do not log signed media URLs, authorization values, or raw handoff contents; ticket ids are opaque diagnostics only.
- A stale feed, entitlement result, lifecycle event, or handoff return must not alter a newer target.
- Preserve current locked/unavailable behavior, playback progress persistence, analytics, preload traffic gating, and user-paused behavior.

## Review Focus

- Shell prefetch resolves before `PlayerPage` exists: the visible For You item must settle and start exactly once; Task 3 pins this integration path.
- User leaves For You while source resolution is pending: no later open may produce audio or attach a surface; Task 4 pins generation invalidation.
- Normal player returns after the user has refreshed or swiped For You: its stale ticket must be ignored; Task 5 pins ticket ordering.
- iOS receives a decoder frame but no native presentation callback: recovery must be bounded to one target/surface generation and retain the two-session cap; Task 6 pins this.
- A user-paused For You item becomes visible again: reattach the surface but do not autoplay; Task 4 pins this.

---

## File structure

- Create: `lib/features/player/application/playback_experience_state.dart` — immutable state, visibility, health, target, and handoff ticket value objects.
- Create: `lib/features/player/application/playback_experience_coordinator.dart` — serialized per-session event reducer and command issuer.
- Modify: `lib/features/player/application/player_feed_controller.dart` — expose a monotonic `revision` for feed replacement and refresh.
- Modify: `lib/features/player/application/for_you_playback_progress_controller.dart` — store ticketed active-process handoff snapshots instead of drama-id-only decision state.
- Modify: `lib/app/shell/app_shell.dart` — publish For You visibility intent; retain only data prefetch at shell level.
- Modify: `lib/features/player/presentation/pages/player_page.dart` — publish page, viewport, lifecycle, and route-handoff events; remove duplicated restoration queues after migration.
- Modify: `lib/features/player/application/player_runtime_coordinator.dart` — accept a coordinator-authorized settled target with generation checks.
- Modify: `lib/features/player/application/player_playback_controller.dart` — expose only needed, idempotent controller primitives and keep low-level source retry local.
- Create: `test/features/player/playback_experience_coordinator_test.dart` — state-machine and dependency-boundary tests.
- Modify: `test/features/player/player_feed_controller_test.dart` — feed revision semantics.
- Modify: `test/features/player/player_page_test.dart` — app-level For You, route return, and render behavior.
- Create: `test/app/app_shell_for_you_playback_test.dart` — shell-prefetch-before-page integration regression.

### Task 1: Define versioned playback-experience state

**Files:**

- Create: `lib/features/player/application/playback_experience_state.dart`
- Modify: `lib/features/player/application/player_feed_controller.dart`
- Test: `test/features/player/player_feed_controller_test.dart`
- Test: `test/features/player/playback_experience_coordinator_test.dart`

**Interfaces:**

- Produces `PlaybackExperienceVisibility`, `PlaybackExperienceHealth`, `PlaybackExperienceTarget`, `ForYouHandoffTicket`, and immutable `PlaybackExperienceState`.
- Adds `int revision` to `PlayerFeedState`; it increments only when a new first page replaces or refreshes feed content, never on loading-more or UI index changes.
- Later tasks consume target identity as `(itemId, episodeId, feedRevision)` and ticket identity as `ticketId + revision`.

- [ ] **Step 1: Write failing feed revision tests**

```dart
test('For You first-page replacement increments the feed revision', () async {
  await controller.load(const PlayerFeedConfig.forYou());
  final first = container.read(provider).revision;

  await controller.refresh();

  expect(container.read(provider).revision, first + 1);
});

test('For You loading more keeps the current feed revision', () async {
  await controller.load(const PlayerFeedConfig.forYou());
  final revision = container.read(provider).revision;

  await controller.loadMore();

  expect(container.read(provider).revision, revision);
});
```

- [ ] **Step 2: Run the feed revision tests to verify they fail**

Run: `flutter test --no-pub test/features/player/player_feed_controller_test.dart --plain-name "For You first-page replacement increments the feed revision"`

Expected: FAIL because `PlayerFeedState.revision` does not exist.

- [ ] **Step 3: Write failing immutable state tests**

```dart
test('experience target equality includes feed revision and episode', () {
  expect(
    const PlaybackExperienceTarget(itemId: 'a', episodeId: '1', feedRevision: 1),
    isNot(
      const PlaybackExperienceTarget(itemId: 'a', episodeId: '1', feedRevision: 2),
    ),
  );
});
```

- [ ] **Step 4: Implement the state values and feed revision**

Implement value equality and `copyWith` in `playback_experience_state.dart`.
Increment `PlayerFeedState.revision` when `load` commits a new first-page
result, including `forceRefresh`; preserve it for index changes and `loadMore`.

- [ ] **Step 5: Run focused state tests**

Run: `flutter test --no-pub test/features/player/player_feed_controller_test.dart test/features/player/playback_experience_coordinator_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/application/playback_experience_state.dart lib/features/player/application/player_feed_controller.dart test/features/player/player_feed_controller_test.dart test/features/player/playback_experience_coordinator_test.dart
git commit -m "feat(player): add versioned playback experience state"
```

### Task 2: Add the session-scoped coordinator and deterministic bootstrap

**Files:**

- Create: `lib/features/player/application/playback_experience_coordinator.dart`
- Test: `test/features/player/playback_experience_coordinator_test.dart`

**Interfaces:**

- Produces `playbackExperienceCoordinatorProvider`, a `NotifierProvider.family<PlaybackExperienceCoordinator, PlaybackExperienceState, String>`.
- `void setVisibility(PlaybackExperienceVisibility visibility)` records external visibility intent.
- `Future<void> synchronize()` derives the current target from feed/viewport/playback state and issues at most one command per target generation.
- `Future<void> onViewportSettled({required PlayerFeedItem item, required int index, required int feedRevision})` accepts only the current target.
- For the For You key, a visible feed with no matching settled viewport calls `PlayerViewportController.initialize` before the normal settled runtime path.

- [ ] **Step 1: Write failing bootstrap tests**

```dart
test('visible prefetched For You feed initializes and starts its first target', () async {
  seedFeed(item: itemA, revision: 3); // Page has not been built when this completes.
  coordinator.setVisibility(PlaybackExperienceVisibility.visible);
  await coordinator.synchronize();

  expect(viewport.initializeCalls, [(index: 0, itemId: itemA.id)]);
  expect(runtime.settledCalls.single.item.id, itemA.id);
});

test('hidden prefetched For You feed initializes no media target', () async {
  seedFeed(item: itemA, revision: 3);
  coordinator.setVisibility(PlaybackExperienceVisibility.hidden);
  await coordinator.synchronize();

  expect(runtime.settledCalls, isEmpty);
  expect(playback.openedItems, isEmpty);
});
```

- [ ] **Step 2: Run the bootstrap tests to verify they fail**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart --plain-name "visible prefetched For You feed initializes and starts its first target"`

Expected: FAIL because the coordinator/provider does not exist.

- [ ] **Step 3: Implement `PlaybackExperienceCoordinator`**

Use one serialized internal operation queue and monotonically incrementing
`commandGeneration`. Read feed/viewport/playback providers only at command
execution time. For a visible For You feed, initialize a missing or mismatched
viewport with the current feed revision, then use the existing settled runtime
path; do not call `PlayerPlaybackController.playItem` directly from bootstrap.

- [ ] **Step 4: Add idempotence test and implement it**

```dart
test('repeated synchronize for one healthy target issues no second start', () async {
  await coordinator.synchronize();
  markHealthy(itemA, revision: 3);
  await coordinator.synchronize();

  expect(runtime.settledCalls, hasLength(1));
});
```

- [ ] **Step 5: Run focused coordinator tests**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/application/playback_experience_coordinator.dart lib/features/player/application/playback_experience_state.dart test/features/player/playback_experience_coordinator_test.dart
git commit -m "feat(player): coordinate For You playback targets"
```

### Task 3: Bridge Shell prefetch and page viewport events through the coordinator

**Files:**

- Modify: `lib/app/shell/app_shell.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Modify: `lib/features/player/application/player_runtime_coordinator.dart`
- Create: `test/app/app_shell_for_you_playback_test.dart`
- Modify: `test/features/player/player_page_test.dart`

**Interfaces:**

- AppShell calls `setVisibility(hidden|visible)` and `synchronize()` through the coordinator; it no longer calls playback visibility APIs directly.
- PlayerPage reports page attachment, settled PageView target, and route coverage to the coordinator; it no longer owns initial-feed replay logic.
- `PlayerRuntimeCoordinator.onViewportSettled` receives a target only after coordinator validation of item id, index, and feed revision.

- [ ] **Step 1: Write the shell-preload integration regression**

```dart
testWidgets('shell prefetch completing before For You page construction starts playback on tab entry', (tester) async {
  final feed = Completer<PlayerFeedPage>();
  await pumpShellAtHomeWithForYouFeed(feed.future);
  feed.complete(pageWith(itemA));
  await tester.pump();

  await selectForYouTab(tester);

  expect(fakePlayback.openedItems, [itemA.id]);
  expect(find.byKey(const ValueKey('playback_loading_overlay')), findsOneWidget);
});
```

- [ ] **Step 2: Run the integration test to verify the existing race fails**

Run: `flutter test --no-pub test/app/app_shell_for_you_playback_test.dart --plain-name "shell prefetch completing before For You page construction starts playback on tab entry"`

Expected: FAIL because current shell prefetch completes without a viewport initialization/start command.

- [ ] **Step 3: Route shell/page events through the coordinator**

Keep AppShell's feed HTTP prefetch. Replace its direct
`markHiddenForVisibility`, `pauseForVisibility`, and
`resumeAfterCompetingPlayer` calls with coordinator visibility events. Replace
PlayerPage's `_hasObservedInitialForYouFeedItem`, initial replay listener, and
page-level restore queue with attachment/settled/route-coverage events. Do not
change PageView gesture behavior or entitlement UI.

- [ ] **Step 4: Add and implement stale target validation**

```dart
test('a feed refresh invalidates a queued start for its prior first item', () async {
  coordinator.setVisibility(PlaybackExperienceVisibility.visible);
  seedFeed(item: itemA, revision: 1);
  final pending = coordinator.synchronize();
  seedFeed(item: itemB, revision: 2);
  await pending;

  expect(fakePlayback.openedItems, isNot(contains(itemA.id)));
});
```

- [ ] **Step 5: Run integration and page regression tests**

Run: `flutter test --no-pub test/app/app_shell_for_you_playback_test.dart test/features/player/player_page_test.dart`

Expected: targeted new tests PASS. Record any unrelated existing widget-test failures separately.

- [ ] **Step 6: Commit**

```bash
git add lib/app/shell/app_shell.dart lib/features/player/presentation/pages/player_page.dart lib/features/player/application/player_runtime_coordinator.dart test/app/app_shell_for_you_playback_test.dart test/features/player/player_page_test.dart test/features/player/playback_experience_coordinator_test.dart
git commit -m "refactor(player): route For You startup through coordinator"
```

### Task 4: Centralize visibility and lifecycle ownership

**Files:**

- Modify: `lib/app/shell/app_shell.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Modify: `lib/features/player/application/playback_experience_coordinator.dart`
- Modify: `test/features/player/playback_experience_coordinator_test.dart`
- Modify: `test/features/player/player_page_test.dart`

**Interfaces:**

- `void setRouteCovered(bool covered)` and `void setAppLifecycle(AppLifecycleState lifecycle)` update effective visibility.
- `Future<void> synchronize()` pauses/releases or restores through existing playback-controller primitives only after the derived effective visibility changes.
- The coordinator distinguishes a user-paused target from a visibility-paused target.

- [ ] **Step 1: Write failing visibility tests**

```dart
test('tab exit during opening invalidates the pending visible target', () async {
  startOpening(itemA);
  coordinator.setVisibility(PlaybackExperienceVisibility.hidden);
  await coordinator.synchronize();
  completeOpen(itemA);

  expect(fakePlayback.playCalls, isEmpty);
});

test('user-paused target reattaches when visible without autoplay', () async {
  seedPausedUserTarget(itemA);
  coordinator.setVisibility(PlaybackExperienceVisibility.visible);
  await coordinator.synchronize();

  expect(fakePlayback.restoreSurfaceCalls, 1);
  expect(fakePlayback.playCalls, isEmpty);
});
```

- [ ] **Step 2: Run the visibility tests to verify they fail**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart --plain-name "tab exit during opening invalidates the pending visible target"`

Expected: FAIL because visibility remains split across AppShell and PlayerPage.

- [ ] **Step 3: Implement effective-visibility reduction**

Derive `visible` only when tab visibility, page attachment, route coverage, and
app lifecycle all allow it. On a hidden generation, invalidate pending commands
before calling existing pause/detach APIs. On a visible generation, choose
restore-surface or ensure-target based on user-pause state; never infer user
intent from `paused` alone.

- [ ] **Step 4: Run focused lifecycle tests**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart test/features/player/player_page_test.dart`

Expected: PASS for the new lifecycle cases.

- [ ] **Step 5: Commit**

```bash
git add lib/app/shell/app_shell.dart lib/features/player/presentation/pages/player_page.dart lib/features/player/application/playback_experience_coordinator.dart test/features/player/playback_experience_coordinator_test.dart test/features/player/player_page_test.dart
git commit -m "refactor(player): centralize For You visibility recovery"
```

### Task 5: Add ticketed normal-player handoff and progress synchronization

**Files:**

- Modify: `lib/features/player/application/playback_experience_state.dart`
- Modify: `lib/features/player/application/for_you_playback_progress_controller.dart`
- Modify: `lib/features/player/application/playback_experience_coordinator.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Modify: `test/features/player/playback_experience_coordinator_test.dart`
- Modify: `test/features/player/player_page_test.dart`

**Interfaces:**

- `ForYouHandoffTicket beginForYouHandoff({required PlaybackExperienceTarget target, required Duration position, required Duration duration})` returns an opaque current ticket.
- `Future<void> completeForYouHandoff({required ForYouHandoffTicket ticket, required ForYouPlaybackSnapshot snapshot})` ignores a non-current ticket and otherwise updates the matching feed item before one authoritative playback synchronization.
- The process-local progress store indexes snapshots by ticket id and retains current lookup by drama only as a non-authoritative display convenience.

- [ ] **Step 1: Write failing stale-return test**

```dart
test('stale ordinary-player return cannot overwrite a newer For You target', () async {
  final first = coordinator.beginForYouHandoff(target: targetA, position: Duration.zero, duration: duration);
  final second = coordinator.beginForYouHandoff(target: targetB, position: Duration.zero, duration: duration);

  await coordinator.completeForYouHandoff(ticket: first, snapshot: snapshotFor(targetA, seconds: 40));

  expect(feed.currentItem!.id, targetB.itemId);
  expect(playback.externalSynchronizations, isEmpty);
  expect(coordinator.state.handoff.ticketId, second.ticketId);
});
```

- [ ] **Step 2: Run the stale-return test to verify it fails**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart --plain-name "stale ordinary-player return cannot overwrite a newer For You target"`

Expected: FAIL because existing return synchronization is page-local and keyed by drama snapshot.

- [ ] **Step 3: Implement ticket lifecycle and atomic return application**

Create tickets at the For You-to-normal-player boundary. Suppress For You while
the ticket is foregrounded by the normal player. On a current return, validate
ticket target/feed revision, update the origin item episode, choose its
position, then request one visible target synchronization. Keep iOS native
recreation decision in the coordinator policy; keep session creation inside the
playback controller.

- [ ] **Step 4: Add and implement current-return regression**

```dart
test('current ordinary-player return updates its origin item and resumes once', () async {
  final ticket = coordinator.beginForYouHandoff(target: targetA, position: Duration(seconds: 5), duration: duration);
  await coordinator.completeForYouHandoff(ticket: ticket, snapshot: snapshotFor(targetA, seconds: 37, episode: episode2));

  expect(feed.itemById(targetA.itemId)!.episode.id, episode2.id);
  expect(playback.externalSynchronizations.single.position, const Duration(seconds: 37));
});
```

- [ ] **Step 5: Run focused handoff tests**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart test/features/player/player_page_test.dart test/features/player/player_playback_controller_test.dart`

Expected: PASS for ticket ordering and existing route-handoff cases.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/application/playback_experience_state.dart lib/features/player/application/for_you_playback_progress_controller.dart lib/features/player/application/playback_experience_coordinator.dart lib/features/player/presentation/pages/player_page.dart test/features/player/playback_experience_coordinator_test.dart test/features/player/player_page_test.dart
git commit -m "feat(player): make For You handoff return versioned"
```

### Task 6: Centralize health classification and bounded native recovery

**Files:**

- Modify: `lib/features/player/application/playback_experience_coordinator.dart`
- Modify: `lib/features/player/application/player_playback_controller.dart`
- Modify: `lib/features/player/presentation/widgets/player_playback_layer.dart`
- Modify: `test/features/player/playback_experience_coordinator_test.dart`
- Modify: `test/features/player/player_playback_controller_test.dart`
- Modify: `test/features/player/player_page_test.dart`

**Interfaces:**

- Coordinator observes `PlayerPlaybackState` for its current target and exposes `PlaybackExperienceHealth`.
- `void reportSurfaceAttached({required String itemId, required VideoController controller})` and existing first-frame presentation callback supply attachment evidence.
- `Future<void> recoverVisibleTarget({required PlaybackRecoveryCause cause, required int commandGeneration})` is coordinator-owned and invokes existing playback primitives at most once per `(target, surface epoch, cause)`.

- [ ] **Step 1: Write failing health classification tests**

```dart
test('visible settled item without source is classified notStarted and started once', () async {
  seedVisibleSettledTarget(targetA, playback: idleWithoutSource);
  await coordinator.synchronize();

  expect(coordinator.state.health, PlaybackExperienceHealth.opening);
  expect(runtime.settledCalls, hasLength(1));
});

test('decoded frame without surface presentation recovers once per surface epoch', () async {
  seedVisibleSettledTarget(targetA, playback: decodedNotPresented);
  await advancePastPresentationTimeout();
  await advancePastPresentationTimeout();

  expect(fakePlayback.recreateCalls, 1);
});
```

- [ ] **Step 2: Run the health tests to verify they fail**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart --plain-name "decoded frame without surface presentation recovers once per surface epoch"`

Expected: FAIL because health and route-level recovery are split between page and playback controller.

- [ ] **Step 3: Implement classified health reconciliation**

Observe only the current desired target. Cancel health timers on target,
visibility, controller, or surface-attachment generation changes. Reuse existing
first-frame/source retry behavior in `PlayerPlaybackController`; move only
visible-route/session rebuild choice into the coordinator. Keep loading overlay
visible until `hasRenderedFirstFrame` is true.

- [ ] **Step 4: Add iOS policy regression and implement it**

```dart
test('iOS surface recovery does not create a third native session', () async {
  configurePlatform(TargetPlatform.iOS);
  seedDecodedNotPresented(targetA);
  await advancePastPresentationTimeout();

  expect(fakeSessionFactory.maxLiveSessions, lessThanOrEqualTo(2));
});
```

- [ ] **Step 5: Run focused health tests**

Run: `flutter test --no-pub test/features/player/playback_experience_coordinator_test.dart test/features/player/player_playback_controller_test.dart test/features/player/player_page_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/application/playback_experience_coordinator.dart lib/features/player/application/player_playback_controller.dart lib/features/player/presentation/widgets/player_playback_layer.dart test/features/player/playback_experience_coordinator_test.dart test/features/player/player_playback_controller_test.dart test/features/player/player_page_test.dart
git commit -m "refactor(player): classify and recover visible playback health"
```

### Task 7: Remove duplicate recovery paths and complete regression validation

**Files:**

- Modify: `lib/app/shell/app_shell.dart`
- Modify: `lib/features/player/presentation/pages/player_page.dart`
- Modify: `lib/features/player/application/player_playback_controller.dart`
- Modify: `docs/player/player-experience-architecture-plan.md`
- Modify: `docs/release/release-seal-checklist.md`
- Test: `test/app/app_shell_for_you_playback_test.dart`
- Test: `test/features/player/playback_experience_coordinator_test.dart`
- Test: existing player test suites

**Interfaces:**

- Produces one coordinator-owned For You restore path; legacy page helper flags, restore queues, and shell direct visibility calls are removed.
- Produces release timing dimensions for event, target/feed revision, opaque ticket, command generation, health state, source open, decoder first frame, and presented first frame.

- [ ] **Step 1: Write failing no-duplicate-command regression**

```dart
testWidgets('tab, lifecycle, and route-return events for one target issue one authoritative restore', (tester) async {
  await enterForYouAndStart(itemA);
  await emitInactiveThenResumed();
  await completeCurrentHandoffReturn();

  expect(fakePlayback.authoritativeRestoreCountFor(itemA.id), 1);
});
```

- [ ] **Step 2: Run the regression to verify it fails before legacy removal**

Run: `flutter test --no-pub test/app/app_shell_for_you_playback_test.dart test/features/player/playback_experience_coordinator_test.dart --plain-name "tab, lifecycle, and route-return events for one target issue one authoritative restore"`

Expected: FAIL if bridge and legacy paths both issue commands.

- [ ] **Step 3: Remove legacy direct restoration paths**

Delete only code superseded by coordinator events: PlayerPage initial-feed
replay helpers, page-local For You restore operation queue, and AppShell direct
playback visibility commands. Retain lower-level playback source retry and
session safety code. Update timing and release documentation with the new
diagnostic dimensions.

- [ ] **Step 4: Run static analysis and focused suite**

Run: `dart format lib/app/shell/app_shell.dart lib/features/player/application lib/features/player/presentation/pages/player_page.dart test/app/app_shell_for_you_playback_test.dart test/features/player && flutter analyze --no-pub lib/app/shell/app_shell.dart lib/features/player test/app/app_shell_for_you_playback_test.dart && flutter test --no-pub test/app/app_shell_for_you_playback_test.dart test/features/player/playback_experience_coordinator_test.dart test/features/player/player_feed_controller_test.dart test/features/player/player_playback_controller_test.dart test/features/player/player_page_test.dart`

Expected: formatting clean; analysis clean; report any pre-existing full-widget-suite failures separately rather than masking them.

- [ ] **Step 5: Perform device matrix before speed work**

Run iOS and Android with `PLAYER_TIMING_LOGS=true` and record: Home → For You,
cold For You entry, leave/return while opening, normal-player handoff/return,
background/foreground, user-paused return, and next/previous swipe. Verify one
target-settled and one play command per expected target, no background audio,
and no black idle state after a visible feed completes.

- [ ] **Step 6: Commit**

```bash
git add lib/app/shell/app_shell.dart lib/features/player/presentation/pages/player_page.dart lib/features/player/application/player_playback_controller.dart docs/player/player-experience-architecture-plan.md docs/release/release-seal-checklist.md test/app/app_shell_for_you_playback_test.dart test/features/player
git commit -m "refactor(player): unify For You playback recovery"
```

## Follow-on speed program

Start only after Task 7's device matrix is green. Use coordinator timing to
separate target-settled delay from source resolve, HLS playlist/segment,
media-open, decoder-first-frame, and presentation delay. Optimize the proven
slowest boundary in this order: rendition/startup source policy, active-player
preload policy, HLS segment/keyframe/CDN contract, then platform decoder
configuration. Do not reintroduce state-machine recovery patches as a
performance experiment.
