# Player Experience System Architecture Plan

This document defines the architecture direction for the short-drama player
experience across Home, For You, and single-drama playback. It is a planning
document only: no UI, playback logic, local HLS cache, or backend integration is
changed by this phase.

## 1. System Goals

- Home card entry should feel close to instant. The first playable frame should
  appear as early as the network, CDN, HLS source, and media pipeline allow.
- For You vertical feed switching should avoid unnecessary loading by preparing
  nearby playable items and preserving session isolation.
- Single-drama previous/next episode switching and swipe-back should reuse
  retained or prepared sessions whenever possible, instead of reopening sources.
- Switching bottom tabs, returning from Player, or moving the app to the
  background must stop audio.
- Every slow path must be diagnosable in release builds through timing logs,
  especially source resolve, HLS preload, media open, first frame, buffering,
  window hit/miss, and lifecycle release.

## 2. Current Conclusions

- Dart-side source resolve and `media_kit` open calls are already fast in device
  timing, usually tens of milliseconds.
- Startup preload can hit after Home feed load, but real device tests still show
  first-frame delays. Normal Dart HLS prefetch does not guarantee that
  `media_kit` can reuse enough work to improve first-frame latency.
- The previous/current/next playback session window is currently the most
  effective client-side experience optimization:
  - prepared next can make downward switching fast when first frame is ready;
  - retained previous can make swipe-back nearly instant;
  - window misses are easy to identify and should be fixed before heavier cache
    work.
- Startup preload and playback preload now have separate scopes. Future work
  must not merge their pending requests, generation state, or `releasePending()`
  behavior.
- If stable mock sources still show multi-second cold start, the likely
  bottleneck is HLS first segment, CDN behavior, startup bitrate, decode, or the
  player pipeline rather than Flutter UI layout.

## 3. Layered Design

### Home And For You Entry Layers

Home and For You only express intent:

- user wants to play a drama or feed item;
- first visible item is worth startup preloading;
- current feed index changed and nearby items may be preloaded.

They must not create `media_kit` players, hold `VideoController`, perform HLS
HTTP work directly, or own playback truth.

### PlayerPlaybackController

`PlayerPlaybackController` is the only source of truth for actual playback
state:

- current playable item and source;
- open/play/pause/dispose;
- position, duration, buffered position, seek;
- speed, ended state, retry;
- recoverable/fatal media errors;
- visibility and app lifecycle pause.

UI controllers may manage sheets, paywalls, and presentation-only states, but
they must not duplicate real playback truth.

### StartupPreloadController

`PlayerStartupPreloadController` owns Home startup preload only:

- receives a Home first-screen candidate;
- resolves a playable item through Player repository boundaries;
- invokes the startup-scoped HLS preload manager;
- records idle/pending/success/failed/cancelled;
- supports cancellation on Home category switch, refresh, or dispose;
- never creates a media session and never produces audio.

Startup preload failure must not affect Player playback error state.

### Playback Preload

Playback preload is internal to active player experiences:

- resolves/preloads next and optionally previous HLS sources;
- uses playback-scoped pending/release state;
- skips locked, unavailable, or null-source items;
- never creates a playback session or produces audio;
- is released when Player is hidden, disposed, or memory pressure occurs.

### PrepareManager And Session Window

`PlayerPlaybackPrepareManager` manages session reuse:

- previous retained paused session;
- current playing session;
- next prepared muted/paused session;
- maximum previous/current/next window;
- release on hidden, dispose, memory pressure, or stale generation.

Only the current session may play. Previous and next sessions must be paused or
muted and must not produce sound.

### HLS And CDN Layer

The HLS/CDN layer owns source and cache-policy concepts:

- playlist fetch and first-segment preheat;
- source expiry and signed URL refresh boundaries;
- segment duration and first segment size assumptions;
- future cache-control and network-policy handling.

Current implementation remains remote HLS playback plus lightweight preload.
Local HLS cache/proxy is a later decision, not an implicit dependency.

### Configurable Playback Policy

Playback smoothness settings should be configurable through a typed policy
object instead of scattered constants. The important distinction is cost:

- HLS playlist/first-segment preload is relatively light and may be tuned by
  scenario.
- Prepared media sessions are expensive because they hold player instances,
  decoder resources, memory, and audio-lifecycle risk.
- Home startup preload is a separate scope and should not inherit active-player
  feed settings by accident.

Future implementation should introduce a `PlayerPreloadConfig` or equivalent
typed policy with documented fields such as:

- `homeStartupPreloadCount`: default `1`; controls Home first-screen startup
  candidates only.
- `singleDramaForwardHlsPreloadCount`: default `1`; controls HLS preload after
  the current episode.
- `singleDramaBackwardHlsPreloadCount`: default `0` or current behavior; controls
  HLS preload behind the current episode when needed.
- `forYouForwardHlsPreloadCount`: default `1`; may be tuned higher for feed
  scrolling after device timing proves benefit.
- `forYouBackwardHlsPreloadCount`: default `0` or `1`; should stay conservative
  because feed users mostly scroll forward.
- `maxConcurrentHlsPreloads`: default `1`; keep sequential until logs prove
  parallel preloads help more than they compete with current playback.
- `maxPreloadBytes`: keep bounded and source-policy aware.
- `preloadTimeout`: keep short enough that stale preloads do not occupy network
  work.
- `preparedForwardSessionCount`: default and maximum `1` for now.
- `retainedBackwardSessionCount`: default and maximum `1` for now.

Code comments are required on this config because these values are operational
tuning knobs, not styling constants. Comments should explain:

- whether a field controls HLS HTTP preload or media-session preparation;
- the default value and why it is conservative;
- whether the value is safe to change remotely later;
- what user experience or resource risk changes when the value increases.

Until a real remote config or backend policy exists, the provider should return
local defaults. Remote configuration can be added later behind the same typed
interface.

### Metrics And Timing

Timing must remain available in release builds through
`--dart-define=PLAYER_TIMING_LOGS=true`.

Required log dimensions:

- session key and trace id;
- item id, source label, source profile;
- user trigger and from/to item;
- source resolve, HLS preload, media open, play, first position, first frame,
  buffering, error/retry;
- session window result: prepared next hit, retained previous hit, or fallback
  miss;
- release reason: hidden, dispose, memory pressure, stale generation.

## 4. Playback Chains

### Home Card To Single-Drama Player

Preload:

- Home feed load may request startup preload for the first playable visible
  drama only.
- Home category switch, retry, refresh, or disposal cancels startup preload.
- Home does not create a media session.

Prepare:

- No media-session prepare happens in Home.
- After Player opens, playback preload and PrepareManager can prepare next
  episode from inside the Player scope.

Media session creation:

- Created only by `PlayerPlaybackController` after the single-drama Player page
  requests playback.

Release:

- Back navigation, route pop, app hidden, or player disposal pauses/disposes
  playback scope and session window.
- Startup scope release is independent and should not affect active Player
  preload/session work.

No-audio scenarios:

- Home startup preload must never create audio.
- Returning from single-drama Player must pause and dispose active playback.
- App inactive/paused/hidden must pause playback.

Required logs:

- Home feed loaded and startup preload request/start/end.
- Home card tap and route push timing.
- Startup preload hit/miss on `playItem`.
- Source resolve, media open, first frame, first position.
- Session window setup after entry.

### For You Tab To Feed Player

Preload:

- For You feed may preload next item from active Player scope after current
  index is known.
- Startup preload is not responsible for For You feed continuity.

Prepare:

- PrepareManager may keep current and next feed item sessions inside the
  For You session key.
- Previous retained session may be reused on upward swipe if still in window.

Media session creation:

- Created by `PlayerPlaybackController` for the For You session key.
- Session state must be isolated from single-drama playback.

Release:

- Switching to Home, My list, or Profile pauses current playback and releases
  pending playback preload/session window work according to current lifecycle
  rules.
- Feed index should be retained unless the feature intentionally resets it.

No-audio scenarios:

- Bottom-tab switch away from For You must stop audio.
- App background/inactive must stop audio.
- Prepared/retained non-current sessions must stay paused or muted.

Required logs:

- For You tab visibility changes.
- PageView scroll start/end and index changes.
- Preload candidates and skipped reasons.
- Window hit/miss and release reason.
- First frame and buffering timing per source label.

### Single-Drama Vertical PageView

Preload:

- Current episode should trigger next episode HLS preload when playable.
- Previous may be retained through session window rather than repeatedly
  preloaded.
- Locked, unavailable, or null-source episodes must be skipped.

Prepare:

- Next playable episode can be prepared as a muted/paused session.
- Current session becomes previous retained session when moving to a different
  episode if still inside the allowed window.

Media session creation:

- Normal open creates a current session only when no suitable prepared/retained
  session is available.
- Prepared hit and retained previous hit must avoid duplicate normal open.

Release:

- Leaving Player releases current session and window.
- Hidden/app lifecycle pause must stop audio.
- Stale generation must not take over current playback.

No-audio scenarios:

- Previous/next sessions are never allowed to play audibly.
- Locked/unavailable episodes must not open, prepare, or preload media.
- Paywall/sheet open should not dispose playback, but actual page leave should.

Required logs:

- Manual swipe direction and page changed.
- Auto-next animation start/end.
- Preload candidates, allowed ids, skipped reasons.
- Prepared hit next, retained hit previous, window miss fallback open.
- Retain current before normal open and retain current done.
- Dispose/release reason for sessions leaving window.

## 5. Recommended Next Phases

### Phase 5.14: Device Timing Re-Review

- Run several release-device passes with `PLAYER_TIMING_LOGS=true`.
- Confirm startup hit/miss, prepared hit, retained hit, window miss, first frame,
  and buffering timing for stable mock sources.
- Produce a short timing matrix for Home entry, For You switching, single-drama
  next, single-drama previous, and auto-next.
- Do not change playback strategy until timing identifies the slow boundary.

Device pass on Android `R58WC02B69R` with release build and
`PLAYER_TIMING_LOGS=true`:

| Scenario | Preload/window result | Source resolve | Media open | User action to first frame | User action to position advanced | Audio background | Conclusion |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home cold entry, pass 1, `mux-fast` | startup hit, first item window miss | 41ms | 23ms | 2673ms | 3442ms | No | Cold-start delay is after open, in HLS/media first-frame path. |
| Home cold entry, pass 2, `mux-fast` | startup hit, first item window miss | 41ms | 17ms | 2869ms | 3715ms | No | Repeated pass confirms source resolve/open are not the slow boundary. |
| Single drama next swipe EP01 -> EP02 | prepared next hit, firstFrameReady=true | 0ms repeated resolve | 0ms repeated open | Already prepared | 58ms | No | Session window works; no fallback open. |
| Single drama previous swipe EP02 -> EP01 | retained previous hit | 0ms repeated resolve | 0ms repeated open | Already retained | session play at 50ms | No | Swipe-back reuses previous session and preserves position. |
| For You first entry | window miss first item | 43ms | 25ms | 3768ms | 4612ms | No | First For You item has the same cold-start behavior as Home. |
| For You next swipe 1 | prepared next hit, `mux-tears-stable` | 0ms repeated resolve | 0ms repeated open | Already prepared | 64ms | No | Prepared session makes feed swipe fast. |
| For You next swipe 2 | prepared next hit, `apple-bipbop-low-stable` | 0ms repeated resolve | 0ms repeated open | Already prepared | 83ms | No | Session window remains effective across multiple feed items. |
| Auto-next | Not measured in this pass | N/A | N/A | N/A | N/A | No | The long mock HLS sources did not emit completed during manual timing; use a short fixture or forced completed event for future device auto-next timing. |

Additional observations:

- Startup preload completed before Home entry and included playlist plus first
  two segment preheat, but first frame still took about 2.7-2.9s on `mux-fast`.
- `mux-tears-stable` warm-up may need up to about 3.1s before first frame in
  some passes, but once prepared is ready, takeover is fast.
- HLS preheat can spend multiple seconds on the second segment for some sources
  (`mux-tears-stable` showed a multi-MB second segment and hit max bytes). This
  is useful CDN/source evidence, but it does not block current playback.
- Switching away from For You logged `playingStream false`, `reason=hidden`,
  and session window release. Android audio policy logs also showed player
  release. No background audio was observed.

Attribution:

- Not a source resolve problem: stable around 41-43ms.
- Not a Dart `media_kit open()` call problem: stable around 17-25ms.
- Not a session-window miss problem for next/previous after preparation:
  prepared and retained hits are working.
- Remaining cold-start slowness is most likely HLS first segment / CDN /
  decoder / media_kit first-frame pipeline.
- Auto-next timing still needs a short controlled fixture. Current production
  mock sources are too long for efficient manual completed-event timing.

Next decision:

- Do not keep adding UI-layer loading patches for cold start.
- If cold start remains unacceptable, move to Phase 5.15 local HLS cache/proxy
  spike or Phase 5.16 server/CDN playback source specification.
- For auto-next device timing, add a short test-only HLS fixture or a dedicated
  debug trigger before trying to infer behavior from long public streams.

### Phase 5.15: Local HLS Cache/Proxy Spike

- If first-frame delays remain after session window hits, evaluate a local HLS
  cache/proxy spike.
- Scope should be explicit: cache playlist/segments with quota, expiry, and
  cancellation.
- Validate whether `media_kit` can benefit from the local proxy before product
  implementation.
- Implementation boundary:
  - `HlsLocalProxyServer` is an experimental player data-layer component.
  - `HlsProxyPlaybackSourceResolver` can map a remote m3u8 to a localhost m3u8
    when `PLAYER_HLS_LOCAL_PROXY_SPIKE=true`.
  - The default remains remote HLS playback; the spike is off for normal builds.
  - The proxy rewrites playlist URLs and caches proxied segment bytes in memory
    only. It does not implement disk quota, LRU, signed URL refresh, offline
    download, or a production cache policy.
  - Startup preload, playback preload, and media-session window ownership do
    not change. Home still never creates a player or `VideoController`.
  - Proxy source generation failure falls back to the remote HLS URL. Runtime
    playlist/segment failure is part of the spike validation and is not yet a
    production fallback path.
- Device validation should compare:
  - direct remote HLS first-frame timing;
  - localhost proxy first-frame timing;
  - second playback of the same source after segment cache hit;
  - swipe back/replay behavior;
  - whether proxy failures cleanly fall back to direct remote playback.
- Initial Android result on `R58WC02B69R`:
  - Direct remote baseline from Phase 5.14 remains the better path:
    `mux-fast` first frame was about 2.7-2.9s after Home tap.
  - Proxy-enabled release build emitted localhost proxy server, playlist fetch,
    segment fetch, and segment cache-hit logs, so the experiment is wired.
  - Proxy playback did not reach a stable first frame inside the sampled window
    and later segment requests hit the proxy timeout path.
  - Recommendation: keep the proxy spike default-off and do not productionize it
    unless a later implementation proves reliable first-frame improvement with
    robust fallback, variant/range handling, and cache policy.

### Phase 5.16: Server/CDN Playback Source Specification

Define a backend/CDN contract for:

- HLS URL and signed URL refresh;
- source expiry;
- duration and dimensions;
- poster and preview sprite/VTT;
- segment duration and keyframe alignment;
- first segment byte size;
- startup bitrate/variant;
- playlist and segment `Cache-Control`;
- subtitles and localized audio/text tracks;
- max preload bytes and network policy.

Phase 5.16 deliverable:

- `docs/player-source-and-cdn-spec.md` defines the playback-source API fields,
  HLS encoding recommendations, CDN/HTTP header requirements, subtitles and
  localization fields, client strategy mapping, and real-source acceptance
  checklist.
- The spec records the current client evidence:
  - source resolve and `media_kit` open are already fast;
  - prepared/retained session window works for next/previous switching;
  - cold first frame still depends heavily on HLS first segment, CDN/source
    behavior, encoding, and media pipeline;
  - the Phase 5.15 local proxy spike is not recommended for production.
- Client-side next work can proceed to `PlayerPreloadConfig` typing and real
  source integration against this contract. Further cold-start optimization
  should involve backend/CDN/encoding changes before adding heavier client
  cache complexity.

### Phase 5.17: Data-Driven Cache Decision

- Use Phase 5.14 timing and Phase 5.15 spike results to decide whether to build
  local HLS cache/proxy.
- If CDN/source tuning solves startup and switching, do not add cache
  complexity.
- If cache helps materially, implement with explicit quota, LRU, expiry, and
  cancellation rules.

### Phase 5.18: Configurable Preload Policy

- Add a typed `PlayerPreloadConfig` and provider with local defaults.
- Use the config for lightweight HLS preload candidate selection in Home,
  For You, and single-drama playback.
- Keep prepared media-session window capped at previous/current/next even if HLS
  preload counts are increased.
- Keep max concurrency conservative until device timing proves parallel preload
  helps.
- Add code comments to every config field that explain cost, default, and tuning
  risk.
- Do not connect remote config in this phase; only preserve the boundary for a
  future server-delivered policy.

Phase 5.18 implementation:

- `PlayerPreloadConfig` now defines local defaults for Home startup preload,
  single-drama forward/backward HLS preload, For You forward/backward HLS
  preload, HLS timeout, max preload bytes, concurrency, and prepared/retained
  media-session caps.
- `playerPreloadConfigProvider` is the replacement boundary for future remote
  config or server-delivered policy.
- `PlayerPlaybackController.preloadAround()` now scans forward/backward
  candidates according to the config. Locked, unavailable, and null-source
  items are skipped without consuming an effective preload slot.
- HLS preloader instances now receive `preloadTimeout` and `maxPreloadBytes`
  from the typed config while keeping startup and playback preload scopes
  separate.
- Prepared media-session behavior remains capped at previous/current/next. HLS
  preload count changes do not increase prepared player instances.

## 6. Explicit Prohibitions

- Do not create a player or `VideoController` in Home.
- Do not let startup preload and playback preload share pending request,
  generation, or `releasePending()` state.
- Do not expand the session window beyond previous/current/next to hide root
  cause.
- Do not increase prepared media-session counts just because HLS preload counts
  become configurable.
- Do not use offline download as a fix for online playback smoothness.
- Do not put playback truth into UI widgets or presentation-only controllers.
- Do not let locked, unavailable, or null-source items open, preload, or prepare
  media.
- Do not treat startup preload failure as playback failure.
- Do not remove release-build timing logs while playback performance is still
  being tuned.
