# Unified Playback Session and First-Frame Design

## Purpose

Make the first visible video and every transition between For You and the
ordinary player use one deterministic playback path. The product outcome is
fast visible video, correct resume position, and no black screen caused by two
pages racing to control the same playback lifecycle.

This design extends the existing Playback Experience Coordinator design. That
coordinator remains the owner of For You target/visibility ordering; this
document defines the shared session, source, progress, and first-frame contract
used by both player presentations.

## Scope and success criteria

Included flows:

- cold app launch to the first For You video;
- Home to For You;
- For You to ordinary player;
- ordinary player back to For You;
- ordinary-player direct entry and episode changes;
- For You swipe to the next item.

For You and ordinary player retain separate page chrome, feed behavior, access
UI, and analytics page names. They must not retain separate implementations of
source resolution, decoder ownership, HLS scheduling, resume, or first-frame
recovery.

Success criteria:

- a return restores the intended episode and position with no more than 500 ms
  error;
- a stale route/lifecycle callback cannot open a source or change a newer
  target;
- current video traffic cannot be delayed by speculative preload traffic;
- all launch and transition latency can be attributed to one of: target ready,
  source ready, media open, seek verified, decoder frame, or presented frame;
- implementation preserves iOS native-session safety limits.

## Observed baseline

The supplied iOS trace shows both correctness and performance failures on the
same flow:

- For You first source resolution takes about 1.8 seconds, then first presented
  frame arrives at about 14.9 seconds.
- Startup preload spent about 8.9 seconds and 2.6 MB on a different drama than
  the first visible For You target, so the actual visible target is a preload
  miss.
- The normal player exits around 27.7 seconds, but the returning For You
  session emits a 0-second startup progress report and reaches first frame only
  about 4.9 seconds after return.
- The test launch explicitly disables the local HLS proxy. HTTP prefetch must
  therefore not be assumed to be reusable by the media engine; it is only a
  network hint until an end-to-end shared cache proves otherwise.

The Facebook/Firebase offline warnings are unrelated to the player trace and
must not be treated as playback root cause.

## Architecture

```text
For You page ───────┐
Ordinary player ────┼── user intent ──> PlaybackSessionCoordinator
Home/app shell ─────┘                         │
                                              ├─ Target and handoff state
                                              ├─ Source resolver
                                              ├─ Native session owner
                                              ├─ HLS traffic scheduler
                                              ├─ Progress store
                                              └─ first-frame state machine
```

`PlaybackSessionCoordinator` is session-scoped and serializes commands for a
single foreground media target. It exposes a single immutable
`PlaybackIntent`:

```text
PlaybackIntent(
  requestId, owner, itemId, dramaId, episodeId, feedRevision,
  resumePosition, autoplay, qualityMode, priority
)
```

`owner` is a presentation concern (`forYou` or `ordinary`), not a media
implementation split. `requestId` and `feedRevision` reject stale work. The
existing `PlayerPlaybackController` remains the only owner of media_kit/native
objects; the new coordinator calls explicit idempotent primitives rather than
letting pages call `playItem`, recovery, pause, and seek independently.

## One playback command pipeline

Every playable entry uses this state machine:

```text
intent accepted
  -> cancel/demote obsolete background work
  -> resolve source at foreground priority
  -> acquire or recreate allowed native session
  -> open paused with resume target
  -> wait until media is seekable
  -> authoritative seek once
  -> verify reported position
  -> play
  -> decoder frame
  -> presented frame
  -> enable next-item preload
```

The coordinator can skip only work already proven valid for the same
`requestId`, source identity, and native surface. It must never skip seek
verification merely because a state object already has a non-null source.

On a route return, the handoff snapshot is accepted atomically only when its
ticket matches the visible target. The returned position is passed into the
pipeline before opening. If the platform needs a fresh native decoder, it opens
paused, waits for seekability, seeks once, confirms the resulting position, and
only then plays. It must not open at zero and launch a competing async seek.

## HLS and first-frame policy

The traffic scheduler has four priority tiers:

1. foreground source manifest, rendition playlist, required init data, and
   first playable segment;
2. accepted handoff/return target;
3. immediate next episode/item after a presented first frame;
4. Home/startup candidate preload.

Higher tiers cancel or suspend lower tiers. A first visible target selected
from the feed replaces any stale Home candidate immediately. A network-only
preload is recorded as a hint, not a cache hit, unless it shares the exact
media-engine cache path.

For auto quality, select a conservative 540p or 720p rendition for the first
frame. Permit adaptive promotion only after a short stable playback interval.
Manual quality selection remains authoritative in the ordinary player. Do not
preload 1080p before a visible first frame.

The player must either provide a verified shared local proxy/cache to media_kit
or stop counting independent Dart HTTP prefetch as first-frame optimization.
The first migration does not enable a proxy; it instruments cache provenance
and bases scheduling decisions on observed reuse. A later cache change requires
its own security and authorization review.

## Presentation and progress rules

- Show the known poster/cover immediately and cross-fade only after the first
  presented frame. This improves perceived responsiveness without claiming the
  stream is ready.
- Store progress in one handoff snapshot keyed by opaque ticket plus target
  identity, not solely by drama id.
- Persist normal watch progress asynchronously, but retain the in-memory
  handoff snapshot as the active-process authority.
- Do not emit a zero-second "start" progress event for a target that has a
  pending nonzero handoff position; report after seek verification or include
  the authoritative target position.
- User pause suppresses autoplay after surface reattachment, but does not
  suppress poster restoration or seek verification.

## Migration stages

### Stage 1: observability and admission control

Add `PlaybackIntent` and correlation IDs to existing timing traces. Record
priority admission, cache provenance, requested/verified seek positions, and
terminal first-frame state. Enforce foreground traffic precedence without
changing native session policy.

### Stage 2: unified source/open/seek primitive

Extract a controller primitive that performs the paused-open, seek-ready,
seek-verify, and play pipeline. Route both For You and ordinary player through
it. Add a failing test for the current 27-second-to-zero-second return.

### Stage 3: ticketed handoff

Move route-return ownership to the coordinator. Remove page-level combinations
of `resumeAfterCompetingPlayer`, recovery, and external progress synchronization.
One ticket produces one command pipeline.

### Stage 4: traffic scheduler and rendition startup policy

Make foreground work preempt startup/next-item preload. Apply first-frame
quality policy, validate whether shared cache reuse exists, and only then tune
preload bytes/segment counts.

### Stage 5: remove duplicate bridges

After regressions pass, delete page- and shell-level playback recovery paths
that bypass the coordinator. Keep platform decoder recovery inside
`PlayerPlaybackController` as a low-level implementation detail.

Each stage is feature-gated, emits comparable metrics, and can be rolled back
without changing HLS/CDN source contracts.

## Acceptance tests and release gates

Automated tests must prove:

- each player entry produces at most one foreground open for an intent;
- For You to ordinary player and ordinary player back retain episode and seek
  position;
- a stale handoff cannot overwrite a subsequent swipe, refresh, or direct
  route entry;
- foreground HLS work preempts a Home candidate;
- a no-shared-cache preload is never reported as a first-frame cache hit;
- user-paused, locked, unavailable, backgrounded, and iOS session-cap paths
  preserve their existing behavior.

Device runs must separately report iOS and Android P50/P95 for cold For You,
Home-to-For You, For You-to-ordinary, ordinary-to-For You, direct ordinary
entry, and next-item swipe. Initial targets are P50 under 2.5 seconds and P95
under 5 seconds for cold For You; handoff return P50 under 1.5 seconds. These
are release goals, not a claim that code changes alone can overcome a slow CDN.

## Non-goals and risks

This design does not add native decoder capacity on iOS, replace media_kit, or
promise cache reuse without verification. CDN response time, segment encoding
layout, and signed source indirection may remain separate bottlenecks after
state and scheduling are corrected. Those bottlenecks will be measurable from
the new pipeline and addressed in a second, evidence-led delivery.
