# Playback Experience Coordinator Design

## Status and scope

This design replaces fragmented For You playback startup and restoration
decisions with one per-session coordinator. It covers For You cold entry, tab
visibility, lifecycle transitions, normal-player handoff/return, feed refresh,
and native video-surface health. It does not replace `media_kit`, change the
HLS/CDN contract, increase the native session window, or add a local proxy.

The immediate production symptom is a For You page that renders feed chrome
after a shell-initiated prefetch but remains `idle` with no source, audio, or
video. The underlying issue is not a slow decoder: the feed completed without
creating a canonical viewport target, so no playback command was ever issued.

## Problem statement

For You currently has several independent owners of parts of one user-visible
state:

- `AppShell` preloads the feed and pauses/resumes For You on tab changes.
- `PlayerPage` initializes a viewport after its own load, listens for tab and
  lifecycle changes, handles route return, and issues replay/recovery calls.
- `PlayerViewportController` stores the settled target needed to start runtime
  work.
- `PlayerFeedEngine` and `PlayerRuntimeCoordinator` perform settled access,
  playback, preload, and overlay work.
- `PlayerPlaybackController` owns media sessions, source/open/play state,
  surface lifecycle, and low-level native recovery.
- `ForYouPlaybackProgressController` holds process-local progress for route
  handoff.

These owners are individually reasonable, but no owner has the complete
question: "while this For You page is foregrounded, which item must be playing
and has it visibly reached that state?" Asynchronous feed completion can
therefore happen after the page's load continuation has already returned. A
later `replaySettled()` has no effect when the viewport was never initialized.

## Goals

1. A visible playable For You target is either opening, visibly playing, or
   represented by an explicit classified state; it must never silently remain
   idle after the feed is ready.
2. Feed preload may happen before the page is built without changing the
   result of initial playback.
3. Exactly one coordinator decides whether to start, resume, recreate, or
   remain paused for the For You session.
4. A return from the ordinary player updates only the matching For You handoff
   and cannot overwrite a newer swipe, refresh, or handoff.
5. Audio/video/surface failures are classified without attempting unreliable
   pixel-level black-frame detection.
6. Existing playback performance investments remain intact: direct HLS,
   rendition policy, HLS preload, session window, and native session caps.
7. The migration is observable, testable, and reversible by feature boundary.

## Non-goals

- This change does not make an HLS segment download, CDN response, or decoder
  intrinsically faster.
- It does not retain extra native decoders on iOS or change its two-session
  safety cap.
- It does not use screenshots or pixel sampling to classify a black video.
- It does not move entitlement rules, watch reward policy, or UI chrome state
  into the coordinator.

## Proposed ownership model

Introduce `PlaybackExperienceCoordinator`, a Riverpod family scoped by
playback session key. For You uses the persistent `for-you-tab` key; a normal
player has its existing per-route key. The coordinator owns desired playback
state and orchestration only. It does not own media resources or render
widgets.

| Layer | Owns | Must not own |
| --- | --- | --- |
| AppShell | navigation intent, feed prefetch request, app-shell tab signal | direct player pause/resume/rebuild commands |
| PlayerPage | rendering, gestures, route presentation, reporting user intent | restoration queues, media-health decisions, feed-to-viewport bootstrap |
| Feed controller | feed data, immutable feed revision, current index | media/session state |
| Viewport controller | candidate and settled visual target | playback recovery policy |
| Experience coordinator | desired target, visibility/route ownership, event ordering, health classification, idempotent commands | decoder/player object, HLS HTTP operations, widgets |
| Runtime coordinator | access decision, paywall state, play command for an allowed settled item | shell/lifecycle/route sequencing |
| Playback controller | open/play/pause/seek/session window/native surface and media errors | deciding whether a For You route should be foregrounded |

The coordinator is the only component allowed to translate the following
events into a restore/start decision: feed ready, tab visible, app resumed,
ordinary-player return, refresh completion, and media-health timeout.

## State model

The coordinator exposes immutable state, rather than page-local boolean flags.

```text
PlaybackExperienceState
  visibility: hidden | visible | coveredByRoute | backgrounded
  content: noFeed | feedLoading | targetUnsettled | targetSettled(item, revision)
  access: unknown | playable | blocked | unavailable
  handoff: none | outgoing(ticket) | returning(ticket) | superseded
  playback: idle | opening | decoding | awaitingPresentation | healthy | failed
  desiredTarget: itemId + episodeId + optional position + targetRevision
  commandGeneration: monotonically increasing
```

The coordinator derives health from existing trustworthy signals:

| Condition | Classification | Action |
| --- | --- | --- |
| Visible, playable settled target; controller has no source | `idle` | issue one start command |
| Source is opening or buffering before first decoder frame | `opening` | retain loading state; do not rebuild yet |
| Position/playing advances without decoder first frame beyond bounded timeout | `decoding` failure | use existing media recovery policy once |
| Decoder first frame exists but native surface has not presented it in a bounded attached-surface interval | `awaitingPresentation` failure | recreate surface/session once where platform policy permits |
| Rendered first frame for desired target | `healthy` | enable normal preload and progress reporting |
| Access is blocked/unavailable or the route is hidden | non-playing terminal state | never auto-open media |

`hasFirstFrame` is decoder evidence and `hasRenderedFirstFrame` is native
surface presentation evidence. Neither claims to inspect actual pixel content;
they are sufficient to distinguish "not started", "not decoded", and "not
presented" without costly or unreliable frame capture.

## Event and command flow

All external transitions are events. Events are stamped with a session-local
generation and are serialized by the coordinator. An obsolete event cannot
start an old target after a swipe, refresh, navigation change, or route return.

```text
Shell feed prefetch ─┐
Feed completion ─────┤
Tab/lifecycle state ─┼─> Experience coordinator ─> ensure settled target
PageView gesture ────┤                              -> entitlement/runtime
Route handoff ───────┤                              -> playback command
Native playback state┘                              -> health / recovery
```

### Cold For You entry

1. AppShell may prefetch a For You feed while Home is visible.
2. Feed completion increments a feed revision and publishes its first current
   item. It does not create a media session.
3. When the tab becomes visible, the coordinator selects the current item,
   initializes the viewport if it has no settled item for the same feed
   revision, and waits for the normal settled runtime path.
4. The runtime evaluates access and calls the playback controller exactly once
   for an allowed target.
5. The coordinator observes first-frame/presentation state and leaves loading
   visible until presentation succeeds.

The order is deterministic whether the feed completes before or after
`PlayerPage` builds. This removes the current load-reuse race.

### Tab and app lifecycle transitions

AppShell publishes visibility intent only. PlayerPage publishes route coverage
and Flutter lifecycle events only. The coordinator combines them into one
effective visibility state and commands the playback controller:

- hidden/backgrounded: invalidate pending start generation, pause, detach or
  release according to existing platform policy;
- visible with a settled allowed target: ensure that target is playing;
- visible with a user-paused target: restore the surface but do not autoplay;
- visible while an ordinary player owns the handoff: remain suppressed.

This eliminates competing direct calls from AppShell and PlayerPage to
`pauseForVisibility`, `resumeAfterCompetingPlayer`, and replay helpers.

### Ordinary player handoff and return

Replace the drama-id-only implicit handoff with a `ForYouHandoffTicket`:

- unique id;
- origin feed item id and feed revision;
- target drama/episode;
- latest position/duration;
- monotonically increasing revision;
- ownership state: outgoing, foregrounded-by-normal-player, returned,
  superseded.

Before the normal player opens, the coordinator records the ticket and moves
For You to `coveredByRoute`; the playback controller releases/retains only as
the platform policy requires. While covered, tab and lifecycle events cannot
restart For You.

On return, the coordinator accepts a snapshot only if its ticket is current.
It updates the original feed item episode and position atomically, selects that
item as the desired target, recreates the native session only when required by
the native/surface health policy, and sends one authoritative seek/open/play
command. A stale return is recorded and ignored.

Server watch progress remains the cold-start authority. The handoff ticket is
an in-memory ordering mechanism for the active process only.

## Data synchronization rules

1. Feed items carry a feed revision. Refresh/replacement increments it.
2. A viewport target is valid only when its item id and feed revision match the
   current feed.
3. A handoff return may modify an item only when its ticket and origin item are
   still current. It cannot select an item by drama id alone.
4. Playback progress is accepted only for the current playback generation and
   desired target. Older position callbacks may update analytics persistence
   only when explicitly safe; they cannot update UI target state.
5. Entitlement is evaluated after target settlement. A result is ignored when
   target generation changed during the asynchronous evaluation.
6. Preload results are hints. They never establish playback state and cannot
   bypass visibility, access, or target validation.

## Performance implications

The coordinator improves perceived startup and switching time by eliminating
waiting for a tap, duplicate source opens, and stale recovery/rebuild work. It
does not shorten CDN or decoder latency by itself.

Performance protections:

- no hidden For You media session is opened merely because the feed prefetched;
- no additional iOS decoder is retained;
- visible target commands are idempotent per target generation;
- HLS preload stays below the coordinator and retains its current traffic
  gate/cancellation policy;
- health timers run only for a visible desired target and are cancelled on
  every target/visibility generation change;
- all timing traces include event, target id, feed revision, ticket id (opaque),
  command generation, and terminal health state; never raw signed URLs.

## Migration plan

### Phase A: establish observable state without changing media policy

- Add coordinator state and event logging.
- Have AppShell and PlayerPage publish intent events in parallel with existing
  behavior.
- Add integration tests for shell prefetch finishing before page creation.
- Verify device logs show one canonical target and one start command.

### Phase B: move For You bootstrap and visibility ownership

- Move feed-ready-to-viewport initialization into the coordinator.
- Remove PlayerPage's initial feed replay helper and page-local restore queue.
- Move AppShell direct playback visibility commands behind coordinator events.
- Keep `PlayerRuntimeCoordinator` and `PlayerPlaybackController` interfaces
  stable while proving behavioral parity.

### Phase C: move handoff and progress synchronization

- Introduce ticketed handoff state.
- Move normal-player return synchronization from page callbacks to the
  coordinator.
- Remove drama-id-only replacement as the decision key; retain it only as a
  presentation lookup when validated by the ticket.

### Phase D: centralize health recovery

- Route first-frame and presentation signals to coordinator health state.
- Keep low-level transport/source retry inside `PlayerPlaybackController`.
- Move only route/visibility/native-session recovery decisions to the
  coordinator, with one recovery per target/surface generation.

### Phase E: remove bridge code and tune playback speed separately

- Delete duplicate page/shell recovery paths after parity tests pass.
- Use reliable traces to identify first-frame bottlenecks.
- Evaluate rendition, preload, HLS first segment, CDN, and encoding changes as
  a separate performance program.

Each phase is independently releasable and can be rolled back by retaining the
previous event bridge, not by switching media source strategy.

## Acceptance and regression matrix

Automated tests must cover:

- feed completion before page construction and after page construction;
- visible feed completion initializes a settled target and reaches runtime;
- hidden feed completion opens no media;
- tab switch during source resolution prevents audio/video start;
- background/foreground preserves user pause but restores an allowed active
  target;
- refresh or swipe invalidates stale start/recovery work;
- normal-player handoff return updates only its current ticket;
- stale handoff return cannot overwrite a later swipe/refresh/handoff;
- iOS native session recreation follows its two-session policy;
- decoder-first-frame and surface-presented-frame states produce the intended
  loading/recovery behavior;
- preload, locked, unavailable, watch-progress, and analytics behavior retain
  current guarantees.

Device validation must separately record iOS and Android results for: cold
For You entry, Home-to-For-You transition, tab leave/return while opening,
normal-player handoff/return, lifecycle interruption, swipe after recovery,
and a user-paused return. The timing report must distinguish target-settled,
play-command, source-open, first decoder frame, and first presented frame.

## Rejected alternatives

### Patch only viewport initialization

This fixes the current preload race but leaves three visibility owners and
multiple restoration queues. It does not prevent a different event ordering
from creating the next black screen.

### A black-screen detector service only

It can classify symptoms but cannot decide whether a source should have opened
in the first place. It would become a second recovery layer beside the page and
controller, increasing races.

### Move all playback logic into PlayerPage

This makes lifecycle, native resources, and data synchronization widget-bound;
it is less testable and conflicts with the persistent shell and route handoff.

### Replace the media stack or enable a local proxy

Neither addresses the proven missing-target issue. The direct HLS path remains
the current production strategy; source/CDN speed work proceeds only after
state correctness is established.
