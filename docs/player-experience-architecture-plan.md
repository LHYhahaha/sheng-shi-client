# Player Experience System Architecture Plan

This document defines the architecture direction for the short-drama player
experience across Home, For You, and single-drama playback. It is a planning
document only: no UI, playback logic, local HLS cache, or backend integration is
changed by this phase.

## Mainline Seal (封板, 2026-05-16)

播放器体验主线（Home / For You / 单剧、`PlayerFeedEngine`、settled-only runtime、单 Video surface、previous/current/next session window）**已封板**。

- **后续**：低端 Android **policy** 线（HLS preload / prepared-retained cap / locked 跳过 preload），不扩大 session window、不把 Video 放回 PageView、不接 HLS proxy。
- **架构**：不继续大拆 engine；开源方案仅作思想参考，**不**替换 `media_kit` 或引入第三方 feed 库。
- **Playback truth** 仍在 `PlayerPlaybackController`；UI / sheet / dwell 由 Page + engine 协调。

### Single-drama chrome auto immersive (2026-05-16)

单剧播放器 chrome（顶栏、侧栏、标题简介等）在**正常播放且用户无操作**一段时间后自动进入沉浸模式；属于 **UI chrome 行为**，不属于播放核心。

| 项 | 说明 |
| --- | --- |
| 适用范围 | 仅 **单剧** `PlayerPage`（`PlayerFeedMode.singleDrama`） |
| For You | **不启用**自动沉浸；会话层 `configureAutoImmersiveSession(enabled: false)` |
| 默认延迟 | `3s`（`RuntimePlayerConfig.autoImmersiveDelay`） |
| 状态归属 | `PlayerUiController` 管理 timer、blocker、chrome mode |
| 点击行为 | 沉浸态单击视频区 → 仅恢复 default chrome，**不暂停**；default 态单击 → 播放/暂停 |
| 测试覆盖 | `playerChromeAutoImmersiveConfigOverrideProvider` 可缩短 delay |

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

### Phase 5.19: Device Regression And Playback Stabilization Review

Android release regression was run on `R58WC02B69R` with
`PLAYER_TIMING_LOGS=true` after the configurable preload policy landed.

Validation build:

```bash
flutter build apk --release --dart-define=PLAYER_TIMING_LOGS=true
flutter install -d R58WC02B69R --release
```

Manual regression matrix:

| Scenario | Result | Timing / log notes | Conclusion |
| --- | --- | --- | --- |
| Home -> single drama player | Passed | Startup preload hit for `found-you-0-ep-1`; source resolve 41ms, media open 38ms, first frame 2212ms after tap, position advanced 3374ms after tap. | Cold entry still depends on HLS/media first frame, not Dart source/open. |
| Single drama EP01 -> EP02 | Passed | `prepared hit next` for `mux-tears-stable`; no repeated source resolve/open; position advanced 52ms after swipe. | Next prepared session window is effective. |
| Single drama EP02 -> EP03 | Passed | `prepared hit next` for `apple-bipbop-low-stable`; position advanced 79ms after swipe. | Consecutive prepared next remains stable. |
| Single drama EP03 -> EP02 | Passed | `retained hit previous`; position retained around 39.5s; no repeated source resolve/open. | Swipe-back reuse works and preserves playback position. |
| For You first entry | Passed | `hideShellNavigation=false`; first item window miss as expected; source resolve 44ms, media open 25ms, first frame 4705ms after tab action, position advanced 5636ms. | First For You item has cold-entry behavior; bottom navigation remains visible. |
| For You next swipe | Passed | `prepared hit next` for `mux-tears-stable`; position advanced 54ms after swipe. | Feed switching benefits from prepared next. |
| For You hidden by switching Home | Passed | `playingStream false`, `reason=hidden`, and session window release logs emitted. | Tab switch stops playback and releases hidden prepared/retained sessions. |
| Playback controls | Passed | Tap play/pause, seek drag, Speed sheet, Episodes sheet, Share sheet, and Download placeholder were exercised manually. | Controls stayed scoped to the current playback session; Download remains a placeholder. |
| App/background lifecycle | Passed | Back from single drama emitted `reason=dispose`; For You tab switch emitted `reason=hidden`; no background audio was observed. | Audio lifecycle guard remains intact. |
| Auto-next | Covered by tests / not manually timed | Public mock HLS streams are too long for practical manual completion timing. Existing tests continue to cover completed -> PageView animation and locked/unavailable/last-item guards. | Use a short test fixture for future release-device auto-next timing if needed. |

Issue classification after Phase 5.19:

- P0: none.
- P1: none blocking client playback mainline closure.
- P2:
  - cold first frame for Home and first For You item remains source/CDN/media
    pipeline dependent;
  - auto-next should get a short fixture if release-device timing is needed;
  - real-content acceptance should wait for the server/CDN playback source
    specification to be implemented.

Current decision:

- The client-side player mainline can be considered stabilized for the mock HLS
  MVP.
- Do not add more UI-layer patches, expand the session window, or revisit local
  HLS proxy/cache before real playback sources are integrated.
- Future large player work should reopen after real source/CDN timing proves a
  specific bottleneck.

### Phase 5.20: PageView Performance Architecture Refactor

日期：2026-05-16

真机新增结论：

- 滑到 locked episode 时卡顿不只是解锁抽屉时机问题。
- 用户关闭解锁抽屉后继续上下滑，PageView 仍然会卡，说明当前播放器页面存在
  PageView / playback state / Video surface / locked business state 混合导致的结构性性能风险。
- 当前 `PlayerPage` 监听完整 `PlayerPlaybackState`，而 playback state 包含 position、
  buffering、first frame、surface lifecycle、preload 等高频字段。高频媒体状态更新会扩大
  到 `PlayerPage`、`PageView.builder` 和 `PlayerChrome` 的 rebuild 路径。

阶段目标：

- 不继续围绕解锁抽屉做小补丁。
- 先验证并降低 PageView rebuild 面。
- 再决定是否把真实 `Video` surface 从每个 PageView item 上提到 PlayerPage viewport 层。
- 保持 `PlayerPlaybackController` 作为唯一播放真相来源，不把播放真相下放到 UI widget。

#### S0: Build / Frame Diagnostics

只读或极小改动，目标是验证卡顿来源。

- 统计 `PlayerPage.build` 次数和耗时。
- 统计 `PageView.itemBuilder`、当前 item `PlayerChrome.build`、非当前 item build 次数。
- 统计 `Video` mount / unmount / controller 替换次数。
- 统计 EP03 -> EP04 locked 时：
  - current item change 到 locked UI 出现耗时；
  - `blockItem` 耗时；
  - `_releaseSessionWindowFor` 耗时；
  - `_disposePreloads` 耗时；
  - auto sheet scheduling 耗时。
- 只在 debug/profile/timing flag 下启用日志，不污染 release 默认输出。

#### S1: Rebuild Boundary Split

第一轮开发优先做，风险最低。

- `PlayerPage` 不再直接 watch 完整 `PlayerPlaybackState`。
- 为主 PageView 提供低频 view state，只包含：
  - current item id；
  - status 是否 blocked/unavailable/error；
  - 是否展示 unlock button；
  - 是否允许挂载当前 video surface。
- `PlayerSeekBar` 单独监听 progress 字段：
  - position；
  - duration；
  - bufferedPosition；
  - seeking preview。
- `Video surface / loading / firstFrame` 单独监听 render 字段：
  - videoController；
  - surfaceLifecycle；
  - hasFirstFrame；
  - isBuffering；
  - currentItemId。
- `preloadStates / preloadedItemIds / timing/debug state` 不进入 PageView 主 build。
- `_isPageScrolling` / `_overlayOpacity` 尽量局部化，避免 setState 重建整棵 PageView。

验收：

- position 高频更新不应导致整个 `PageView.builder` 重跑。
- seekbar 能独立更新。
- 滑到 locked episode 时 `Unlock Now` 快速出现，PageView 不明显卡顿。
- free / 已解锁 episode 播放链路不回退。

#### S2: Active Video Surface Overlay Spike

如果 S1 后 PageView 仍明显卡顿，再进入本阶段。

推荐方向：

- PageView item 只渲染静态 shell：
  - poster / fallback；
  - title / synopsis；
  - action rail；
  - top bar；
  - locked / unavailable placeholder；
  - unlock button。
- 真实 `Video` widget 提升到 PlayerPage 顶层 `ActivePlaybackSurfaceOverlay`。
- overlay 只绑定当前 active item 的 `VideoController`。
- 非当前 item 永远不挂 `Video`。
- 对齐策略分两步：
  1. 低风险版本：page settle 后切换 overlay 到当前 item；
  2. 体验增强版本：监听 `PageController.page`，让 overlay 跟随页面滑动。

风险：

- 需要处理滑动时视频 surface 与 page shell 的视觉对齐。
- Android `media_kit_video` native surface late callback 仍需沿用 pause -> detach -> dispose
  顺序。
- prepared next session 不应同时挂第二个 `Video` widget。

#### S3: Locked / Paywall State Split

locked 逻辑需要拆成三阶段，避免在滑动关键路径做重操作：

1. `LockedPresentation`
   - 立即展示 locked poster / fallback 和 `Unlock Now`。
   - 不触发 media resolve/open/preload/prepare。
2. `PlaybackQuiesce`
   - 尽快 pause 当前 session，保证旧音频停止。
   - 尽量轻，不在滑动帧里释放整个 window。
3. `ResourceCleanup`
   - scroll settle / post frame 后释放 stale prepared window、pending preload、surface。
   - auto sheet 也在这个阶段后弹出或确认 current item 后弹出。

原则：

- locked / unavailable / null-source item 仍不能 resolve、open、prepare 或 preload 未授权 source。
- 但“显示 locked UI”和“释放媒体资源”不能强绑在同一个滑动关键路径。

#### S4: Tests And Device Acceptance

必须补充：

- position 更新不触发 PageView shell rebuild 的测试或可观测诊断。
- locked item 不挂 `Video`、不显示 seekbar、不触发 source resolve/preload/prepare。
- EP03 -> EP04 locked，`Unlock Now` 先出现，旧音频停止。
- 关闭抽屉后继续滑动不卡，快速上下滑不重复弹旧 item。
- Android 真机验证：
  - single drama EP03 -> EP04 locked；
  - 关闭 sheet 后 EP04 -> EP05 -> EP06；
  - For You 上下滑；
  - route pop；
  - tab hidden；
  - app background。

明确不做：

- 不换播放器库。
- 不扩大 HLS cache/proxy。
- 不扩大 prepared session window。
- 不接真实 API。
- 不改支付/权益规则。
- 不为了 locked 流畅而提前请求未授权播放源。

### Phase 5.21: Active Surface And Locked Dwell Strategy

日期：2026-05-16

Phase 5.20 / S1 真机复测结论：

- `PlayerPage` rebuild blast radius 已经缩小，播放进度不再明显拖着整个 PageView 重建。
- 真机日志仍显示 playable episode 切换时存在 `Video.mount`、`Video.unmount`、
  `Video.controller.replace`，说明真实 `Video` surface 仍跟随 PageView item 生命周期。
- locked episode 卡顿还有另一层交互原因：自动解锁/充值抽屉作为 modal 会打断连续滑动。
  即使弹窗时机已经延后，连续滑到多个 locked episodes 时，频繁自动弹 modal 仍会让用户感觉
  PageView 卡住。

因此下一轮不应继续调 debounce，也不应只修一个 EP04 case。需要同时规划两条线：

1. **播放架构线：Active Video Surface Overlay**
   - 把真实 `Video` widget 从 PageView item / `PlayerChrome` 中移出。
   - PageView item 只负责静态 shell 和业务 overlay。
   - 当前 active playable item 的视频由 PlayerPage 顶层 overlay 统一挂载。
2. **解锁交互线：Locked Dwell Auto Sheet**
   - locked current item 先快速显示 poster + `Unlock Now`。
   - 用户停留一段时间且没有继续滑动时，再自动弹解锁/充值抽屉。
   - 如果用户继续滑动，不自动弹，保留按钮。
   - 用户点击 `Unlock Now` 立即弹。

#### S2 Implementation Scope: Active Playback Surface Overlay

目标：

- 解决 `Video` surface 跟随 PageView item mount/unmount 的架构风险。
- 让 PageView shell 滑动更轻，减少 Android `media_kit_video` surface 生命周期干扰。

要求：

- 新增 `ActivePlaybackSurfaceOverlay` 或等价组件，位于 `PlayerPage` 顶层 Stack。
- overlay 只绑定当前 active playable item 的 `VideoController`。
- locked / unavailable / no-source / paywall-blocked item 不挂 `Video`。
- PageView item 不再创建 `Video` widget，只渲染：
  - poster / fallback；
  - gradient；
  - title / synopsis；
  - top bar；
  - action rail；
  - `Unlock Now`；
  - unavailable overlay；
  - seekbar 容器或局部进度 UI。
- 先做低风险版本：surface 可以在 current item settle 后切换，不要求第一版跟手滑动。
- 保留现有 Android pause -> detach -> dispose 顺序。

验收：

- playable EP01 -> EP02 -> EP03 时，PageView item 不再直接产生 `Video.mount/unmount`。
- current playable item 有且只有一个 active `Video` surface。
- locked item 切入时 overlay 隐藏，poster + `Unlock Now` 出现。
- route pop / tab hidden / app background 仍无后台声音。

#### S3 Implementation Scope: Locked Dwell Auto Sheet

目标：

- 解锁流程不再破坏连续上下滑体验。
- locked episode 的第一反馈是 inline `Unlock Now`，不是立即 modal 阻断。

建议策略：

- 进入 locked current item 后，立即显示 `Unlock Now`。
- 自动弹窗改为 dwell 后触发：
  - 用户停留 800-1000ms；
  - 当前 item 未变化；
  - 当前没有 modal/sheet；
  - 当前 item 仍 locked 且未解锁；
  - 用户没有继续滑动。
- 如果用户继续滑动，取消 pending auto sheet。
- 如果用户手动点击 `Unlock Now`，立即打开对应流程，不等待 dwell。
- 对连续 locked episodes，不要每一集刚落位就强制弹 modal；以“停留后弹”为准。

验收：

- 快速滑过 locked episodes 不会连续弹多个抽屉。
- 停留在 locked episode 一段时间后自动弹对应抽屉。
- 关闭抽屉后继续滑动顺畅。
- 点击 `Unlock Now` 立即弹。
- free / 已解锁 episode 不受影响。

#### Phase 5.21 Validation

必须跑：

```bash
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart -d R58WC02B69R
```

建议额外打 release 包验证：

```bash
flutter build apk --release --dart-define=PLAYER_REBUILD_LOGS=true
flutter install -d R58WC02B69R --release
```

真机验证路径：

- Home -> single drama。
- EP01 -> EP02 -> EP03 playable 切换。
- EP03 -> EP04 locked。
- 快速 EP04 -> EP05 -> EP06。
- 停留在 locked episode 等待 auto sheet。
- 关闭 sheet 后继续上下滑。
- 点击 `Unlock Now`。
- route back、tab hidden、app background。

### Phase 5.22: Follow-Scroll Video Surface And Long Swipe Stability

日期：2026-05-16

Phase 5.21 真机体验新增结论：

- Active video surface 上提后，playable / unlocked 视频切换的 native surface 绑定更清晰，
  但低风险版本只在 current item settle 后切换 overlay，导致视频画面不跟随 PageView 滑动。
  对短剧类产品来说，已解锁/免费内容滑动时视频必须跟手，否则体验不自然。
- 测试不能只滑 3-5 条。真机反馈显示越往下滑越卡，后续验收必须覆盖连续滑动 10-15 条，
  包括 free / locked / membership / unavailable 混合内容。

下一轮目标：

1. 保留 Active Video Surface Overlay 的“单一真实 Video surface”架构。
2. 让 playable / unlocked 当前视频 surface 在 PageView 滑动时跟随页面位移。
3. locked / unavailable item 仍只显示静态 shell，不挂 Video，不请求未授权 source。
4. 增加长滑动诊断，确认越往下卡是 item shell、sheet scheduling、entitlement/block、还是
   PageView 缓存/图片解码导致。

#### Follow-Scroll Surface Strategy

推荐实现：

- 使用 `PageController` 的 `Listenable` 或 `AnimatedBuilder` 读取 `page` 值。
- 根据 `currentIndex` 和 `page` 计算 active video surface 的垂直偏移：
  - `offsetY = (currentIndex - page) * viewportHeight`
  - 只在当前 playable item 附近显示 overlay。
- 当用户从 playable 滑向 locked：
  - active video surface 跟随旧 playable page 滑出；
  - locked page shell 跟随滑入；
  - 到达 locked current 后 hide overlay，显示 poster + `Unlock Now`。
- 当用户从 locked 滑回 playable：
  - playable page shell 进入；
  - overlay attach 后跟随 current playable page 显示。
- 第一版只需要跟随 single drama；For You 可同步使用同一套逻辑，但如果风险大，可先保证
  single drama。

风险：

- 跟手期间 overlay 和 PageView shell 可能出现一帧错位，必须用真机录屏验证。
- 不允许为了跟手而在邻近页挂第二个 Video。
- 不允许把 prepared next session 直接挂到另一个 Video widget。

#### Long Swipe Diagnostics

必须增加或复用日志，覆盖连续滑动 10-15 条：

- `PageView.itemBuilder` build count 按 item 分类；
- active overlay show/hide/translate；
- dwell auto sheet schedule/cancel/fire；
- `blockItem`、`releaseSessionWindow`、`disposePreloads` 耗时；
- image/poster 是否重复解码或频繁创建；
- 当前页面 index 越大时，是否存在 build 数、timer、pending sheet、retained state 累积。

验收路径：

- 从 EP01 连续向下滑到 EP12 或更后。
- 途中遇到 locked episode 不停留时不能弹 sheet；停留后才弹。
- 已解锁/免费 episode 视频要跟手滑动。
- locked episode 只显示 shell + `Unlock Now`。
- 越往下滑不应越来越卡。
- 关闭 sheet 后继续连续滑 5 条。
- 再向上滑回已播放 episode，仍无旧音频泄漏。

如果 S5.22 后仍然越滑越卡，下一步再检查：

- PageView 缓存范围和 item shell 是否过重；
- poster 图片尺寸/解码是否需要预缓存或降尺寸；
- locked cleanup 是否需要进入三阶段状态机；
- 是否有 pending timers / modal scheduling 未释放。

### Phase 5.23: Locked Episode As Normal Page Shell

日期：2026-05-16

产品/体验方向更新：

- locked episode 不应该像一条完全不同的“播放阻断链路”。
- 更好的模型是：locked episode 和 free episode 一样参与 PageView shell 渲染，只是不启动
  media playback，不请求未授权 source，并在页面上盖一层 locked overlay。
- 解锁成功后，当前 locked page 转成 playable page，再 attach active video surface 并播放。

当前问题：

- locked current item 进入时调用 `blockItem`，会触发 pause、surface hide、window release、
  preload dispose、blocked state 和 sheet scheduling。
- 这让 locked page 成为“特殊页面”，滑到 EP04+ 时体验明显不同于前三个 free episodes。
- 真机表现是：free episodes 滑动相对顺，locked episodes 尤其卡。

目标模型：

```text
free / unlocked:
  Page shell + ActiveVideoSurfaceOverlay

locked:
  Page shell + poster/fallback + locked overlay
  不 open source
  不 attach Video
  不 preload/prepare unauthorized source
  不在滑动关键路径 release whole window

unlock success:
  当前 item 标记为 playable
  locked overlay 消失
  ActiveVideoSurfaceOverlay attach
  playItem
```

实现原则：

- locked 是内容访问状态，不应该把播放器切成一条重型 blocked page。
- 进入 locked current item 时，最多只做轻量 quiesce：
  - 立即停止旧音频；
  - 不再把旧视频 surface 留在当前 locked page 上；
  - 但不在滑动关键路径同步释放全部 prepared window / pending preload。
- locked overlay 应随 PageView shell 自然滑动。
- 自动弹窗只作为停留后的后续动作，不影响 PageView 滑动。
- 手动点击 `Unlock Now` 立即打开对应流程。

建议重构：

1. 新增或明确 `PlayerAccessPresentationState`
   - `playable`
   - `lockedCoins`
   - `lockedRecharge`
   - `lockedMembership`
   - `unavailable`
2. `PlayerPage` 对 locked item：
   - 不调用重型 `blockItem` 作为进入 locked page 的第一步；
   - 先更新 UI/presentation state；
   - active video overlay 根据 presentation state 隐藏；
   - old audio pause 可以快速执行；
   - heavy cleanup 延后或弱化。
3. `PlayerPlaybackController` 可新增轻量 API：
   - `pauseForAccessOverlay(...)`
   - 或 `quiesceForLockedPage(...)`
   - 只负责停声和清当前 surface 绑定，不释放整个 window。
4. 保留 `blockItem` 给真正 fatal/unavailable/route cleanup 等需要重阻断的场景，不要作为
   locked page 默认入口。

验收：

- EP01 -> EP02 -> EP03 -> EP04 滑动时，EP04 像普通 page 一样进入，先显示 poster +
  `Unlock Now`，不卡顿。
- EP04/EP05/EP06 连续滑动不触发重型 media cleanup。
- locked item 不 open/preload/prepare unauthorized source。
- 旧音频在进入 locked 后停止。
- 停留 locked 后才弹 sheet。
- 点击 `Unlock Now` 立即弹。
- 解锁成功后，当前 page attach active video surface 并播放，不停在封面。

明确不做：

- 不提前获取 locked 播放源。
- 不为了流畅而播放未授权内容。
- 不创建多个 Video widgets。
- 不改支付/权益规则。
- 不扩大 HLS cache/proxy。

### Phase 5.24: Settled-First Feed Runtime

日期：2026-05-16

真机体验问题：

- 单剧播放器在 locked episode 附近仍会出现“手拖不动”的感觉。
- 这类卡顿不是单纯的 HLS 加载慢，也不是单个抽屉弹出慢，而是 PageView 拖动过程中仍可能触发
  access / playback / preload / sheet / surface 相关运行时逻辑。
- 当前 `onPageChanged` 和 `feed.currentItem` 更接近“页面阈值已切换”，不等于“PageView 已完全
  settled”。如果在这个阶段触发 `playItem`、`quiesceForAccessOverlay`、`preloadAround` 或
  auto sheet 调度，就会把播放运行时工作挤进用户手势路径。

核心规则：

```text
dragging / settling:
  只允许 PageView shell 和 active video surface transform 跟随手势。
  不触发 access decision。
  不触发 playItem / open source。
  不触发 quiesce / block / release。
  不触发 preload / prepare。
  不触发 auto sheet schedule/fire。

settled:
  只处理最终 settled item。
  先计算 access presentation。
  playable 才播放/恢复。
  locked 才展示 Unlock Now，并按 dwell 规则弹 sheet。
  unavailable 才展示不可用态。
  周边 preload/prepare 也从 settled playable item 出发。
```

目标架构：

```text
PlayerPage
  -> Feed Viewport Layer
     pageOffset / scrollPhase / candidateIndex / settledIndex / settledItemId
     只管手势和 PageView settled，不碰权益、播放、弹窗、预加载。

  -> Access Presentation Layer
     只在 settled item 后计算 playable / lockedCoins / rechargeRequired /
     membershipRequired / unavailable。

  -> Playback Runtime Layer
     只消费 settled playable item，负责 play / resume / prepare next /
     retain previous / pause / hide / release。

  -> Overlay Orchestrator
     只消费 settled locked presentation，负责 dwell、dismiss once per item、
     manual Unlock Now、recharge -> unlock -> play。
```

阶段拆分：

1. R1/R2 合并：`PlayerViewportController` + settled-only access
   - 新增 `player_viewport_controller.dart`。
   - `onPageChanged` 只更新 viewport candidate/current index。
   - `ScrollStart/ScrollUpdate` 只更新 `scrollPhase/pageOffset`。
   - `ScrollEnd` 后等待 page 稳定，再输出 `settledIndex/settledItemId`。
   - `feed.currentItem` listener 不再直接触发 access/playback/sheet/preload。
   - `_handleEntitlementDecisionForItem` 只由 settled item 触发。
2. R3：抽出 overlay/sheet orchestration
   - 把 dwell、dismissed item、manual Unlock Now、modal state 从 `PlayerPage`
     收到 `player_overlay_orchestrator.dart`。
3. R4：抽出 playback runtime scheduler
   - Page 不再散落调用 `playItem`、`quiesceForAccessOverlay`、`preloadAround`。
   - scheduler 根据 settled access presentation 发出唯一 runtime command 序列。
4. R5：`PlayerPage` 只保留 UI 组装
   - PageView shell、active video surface、top bar、sheet host。
   - 不拥有 access decision、runtime command、dwell timer。

R1/R2 验收：

- drag 中不触发 entitlement evaluate。
- drag 中不 schedule auto sheet。
- drag 中不 quiesce / block / release / dispose preload。
- drag 中不 source resolve / preload / prepare / open。
- 快速滑过 EP04 -> EP05 -> EP06，只处理最终 settled 的 EP06。
- locked item 连续滑动不阻塞 PageView。
- free -> locked -> free 回滑恢复播放。
- `Unlock Now` 手动点击仍立即打开解锁/充值流程。
- 解锁 `Play` 后恢复 active video surface，不停封面。
- For You 和 single drama 共用 viewport/access/runtime 思路，但 sessionKey 保持隔离。

明确不做：

- 不换播放器库。
- 不接真实 API。
- 不做 HLS local cache/proxy。
- 不扩大 player session window。
- 不把多个 `Video` 放回 PageView item。
- 不改支付/权益业务规则。
- 不提前 resolve/open/preload/prepare locked source。

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
