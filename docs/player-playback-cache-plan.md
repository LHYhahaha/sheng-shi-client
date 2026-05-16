# Player Playback And Cache Plan

> **Document status: Historical Plan / Current Decision**
>
> 本文档保留预研与历史方案讨论。**当前产品结论（Current）** 见下框；勿按全文推进 local cache/proxy 生产化。
>
> | Current decision | |
> | --- | --- |
> | Local HLS cache/proxy | **不生产化**；仅 diagnostic spike（`PLAYER_HLS_LOCAL_PROXY_SPIKE`） |
> | Session window | **不扩大**；prepared/retained cap 0..1 |
> | 保留能力 | HLS source resolve、轻量 playlist/segment preload、prepared/retained window、runtime performance policy |
> | Local proxy 文档 | 见 `docs/player-local-hls-proxy-cache.md`（**Diagnostic**） |
>
> ---

This plan covers Player and For You playback reliability, loading experience,
preload strategy, and future HTTP/CDN cache boundaries. **以下内容多为 Historical。**

## Current Problems

- For You playback may continue with audio after switching to Home, My list, or
  Profile.
- Single drama playback may continue with audio after leaving the Player page.
- App inactive, paused, or detached states must pause playback.
- Switching videos can show a black screen while the next source is loading.
- Larger video files can delay the first frame.
- Entering playback from a list can still feel slow when the first source is not
  prepared.
- Vertical swipe switching must reuse prepared sessions when possible instead of
  reopening every source.
- Swiping away from an unfinished video and then swiping back should reuse the
  retained previous session whenever it is still inside the playback window.
- Playback controls now cover tap video to play/pause, real progress, seek,
  speed selection, and completion handling. Remaining polish is focused on
  alignment, visible transitions, and seek thumbnail preview.
- The Figma player design includes a drag-to-seek state with a stronger progress
  bar, time bubble, and thumbnail preview.
- Reference short-drama players include lightweight tap feedback, playback speed
  selection, automatic next episode after completion, and a visible swipe-like
  transition when moving to the next episode.
- The single drama bottom-right action should stay as a `Download` placeholder,
  not a visible `Next` button.
- The single drama player top controls should move with each PageView item while
  swiping, not stay pinned outside the page transition.
- Reference short-drama players show a thumbnail preview while dragging the
  progress bar. The MVP uses the current poster/background as the preview image.
- Future video source, access, cache policy, signed URL refresh, and playback
  progress all require server APIs. For now, these must be represented by
  repository/service boundaries with mock implementations.

## Goals

- Pause playback whenever the player is not visible.
- Show poster/background plus loading before the first frame is ready.
- Keep the current frame or poster visible while buffering.
- Show retry UI when opening or playback fails.
- Support tap video to play/pause in both For You and single drama player.
- Support real position, duration, buffered progress, and seek.
- Support drag seek with a time bubble matching the Figma interaction.
- Support completed playback handling and automatic next episode.
- Keep internal next-episode controller support for automatic playback
  completion, but do not expose a visible `Next` button in the single drama
  bottom action area.
- Support playback speed selection through a lightweight sheet.
- Support a mock seek thumbnail preview while dragging in single drama playback.
- Keep tap feedback lightweight instead of building a full long-video control
  overlay.
- Preload the next playable item lightly.
- Keep a tiny playback session window for smoother vertical switching:
  previous paused, current playing, and next prepared.
- Prepare clear boundaries for HLS, CDN cache, HTTP Range, signed URLs, and
  cache policy.
- Keep mock data out of widgets and pages.

## Short-Term Playback Smoothness Route

The short-term client work should stay focused on one primary goal: make video
playback feel smooth in list entry, vertical feed switching, and swipe-back
scenarios.

Execution order:

1. Stabilize the playback session window.
   - Keep previous/current/next session reuse reliable.
   - Fix window misses, stale takeover, background audio, and repeated open
     before adding heavier cache work.
2. Use device timing to identify the actual slow boundary.
   - Compare source resolve, playlist preload, media open, first frame,
     buffering, next hit, previous hit, and fallback miss.
3. Add HLS first-segment preheat only if timing proves the window is hitting but
   first frame is still slow.
4. Add lightweight HLS segment cache only if segment preheat is proven useful
   and repeated network fetches remain a real bottleneck.
5. Coordinate server/CDN once client timing shows the remaining bottleneck is
   outside the app.

Decision rules:

- If logs show frequent `window miss fallback open`, continue fixing session
  window reuse.
- If logs show `prepared hit next` or `retained hit previous` but first frame is
  still slow, evaluate HLS first-segment preheat next.
- If first-segment preheat helps but repeated requests still hurt smoothness,
  evaluate a quota-limited HLS segment cache.
- Offline download remains outside the playback-smoothness path and should be a
  separate product feature.

## Server-Mock Boundaries

All future server-backed playback capabilities must be represented by domain
interfaces and mock data implementations before real API integration.

### VideoSourceRepository

Responsibilities:

- `getVideoSource(episodeId)`
- `refreshVideoSource(episodeId)`
- Return play URL, format, expiry, poster URL, and cache policy.
- MVP implementation lives behind `PlayerPlaybackSourceRepository`.
- Mock implementation resolves from `PlayerFeedItem.episode.videoSource`,
  attaches cache metadata, and delegates local cache behavior to a cache manager.

Suggested source fields:

- `id`
- `url`
- `format`: `hls`
- `codecHint`
- `duration`
- `width`
- `height`
- `fileSize`
- `posterUrl`
- `expiresAt`
- `cachePolicy`

### PlaybackProgressRepository

Responsibilities:

- `getProgress(episodeId)`
- `saveProgress(episodeId, position)`

MVP implementation:

- Use an in-memory mock.
- Do not report progress to a real server yet.

### Episode Access

Access state may stay in the current content model initially, but it must remain
outside UI widgets.

Required states:

- unlocked
- locked
- unavailable

Locked and unavailable episodes must not open or preload video sources.

### HLS Preload Policy

Suggested fields:

- `allowPreload`
- `allowHttpCache`
- `preloadStrategy`: `none`, `metadata`, `firstSegment`, `nextItem`
- `maxPreloadBytes`
- `maxCacheAge`
- `requiresAuth`
- `onlyWifi`
- `expiresAt`

### HLSPlaybackPreloadManager

Responsibilities:

- `preload(item, source)`
- `releasePending()`
- Simulate lightweight HLS source/playlist warmup for the current mock phase.
- Cancel pending preload work when the player becomes hidden or is disposed.

MVP implementation:

- Uses `MockPlayerPlaybackPreloadManager`.
- Does not write full media files to disk.
- Does not download MP4 files.
- Keeps the playable source as the remote HLS/m3u8 URL.
- Keeps preload source-only: it must not create a media player session and must
  not produce audio.

### Playback Session Window

Responsibilities:

- Keep only the nearby sessions needed for feed-style vertical playback.
- Retain the previous playable item as a paused session for quick swipe-back.
- Keep the current item as the only session allowed to play.
- Prepare the next playable item as a paused session for faster downward swipes.
- Release sessions outside the previous/current/next window.
- Release all retained/prepared sessions when the player becomes hidden,
  leaves the page, or the provider is disposed.

MVP constraints:

- At most three playback sessions should exist for one player context.
- Previous and next sessions must be explicitly paused and must not produce
  audio.
- Locked, unavailable, and null-source items never enter the window.
- A window miss must fall back to the normal HLS open path without affecting the
  current playback state.

## Playback State

`PlayerPlaybackState` should cover:

Statuses:

- `idle`
- `opening`
- `buffering`
- `ready`
- `playing`
- `paused`
- `seeking`
- `blocked`
- `unavailable`
- `error`
- `disposed`

Fields:

- `currentItemId`
- `currentSource`
- `hasFirstFrame`
- `isBuffering`
- `isSeeking`
- `position`
- `duration`
- `bufferedPosition`
- `seekPreviewPosition`
- `hasEnded`
- `playbackRate`
- `error`
- `preloadedItemIds`

## Playback Controls

### Tap To Play Or Pause

- Tapping the video while playing pauses playback.
- Tapping the video while paused resumes playback.
- A central play button is visible while paused.
- Loading, error, locked, and unavailable states must not directly toggle
  playback.
- Both For You and single drama player must support this interaction.

### Control Overlay

- Tapping the video can show the player controls.
- Controls auto-hide after 2-3 seconds while playing.
- Controls stay visible while paused.
- Opening sheets or paywall overlays must not dispose playback.

### Lightweight Tap Feedback

- When the user taps while the video is playing, show a short pause feedback
  icon for about 350-500ms.
- When the player is paused, keep the central play button visible.
- Loading, error, locked, unavailable, and paywall states must not show normal
  tap feedback.
- This feedback is transient UI and should not become playback source of truth.

### Playback Speed

- The top `Speed` entry should open a dark bottom sheet.
- Options: `2.0x`, `1.5x`, `1.2x`, `1.0x`, `0.8x`.
- The selected option shows a pink check.
- Playback rate belongs to the playback session, so For You and single drama
  sessions remain isolated by default.
- Rate persistence is out of scope for MVP.

### Next Episode And Download Placeholder

- Single drama playback should keep the original bottom-right `Download`
  position as a placeholder.
- Do not expose a visible `Next` button in the bottom action area.
- `Download` is a UI placeholder in this phase. It may be a no-op or show a
  lightweight mock/disabled feedback, but it must not start a real download.
- Internal next episode capability can stay in `PlayerFeedController` for
  automatic completion flows, but the single drama UI must not replace
  `Download` with `Next`.
- For You should not gain the single-drama `Next` entry.

### Playback Completion

- Completion must use the media player's completed event, not
  `position >= duration`.
- `media_kit` exposes `player.stream.completed`; use that through
  `PlayerPlaybackSession.completedStream`.
- When the current item completes and the player is visible, the page may
  automatically move to the next item.
- Automatic next should use the vertical PageView animation so the user sees the
  same swipe-like transition as manual episode switching.
- Completion handling must guard against stale items, hidden pages, seeking,
  sheets/paywall, and disposed sessions.
- If the next item is locked, move to it and show the paywall.
- If the next item is unavailable, move to it and show the unavailable state.
- If the current item is the last item, stay on the current item and show a
  replay/play state. Do not loop automatically.

## Progress And Seek

The progress bar must eventually use real player streams:

- position
- duration
- buffered position
- playing
- buffering

Normal state:

- Show real playback progress.
- Keep buffering progress stable and avoid visual jumps.

Dragging state:

- Show the Figma-style stronger progress bar.
- Show a time bubble such as `00:00 / 01:45`.
- Show a small thumbnail preview above the time bubble.
- Update `seekPreviewPosition` while dragging.
- Disable vertical page swiping while the user is dragging the progress bar.

Drag end:

- Seek to the target position.
- If playback was playing before dragging, continue playing.
- If playback was paused before dragging, remain paused.
- Playback progress persistence starts as a local mock boundary in Phase 5.
  Drag seek should not report progress to a real server.

## Preload Strategy

MVP preload:

- Preload `currentIndex + 1`.
- Keep `currentIndex - 1` as a retained paused session when it was recently
  played.
- Keep at most previous/current/next playback sessions.
- Skip locked and unavailable episodes.
- Release stale preload sessions after fast swipes.
- Release preload sessions when leaving the player.
- Keep For You and single drama sessions isolated.

Do not download complete videos for feed scrolling. The player strategy is HLS
remote playback with lightweight source/playlist preload only.

## HTTP/CDN Cache Strategy

This is a future integration boundary. It should not be fully implemented until
the real video service is defined.

### HLS Preferred

Server/CDN should provide:

- HLS playlist and segment URLs.
- Cacheable playlist and segment responses.
- Small initial segments for fast first frame.
- Signed URL or token support when required.

Client strategy:

- Preload playlist and possibly the first 1-2 segments.
- Respect `maxPreloadBytes`.
- Refresh expired source URLs through `VideoSourceRepository`.

### CDN/HLS Configuration Checklist

Backend and CDN configuration should be reviewed against this checklist before
real traffic ramps up:

- Segment duration: target short segments, generally 2-4 seconds, so startup and
  seeks do not wait on oversized chunks.
- Keyframe alignment: align keyframes with segment boundaries across renditions
  to keep ABR switches and seeks predictable.
- Playlist cache-control: keep master playlists cacheable for longer, but keep
  media playlist TTL aligned with signing and rollout needs.
- Segment cache-control: make `.ts`/`.m4s` segments highly cacheable and
  immutable when URLs are content-addressed or versioned.
- Signed URL expiry: source URLs must live long enough for a viewing session,
  and the backend must define refresh behavior before expiry.
- Redirects: avoid multi-hop redirects on playlists and first segments; if
  redirects are unavoidable, keep them cache-friendly and signed consistently.
- First segment size: keep the first segment small enough for quick first frame
  on cellular networks.
- Master playlist bitrate ladder: include a low initial rendition for weak
  networks and avoid forcing the highest bitrate before ABR has data.

### MP4 Whole-File Cache

- Deprecated for this project.
- Do not implement MP4 whole-file download/cache compatibility.
- Historical `FilePlayerPlaybackCacheManager` and `.mp4.download` temp-file
  handling have been removed.

## Phases

### Phase 1: Lifecycle And Black Screen Fix

- Pause For You playback when switching to Home, My list, or Profile.
- Pause and dispose single drama playback when leaving the Player page.
- Pause on app inactive, paused, or detached.
- Show poster/background plus loading before first frame.
- Keep frame or poster visible while buffering.
- Show retry UI on open error.
- Do not repeat open when source is unchanged.
- Do not open or preload locked or unavailable episodes.
- Prevent stale open results from overwriting the current item after fast swipes.

### Phase 2: Playback Controls

- Tap video to play/pause.
- Sync play/pause with `media_kit` state.
- Show central play button while paused.
- Keep full control overlay display and auto-hide behavior deferred.
- Support For You and single drama player.

### Phase 3: Real Progress And Drag Seek

- Track position, duration, and buffered position.
- Replace fixed progress with real progress.
- Support drag seek.
- Show Figma-style time bubble while dragging.
- Disable vertical page swiping while dragging the progress bar.
- Do not save or report playback progress in this phase.

### Phase 3.5: Completion, Speed, And Lightweight Playback Polish

- Add `completedStream`, `rateStream`, and `setRate` to
  `PlayerPlaybackSession`.
- Track `hasEnded` and `playbackRate` in `PlayerPlaybackController`.
- Add `setPlaybackRate(double rate)`.
- Add replay behavior for ended current source.
- Add `canGoNext` and `goNext()` to `PlayerFeedController`.
- Initially added a visible single drama `Next` entry, but the latest product
  decision is to restore the `Download` placeholder and keep next episode as an
  internal/automatic flow.
- Auto advance to the next item on completed playback when safe.
- Add speed selection sheet.
- Add short pause/play tap feedback without building a full control overlay.
- Do not add progress persistence, CDN/cache, or full For You controls in this
  phase.

### Phase 4: VideoSource And Preload Policy

- Add playback source and cache boundaries:
  `PlayerPlaybackSourceRepository`, `PlaybackSource`, and
  `PlayerPlaybackPreloadManager`.
- Add a mock playback source repository that resolves a playable URL, cache key,
  expiry, and codec hint from the feed item.
- Add a mock preload manager for lightweight HLS source/playlist warmup.
- Route `PlayerPlaybackController.playItem()` through source resolution before
  opening media.
- Open the remote HLS/m3u8 source directly.
- On source resolve/open failure, keep the existing playback error and retry
  path.
- Keep locked, unavailable, and null-source episodes outside resolve/preload/open.
- Rework `preloadAround()` to prepare source metadata only. Preload no longer
  creates media player sessions and cannot play audio.
- Release pending preload work when For You is hidden, a single drama player is
  disposed, or the provider is disposed.
- `pauseForVisibility()` releases pending preload work when the player becomes
  hidden without disposing the active playback session.
- Keep preload scoped to each playback session key, so For You and single drama
  states do not bleed into each other.

Phase 4 defer:

- Real backend video source API.
- Real CDN response headers and signed URL refresh.
- HLS playlist/segment cache.
- Offline download.
- Playback progress server reporting.
- Android smoke verification unless a playback lifecycle issue requires it.

### Phase 4.5: Player UI Polish After Cache Foundation

This phase should run after Phase 4 review passes. Keep it small and focused on
player interaction polish.

Back button alignment:

- Re-align the single drama top-left back button to Figma/reference video.
- Keep the change scoped to `PlayerChrome` single drama top bar.
- Do not add a For You back button.
- Keep the tap target at least 40x40 while preserving the visual icon size.
- Keep `EP.01`, `Speed`, and `More` vertically aligned with the back button.

Completion and bottom action polish:

- When playback completes and auto-advances, animate the vertical PageView to the
  next episode instead of jumping without visible motion.
- Restore the single drama bottom-right `Download` placeholder in the UI.
- Remove the visible single drama `Next` button from `PlayerChrome`.
- Keep `PlayerFeedController.goNext()` available for auto-next/internal flows.
- For the last episode, keep the current ended/replay state and do not show a
  manual `Next` action.
- `Download` remains a placeholder only. Do not implement real downloads in this
  phase.

Seek thumbnail preview MVP:

- While dragging the single drama seek bar, show a small preview thumbnail above
  the existing time bubble.
- Use the current episode poster/background image as the MVP thumbnail.
- Follow the drag position horizontally and clamp the thumbnail to screen
  bounds.
- Reuse `seekPreviewPosition`; do not seek the real player during preview
  updates.
- Do not extract preview frames from the video stream on the client.
- Do not request a new image for every drag position.
- Do not enable this UI for For You until design confirms the layout.

Future seek thumbnail service boundary:

- The playback source API may later return `previewSpriteUrl`,
  `thumbnailIntervalSeconds`, `columns`, `rows`, and `duration`.
- The client should map `seekPreviewPosition` to the correct sprite cell.
- Sprite/VTT image metadata should integrate with the video source and CDN cache
  model, not with widget-only state.

Phase 4.5 defer:

- Real thumbnail sprite generation.
- Client-side video frame extraction.
- For You seek preview UI.
- Full control overlay auto-hide.
- Playback progress persistence.
- Loading animation on the progress track.

### Phase 4.6: Player Loading Polish

This phase is a small follow-up after Phase 4.5. It should focus only on the
loading feel of the progress track.

Progress track loading animation:

- When the player is opening, waiting for the first frame, or buffering, show a
  lightweight loading animation on the progress track.
- Use an indeterminate short segment or subtle shimmer on the track.
- Before the first frame, the animation should help communicate that playback is
  loading.
- After the first frame, keep the current video frame visible and show the
  loading animation only on the progress track.
- During normal playback, show real progress and buffered progress without the
  loading animation.
- During seek dragging, prioritize the seek preview, time bubble, and thumbnail;
  do not show the loading animation at the same time.
- Do not show the loading animation for error, locked, or unavailable states.
- Keep this visual local to `PlayerSeekBar` or nearby player UI widgets. Do not
  add playback source-of-truth state for a purely visual animation.

### Phase 5: HLS Source Preload And Weak-Network MVP

- Retire the historical MP4 whole-file cache experiment.
- Remove `FilePlayerPlaybackCacheManager`, `PlaybackFileDownloader`, and local
  `.mp4.download` temp-file handling.
- Keep playback source resolution as the stable server replacement boundary.
- Open remote HLS/m3u8 URLs directly.
- Keep `preloadAround()` source/preload-only. It does not create media player
  sessions and cannot produce audio.
- Keep preload cancellation wired to hidden tab, single drama dispose, and
  provider dispose through `releasePending()`.
- Add `PlaybackProgressRepository` and an in-memory MVP implementation.
- Single drama sessions save local position/duration and restore the same
  episode on re-entry when the saved position is resumable.
- For You does not restore progress across sessions yet; it only keeps the
  current playback session state.

### Phase 5.1: HLS Preload State Machine

- Add `PlaybackPreloadStatus` with `pending`, `success`, `failed`, and
  `cancelled`.
- Add `PlaybackPreloadState` so controller state can distinguish active,
  successful, failed, and cancelled preload work.
- Keep `preloadedItemIds` as a convenience field for successful preload items
  only.
- Keep preload implementation mocked with a delay; do not perform real HTTP in
  this phase.
- `preloadAround()` remains the scheduler and generation guard. It chooses
  candidates, writes pending state, records success or failure, and prevents late
  completion from stale generations.
- `pauseForVisibility()`, `disposeSession()`, fast swipes, and provider dispose
  continue to release pending preload work.
- Preload failures must not affect the current playback status or trigger the
  player error UI.

### Phase 5.2: HLS Playlist Prefetch MVP

Implemented. This phase warms the next HLS playlist before the user swipes to
it, while keeping the current playback stable.

- Add a small `HlsPlaylistPreloader` behind `PlayerPlaybackPreloadManager`.
- Perform a real HTTP GET for the m3u8 playlist only.
- Use a short timeout, defaulting to 4 seconds.
- Support cancellation through the existing preload release path.
- Treat prefetch failure as a preload failure only. It must not affect the
  current playing item or show the player retry UI.
- Keep `PlayerPlaybackController.preloadAround()` as the scheduler. It should
  not contain HTTP details.
- Keep `PlaybackPreloadState` as the state surface for pending, success, failed,
  and cancelled preload work.
- Do not create a media player session during preload.
- Do not play, prepare audio, or produce sound during preload.
- Do not download segments or store HLS files locally in this phase.
- If the playlist is a master playlist, detect it and safely mark playlist
  prefetch as complete without segment handling. Variant selection is deferred.
- If the playlist has relative segment URLs, parsing/resolving may be tested,
  but segment preheat remains deferred.
- Keep tests isolated from the network by overriding the HTTP client/preload
  manager with fakes.

Expected tests:

- Playlist GET success marks preload success.
- Timeout marks preload failed without touching current playback.
- Cancelled pending preload does not late-write success.
- Fast generation changes do not late-write stale preload state.
- Locked, unavailable, and null-source items do not prefetch.
- For You and single drama preload states remain isolated.

### Phase 5.3: Vertical Switch First-Frame Latency MVP

Implemented. Playlist prefetch only warms the m3u8 text response; it does not
guarantee that `media_kit` has opened the playlist, requested segments, decoded
frames, or produced the first video frame. This phase targets the first-frame
wait after vertical PageView switches in For You and single-drama playback.

- Add lightweight playback timing diagnostics in `PlayerPlaybackController`.
  Timing covers source resolve start/end, preload start/end/status, media open
  start/end, first frame from `widthStream`, buffering start/end, and errors.
- Keep timing in an internal bounded list and optionally print it in debug builds
  with `--dart-define=PLAYER_TIMING_LOGS=true`.
- Add `PlayerPlaybackPrepareManager` for a single next prepared session.
- Prepare only the nearest next candidate selected by `preloadAround()`.
- Prepare resolves the playback source and opens an independent
  `PlayerPlaybackSession` with `play: false`.
- Prepared sessions do not create UI, do not call `play()`, and must not produce
  audio.
- On matching `playItem()`, the prepared session is taken over, stream listeners
  are rebound, the old current session is paused/disposed, and playback resumes
  without repeating a normal `open()` on the old session.
- Locked, unavailable, and null-source items are not prepared.
- Prepare failures are logged/degraded and never affect the current playback
  state.
- `pauseForVisibility()`, `disposeSession()`, provider dispose, and fast
  generation switches release stale prepared sessions.
- For You and single-drama controllers each own their own prepare manager, so
  prepared state does not cross sessions.

Phase 5.3 limits:

- At most one prepared next session.
- No multi-player pool.
- No HLS segment cache.
- No offline download.
- No CDN-specific optimization or real backend coordination yet.

### Phase 5.4: Playback Timing Export And Session Window MVP

Implemented. This phase keeps Phase 5.3's prepared-session idea, but makes it
more useful for vertical swiping by retaining a tiny playback session window.

- Keep playback timing diagnostics in a bounded in-memory list that is available
  in release builds through `PlayerPlaybackController.timingEvents` and
  `exportTimingReport()`.
- Timing still covers source resolve, playlist preload, media open, first frame,
  buffering, and error/retry boundaries. Debug printing remains optional with
  `--dart-define=PLAYER_TIMING_LOGS=true`.
- Upgrade the single next prepared session into a small session window:
  previous paused session, current playing session, and next prepared session.
- Keep at most two non-current window sessions, so total player sessions should
  stay around 2-3.
- When swiping to a prepared item, take over that session and retain the old
  current session in a paused state for quick swipe-back.
- Only the current session may play. Previous and next sessions are explicitly
  paused after prepare/retain and must not produce audio.
- Locked, unavailable, and null-source items do not enter the window.
- Fast swipes, stale generations, hidden tabs, player disposal, provider
  disposal, and memory pressure release prepared/retained sessions.
- Session-window failures degrade to the normal remote HLS open path and do not
  affect current playback.

Phase 5.4 limits:

- No segment preheat.
- No persistent HLS cache.
- No multi-session pool beyond the small previous/current/next window.
- No user-facing timing export UI yet; export is a controller API for debugging
  and QA builds.

### Phase 5.5: Device Timing Review And Window Tuning

Implemented. This phase keeps the client-only scope and tunes the session
window using the diagnostics added in Phase 5.4.

- `--dart-define=PLAYER_TIMING_LOGS=true` now prints timing in release builds
  too. Timing output is no longer gated by debug mode.
- Timing report lines include `session=<sessionKey>`, item id, event name,
  elapsed ms, source, window hit/miss information, first-frame readiness, and
  release/dispose reasons where applicable.
- Add explicit session-window events:
  - `list entry normal open`
  - `window miss fallback open`
  - `prepared hit next`
  - `retained hit previous`
  - `previous retained`
  - `prepare end` with `next prepared`
  - `old session disposed`
  - `session window release` with `hidden`, `dispose`, `memory pressure`,
    `provider dispose`, or stale-generation reasons.
- Prepared sessions keep listening for `widthStream` until takeover or release,
  so `firstFrameReady` can become true even if the first frame arrives after
  `open(play: false)` returns.
- Taking over a prepared session cancels its lightweight first-frame listener
  before binding the real playback listeners.
- Retained previous sessions snapshot position, duration, buffered position, and
  first-frame state. Swiping back to a retained item restores that state and
  avoids a repeat source resolve/open while the item remains in the window.
- Duplicate prepare requests for the same item are ignored while one prepare is
  pending, preventing a second prepare from invalidating the first session and
  causing an avoidable window miss.
- `PlayerPage` now sequences current-item playback before neighbor preload, so
  initial entry and swipes have a stable current item/source before preparing
  adjacent items.
- Stale prepared completion releases only the stale prepared item instead of
  clearing the entire window. Hidden tab, player dispose, provider dispose, and
  memory pressure still release the full non-current session window.

Device timing conclusion:

- Release APK timing logs confirmed the diagnostic path works on device. The
  first sampled list-entry path showed source resolve around 40-60 ms and media
  open around 20-100 ms, while first frame could still take multiple seconds
  under the sampled network/CDN path.
- The first device timing pass also exposed duplicate prepare calls and frequent
  `window miss fallback open` during fast swipes; this phase adds same-item
  prepare dedupe and play-before-preload sequencing to reduce those misses.
- Unit tests confirm the intended client behavior: next prepared hits do not
  repeat normal open, previous retained hits keep progress, stale prepared
  sessions cannot take over, duplicate prepare is ignored, and previous/next
  sessions are paused.
- If real-device logs still show long waits after a `prepared hit next`, the
  likely bottleneck is media first-frame/segment fetch rather than source
  resolve. If logs still show frequent `window miss fallback open`, the problem
  is session window coverage/release timing.
- Remaining first-frame slowness after a successful prepared hit will likely
  require CDN/HLS cooperation or a future segment-preheat phase.

### Phase 5.6: First Segment Preheat MVP

Implemented. This phase keeps the existing previous/current/next session window
and adds a narrow HLS first-segment preheat path to test whether startup
latency is dominated by playlist/segment fetch and first-frame decode rather
than source resolve or media open.

- `HlsPlaylistPreloader` still starts from the resolved remote HLS/m3u8 URL.
- If the playlist is a master playlist, the preloader selects the lowest
  bandwidth variant it can read and fetches that media playlist.
- If the playlist is already a media playlist, it parses segment lines directly.
- Relative variant and segment URLs are resolved against the playlist URL.
- The preloader GETs only the first one or two media segments. It does not
  persist them to disk, rewrite playlists, or expose a local cache URL.
- Preheated bytes are capped with `maxPreheatBytes` so this remains a bounded
  startup experiment instead of background downloading.
- Hidden tab, single-player disposal, provider disposal, fast-swipe generation
  changes, and explicit preload release still cancel pending playlist/segment
  work. Late completions return cancelled or are ignored by the controller.
- Locked, unavailable, and null-source items remain outside resolve, preload,
  and segment preheat.
- Preload diagnostics now include master playlist fetch, media playlist fetch,
  segment preheat start/end, segment bytes, and max-byte-stop markers. These
  details flow into preload timing logs for release timing review.
- Segment preheat failure marks only that preload item as failed. It does not
  alter current playback state, auto-next behavior, or the session window.

Phase 5.6 limits:

- No local HLS segment cache.
- No playlist rewriting or local proxy.
- No offline download.
- No signed URL refresh.
- No Wi-Fi/cellular policy.
- No multi-variant intelligence beyond choosing the lowest declared bandwidth.

### Phase 5.7: Fix Session Window Miss On Normal Open

Implemented. Device logs from the Phase 5.6 release showed that slow vertical
switches were not only a first-frame/CDN problem. The session window was also
missing:

- `preload candidates` skipped the next episode with `current_source` because
  EP.01 and EP.02 used the same mock HLS URL.
- `window miss fallback open` reused the current media session for normal open,
  so the previous episode was never retained in the window.
- Swiping back therefore repeated source resolve/open instead of producing
  `retained hit previous`.

This phase fixes the client-side window miss before adding any heavier cache:

- `preloadAround()` no longer skips a different item just because it shares the
  current HLS URL. It only skips current item, locked, unavailable, and null
  source candidates.
- Before a normal fallback open for a different item, the current session is
  paused, its stream listeners are detached, its first-frame/progress snapshot
  is retained as `PreparedPlaybackSessionKind.retained`, and a fresh current
  session is created for the new normal open.
- If the new normal open fails, the retained previous session stays in the
  window so a user can swipe back and hit the previous session.
- Only the current session is allowed to play. Retained previous sessions are
  paused before entering the window.
- Tests cover same-source different-item candidates, normal-open retain,
  previous hit on swipe back, no repeat source resolve/open on retained hit,
  retained pause/no-audio behavior, normal-open failure retaining previous, and
  the previous/current/next window limit.

Phase 5.7 limits:

- No HLS segment cache.
- No offline download.
- No UI changes.
- No service integration.
- No window size expansion beyond previous/current/next.

### Phase 5.8: Prepared First-Frame Warm-Up

Implemented. Release logs after Phase 5.7 showed session-window hits such as
`prepared hit next`, but `firstFrameReady=false` on takeover. That suggests
`media_kit` can open an HLS source with `play: false` without decoding a video
frame on Android, so the prepared session still needs to wait for the first HLS
segment and decoder frame after takeover.

This phase changes only the prepared-session strategy:

- Prepared sessions now warm up muted: set volume to `0`, open the source with
  `play: true`, then pause after the first width/first-frame signal or a short
  timeout.
- After warm-up pauses the prepared session, volume is restored to `100` so a
  later takeover can play normally.
- If takeover happens while warm-up is still pending, the warm-up pause is
  cancelled so it cannot pause the new current session after takeover. The
  controller also restores volume before calling `play()`.
- Hidden tab, player dispose, provider dispose, stale generation, and explicit
  release paths cancel pending warm-up and dispose prepared sessions.
- Timing logs now include `prepare warm-up start`, `prepare warm-up end`,
  `prepare warm-up cancelled`, and `prepare warm-up failed` so device logs can
  distinguish prepared-window hit from first-frame readiness.
- Tests cover muted warm-up, no-audio prepare, takeover before warm-up timeout,
  late first-frame updates, hidden/dispose release, and prepared-session
  isolation.

Phase 5.8 limits:

- No UI changes.
- No segment cache or local HLS proxy.
- No service/CDN integration.
- No guarantee that every CDN/HLS source decodes a frame during muted warm-up;
  device timing remains the source of truth.

### Phase 5.8.1: Audio Playing But Poster Still Visible

Implemented. Device testing showed a second first-frame edge case: audio could
start and position could advance while `widthStream` had not emitted yet, so
`hasFirstFrame=false` kept the video opacity at zero and left the poster visible
over an already-playing session.

This phase separates video-surface visibility from first-frame readiness:

- `PlayerPage` now treats playable/current/non-error media as a mountable video
  surface independently from `hasFirstFrame`.
- Before the first frame, the poster remains for opening/loading. Once playback
  is `playing` or position advances, the video surface is shown with loading
  overlay instead of leaving the poster permanently on top.
- `hasFirstFrame` still controls when loading fades and when pause/play center
  affordances are shown.
- Error, locked, and unavailable states continue to hide the playable video
  surface.
- Timing now records `playing event while hasFirstFrame=false`,
  `position advancing while hasFirstFrame=false`, and
  `video surface shown before firstFrame` so release logs can identify this
  mismatch.
- Prepared warm-up timeout is raised to 4000 ms to give HLS sources more time to
  decode a first frame before takeover.
- EP.01/EP.02 mock HLS sources remain distinct public stable fixtures for A/B
  testing prepared-next and retained-previous timing.

Phase 5.8.1 limits:

- No UI redesign.
- No segment cache.
- No media_kit pipeline changes beyond prepared warm-up and surface visibility.

### Phase 5.8.2: Playback Timing Trace Enhancement

Implemented as a diagnostic-only phase. This phase does not change playback
strategy, session-window size, preload strategy, or player UI. It makes release
timing logs easier to read across repeated Android device runs.

Trace fields:

- Each `playItem()` request now starts a `playbackTraceId` scoped to the
  `sessionKey`, for example `single-drama-a-1-001`.
- Timing events include `trace`, `sourceLabel`, `sinceTraceStartMs`, and
  `sinceUserActionMs` in both `exportTimingReport()` and release logs enabled
  by `--dart-define=PLAYER_TIMING_LOGS=true`.
- Source labels are derived from the mock HLS source URL, with stable playback
  fixtures separated from special-purpose sources: `mux-fast`,
  `mux-tears-stable`, `apple-bipbop-low-stable`, `aspect-ratio-16x9-test`,
  `aspect-ratio-4x3-test`, `unstable-source-test`, `slow-source-test`,
  `business-lz15`, or `unknown-hls`.
- Home card entry passes a `home_card_tap` trigger and user-action time through
  the player route query so first-entry traces can show time since tap.
- Player page events record PageView scroll start, PageView page changed,
  auto-next animation start/end, and retry taps. The next `playItem()` trace
  consumes that trigger.

Trace timeline coverage:

- `trace start`
- `play item request`
- `trace generation assigned`
- window take/result events, including prepared-next, retained-previous, and
  miss fallback open
- source resolve start/end
- HLS preload start/end with playlist/segment diagnostics from the preload
  result
- media open start/end
- `session play called`
- `playingStream true/false`
- position advancing before first frame
- first frame received
- video surface shown before first frame
- error

Audio/video mismatch diagnostics:

- `playing event while hasFirstFrame=false`
- `position advancing while hasFirstFrame=false`
- `video surface shown before firstFrame`
- `firstFrameDelayAfterPlayingMs`
- `firstFrameDelayAfterPositionMs`
- `audioPlayingBeforeFirstFrameMs`

Device test method:

1. Build with `flutter build apk --release --dart-define=PLAYER_TIMING_LOGS=true`.
2. Install the release APK on the Android test device.
3. Run 3-5 passes for Home card entry, single-drama swipe next, single-drama
   swipe previous, For You vertical swipes, auto-next, and retry.
4. Compare `sinceUserActionMs`, source label, window result, media open, first
   frame, and audio-before-first-frame fields per trace.

Phase 5.8.2 limits:

- No performance conclusion is recorded here; review agent should add that
  after device log review.
- No UI change.
- No HLS segment cache or local proxy.
- No service integration.

### Phase 5.8.3: Review Consolidation And Next Work

Review status after Phase 5.8.2 device testing and parallel code/function
review:

- No P0 blocker was found.
- Default mock HLS sources were moved away from the slow Unified Streaming
  fixture. The default first episodes now use `mux-fast`, `mux-tears-stable`,
  and `apple-bipbop-low-stable`.
- Android release timing showed `mux-fast` first frame around 3-6 seconds on the
  test device, while prepared/retained session hits usually resume within tens
  of milliseconds once `firstFrameReady=true`.
- Previous/current/next session window behavior is acceptable for primary
  gestures. Fast multi-step backtracking can still miss after a retained session
  is trimmed, but this is an expected limit of the current window size.
- Single-player exit, For You tab switching, and app hidden/background flows
  stop playback and release prepared sessions.

Next implementation priorities:

1. Video fit and aspect-ratio policy. Device review showed non-vertical sources
   can be heavily cropped under cover-style fit. Add a small policy for `cover`
   versus `contain` based on source dimensions or mock/source metadata.
2. Recoverable HLS error handling. `errorStream` currently routes most playback
   errors to fatal playback error. Add a minimal error kind/state so transient
   network/HLS segment failures can keep the current frame/surface and avoid
   dropping to poster/error when playback can continue.
3. Timing trace helper extraction. `PlayerPlaybackController` is still
   acceptable as the playback orchestrator, but timing trace fields and
   formatting should move to a helper to reduce controller size without touching
   playback sequencing.

Keep deferred for now:

- Expanding the prepared-session window beyond previous/current/next.
- Local HLS cache or local proxy.
- Large `PlayerPlaybackController` decomposition beyond timing trace extraction.
- For You-specific playback fork.

### Phase 5.9: Visual Fit, Recoverable Error, Timing Trace Cleanup

Implemented as a small player-only polish pass after the session window and mock
source validation work.

Completed:

- Added a lightweight video fit policy using episode/source aspect-ratio
  metadata. Vertical or near-vertical sources keep immersive `cover`; obvious
  non-vertical sources such as 16:9 and 4:3 use `contain` over the existing
  poster/background layer so test fixtures are not aggressively cropped.
- Added minimal playback error classification:
  - `recoverableNetwork` for transient HLS/network/segment style errors.
  - `sourceResolve` for playback source resolution failures.
  - `mediaFatal` for unrecoverable media open/playback failures.
  - `unknown` as a conservative fallback.
- Recoverable HLS errors after first frame no longer clear `hasFirstFrame` or
  immediately force the fatal retry UI while playback position is still moving.
  The current video surface stays mounted and the existing loading/track loading
  affordance can cover temporary network churn.
- Extracted timing event storage, source labeling, trace lifecycle, user action
  correlation, formatting, and release logging into
  `PlayerPlaybackTimingTrace`. `PlayerPlaybackController` still owns playback
  sequencing and calls the helper through `record(...)` / `exportReport()`.

Still deferred:

- Runtime dimension-based fit changes from native video size streams. The MVP
  uses mock/source metadata first.
- Consecutive transient error backoff and retry budgets.
- CDN/HLS segment cache, local proxy, and offline download.
- Larger playback-controller decomposition beyond timing trace extraction.

### Phase 5.9.1: Mock HLS Source Stabilization

Device validation after Phase 5.9 showed the playback chain is healthy, but the
default mock source list still allowed special-purpose HLS fixtures into the
normal episode cycle. In particular, a non-default source could produce
`firstFrameReady=false` / `positionMs=0` and make product validation look like a
player regression.

Completed:

- Default generated episodes now cycle only the stable playback fixtures:
  - `mux-fast`: `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
  - `mux-tears-stable`: `https://test-streams.mux.dev/tos_ismc/main.m3u8`
  - `apple-bipbop-low-stable`:
    `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8`
- Special-purpose fixtures remain available in `mockPlayerVideoAssets`, but do
  not enter the default episode chain:
  - At least 20 remote HLS `.m3u8` fixtures are kept for playback tests and
    source A/B validation. Direct MP4 files are intentionally excluded.
  - `slow-source-test` for slow first-frame / bad-network validation.
  - `aspect-ratio-16x9-test` for contain/fit validation.
  - `aspect-ratio-4x3-test` for contain/fit validation.
  - `unstable-source-test` for intentionally suspect source behavior.
  - Apple, Mux, Shaka, Akamai, JW, and Unified Streaming HLS fixtures for
    playlist/parser, timing, and fallback source checks.

Validation rule:

- Playback experience tuning should use only the default stable source chain.
- Slow, unstable, and aspect-ratio fixtures should be selected explicitly by a
  focused test/profile. If stable sources still cold-start slowly, the next
  investigation should target HLS first segment, bitrate, CDN behavior, and the
  media_kit first-frame pipeline rather than papering over the delay in UI.

### Phase 5.10: Android Safe Area And Prepared First Frame Tuning

Implemented as a focused player-only pass after Android release timing showed
stable retained/prepared session hits but two remaining polish issues:

- 16:9 `contain` playback could look vertically off-center on Android three-key
  navigation because the video fit container still included the player bottom
  control frame.
- `mux-tears-stable` could hit a prepared session with `firstFrameReady=false`,
  so takeover reused the prepared session but still needed clearer diagnostics
  around whether the prepared player had actually opened or advanced playback.

Completed:

- Single-drama playback now computes an explicit video viewport that excludes
  the bottom player controls and system bottom inset before applying video fit.
  This keeps 16:9 and 4:3 `contain` sources centered in the visible playback
  area without changing the immersive 9:16 `cover` policy.
- For You keeps its safe-area-only viewport policy, so bottom-tab feed playback
  is not coupled to the single-drama membership/download frame.
- Viewport behavior is covered by widget tests for single drama and For You.
- Prepared warm-up logs now include open start/completion, playing stream,
  buffering stream, width stream, position advance, timeout, and pause events.
- Prepared sessions track `isOpened`, `hasFirstFrame`, and
  `hasPlaybackAdvanced`. If width/first-frame reporting is late but playback has
  opened or advanced, takeover still reuses the prepared session instead of
  falling back to a normal source resolve/open path.
- Session window trimming during `preloadAround()` is awaited so stale retained
  sessions are released deterministically and the window remains bounded to the
  intended previous/current/next set.

Current conclusion:

- A prepared hit with `firstFrameReady=false` can still be a useful warm session
  if the media session opened and playback advanced. The UI should keep the
  loading overlay until first frame, but the playback path should not duplicate
  source resolve/media open.
- If a stable source still has slow first frame after this tuning, the next
  investigation should stay in the HLS first segment, bitrate, CDN behavior, or
  media_kit first-frame pipeline. It should not be treated as a layout/safe-area
  issue unless screenshots show a new visual regression.

### Phase 5.11: Cold Start First Frame Optimization Review

Review status after Phase 5.10 Android validation:

- EP.01 cold start still takes roughly 3 seconds to first frame even though
  source resolve and media open are both tens of milliseconds.
- Prepared next and retained previous paths are healthy, so the remaining
  visible wait is concentrated in the first playback of the first item.
- The likely slow section is HLS startup outside the Dart source resolver:
  playlist/variant selection, first segment request, keyframe/decode pipeline,
  CDN latency, or media_kit's first-frame reporting behavior.

Timing coverage added:

- Player page lifecycle now records `player page init` and
  `player page first build`.
- Feed loading now records `feed load start` and `feed load end`, including
  mode, item count, current index, elapsed time, and error state.
- Playback position now records `position first advanced` independently from
  the existing `position advancing while hasFirstFrame=false` diagnostic.
- Existing timing remains in place for home card tap/user action correlation,
  `play item request`, source resolve start/end, HLS prefetch diagnostics, media
  open start/end, `session play called`, buffering start/end, first frame, and
  video surface display before first frame.

Cold-start assessment:

- The current player route already passes the Home tap timestamp into the
  playback trace. With the new page/feed timing nodes, release logs can separate
  route/build/feed overhead from media startup.
- Current playback open is already triggered as soon as the first feed item is
  available. Moving it much earlier inside `PlayerPage` is unlikely to recover a
  multi-second first-frame delay unless feed loading itself shows unexpected
  latency in device logs.
- Creating a media player on Home is not recommended for this MVP because it
  complicates lifecycle/audio safety and duplicates the session-window concerns
  outside the player feature.
- A lightweight Home playlist prefetch is the most reasonable client-side next
  step if timing confirms feed/route overhead is small: after Home feed load,
  prefetch only the first visible card's m3u8/first segment through the existing
  HLS preload boundary, cancel on category switch/refresh/leave, and do not
  create a media session or play audio.

Mock source notes:

- Default stable fixtures remain:
  - `mux-fast` for EP.01.
  - `mux-tears-stable` for EP.02.
  - `apple-bipbop-low-stable` for EP.03.
- `mux-fast` is still useful as the first default because it is stable and
  publicly reachable, but device logs should continue comparing its cold-start
  first-frame time against `mux-tears-stable` and
  `apple-bipbop-low-stable`. If one fixture is consistently faster without
  other regressions, default ordering can be changed in a later mock-only pass.
- Slow, aspect-ratio, and unstable fixtures must stay opt-in test profiles.

Client-side next options:

- Home playlist prefetch for one visible/default card only.
- Feed/route timing review using `PLAYER_TIMING_LOGS=true` before changing
  playback strategy.
- Minor loading/poster timing polish only if logs show UI overlay hides the
  video surface after playback has already advanced.
- Mock source ordering adjustment if repeated device timing shows one stable
  fixture is a better cold-start default.

Server/CDN/HLS items that remain outside this client pass:

- HLS segment duration and first segment byte size.
- Keyframe alignment and startup GOP.
- Startup variant/bitrate selection.
- Playlist and segment `Cache-Control`.
- Signed URL refresh and redirect latency.
- CDN edge behavior for first playlist and first media segment.

### Phase 5.12: Startup Preload Architecture

Implemented as the long-term boundary for cold-start preheating. The goal is to
let Home express "the first visible item is worth preloading" without coupling
Home to media sessions, `VideoController`, or media_kit.

Architecture:

- `PlayerStartupPreloadController` owns startup preload state:
  - `idle`
  - `pending`
  - `success`
  - `failed`
  - `cancelled`
- Home passes the first loaded `Drama` candidate to the startup preload
  controller. It does not resolve playback URLs, create a player, hold a
  `VideoController`, or import media_kit.
- The startup controller converts the drama candidate through the existing
  player feed/source repositories, then calls the existing
  `PlayerPlaybackSourceRepository.preload(...)` path. This keeps startup
  preheating aligned with the HLS source/playlist/first-segment preload
  pipeline.
- The startup controller has its own generation guard so category switches,
  refreshes, disposal, and late completions cannot write stale success state.
- Startup preload failure is isolated. It records failed state and timing, but
  it never drives the real playback controller into error.
- `PlayerPlaybackController.playItem(...)` checks the current startup preload
  state and records either `startup preload hit on playItem` or
  `startup preload miss on playItem`. A hit is diagnostic only; real playback
  still proceeds through the normal player lifecycle because Dart HTTP prefetch
  is not guaranteed to be shared with media_kit internals.

Home integration:

- Initial Home feed success preloads only the first item in the loaded list.
- Category switch, retry, and Home disposal cancel pending startup preload.
- Pagination does not trigger additional startup preload work.
- Startup preload does not affect Home loading/error/empty UI.

Release timing to verify with `PLAYER_TIMING_LOGS=true`:

- `startup preload request`
- `startup preload start`
- `startup preload success`
- `startup preload failed`
- `startup preload cancelled`
- `startup preload hit on playItem`
- `startup preload miss on playItem`

Expected device review:

- Confirm Home feed load to startup preload success timing.
- Confirm Home tap to `playItem` reports startup hit or miss.
- Compare EP.01 cold-start first frame before/after startup preload.
- If hit is present but first frame remains slow, the remaining bottleneck is
  likely still media_kit/HLS first-segment/decode/CDN behavior rather than
  route/feed/source-resolve overhead.

Deferred:

- Home media session warm-up. This remains intentionally out of scope because it
  adds audio lifecycle risk outside the player.
- Startup preload for more than one visible card.
- Network-aware preload policy.
- Real backend source API and signed URL refresh.
- Local HLS cache, segment cache, and offline download.

### Phase 5.13: Preload Scope Isolation

Implemented a scope split between Home startup preload and in-player playback
preload. Both scopes continue to use the same HLS source/preload abstractions,
but they no longer share pending request, generation, or `releasePending()`
state.

Architecture:

- Playback preload remains owned by `PlayerPlaybackController` through
  `playerPlaybackPreloadManagerProvider` and
  `playerPlaybackSourceRepositoryProvider`.
- Startup preload now uses independent provider instances:
  `startupHlsPlaylistPreloaderProvider`,
  `playerStartupPreloadManagerProvider`, and
  `playerStartupPlaybackSourceRepositoryProvider`.
- Home category switch, retry, and disposal only cancel the startup preload
  scope. They must not release Player next/previous preload or the playback
  session window.
- Player hidden, dispose, provider disposal, and memory pressure only release
  the playback preload scope plus the playback session window. They must not
  cancel Home startup preload work.
- Late completion and generation guards stay per scope, so startup and playback
  preload can independently finish as success, failed, or cancelled without
  writing into each other's state.

Tests added/updated:

- Startup cancel does not cancel playback preload.
- Player pause/visibility release does not cancel startup preload.
- Startup and playback preload can run at the same time and resolve to
  independent success/failed/cancelled states.
- Startup hit/miss timing remains visible on `playItem`.
- Existing previous/current/next session window behavior remains covered by the
  player playback controller suite.

Device conclusion carried from Phase 5.12:

- A startup preload hit is useful timing evidence, but it does not reliably
  reduce media_kit first-frame latency because Dart HTTP prefetch is not
  guaranteed to share the player pipeline cache. If cold start remains slow, the
  next investigation should focus on HLS/CDN, media_kit first-frame behavior,
  or a deliberate local HLS cache/proxy design rather than UI-layer patches.

Deferred:

- Home media session warm-up.
- Local HLS segment cache or proxy.
- Signed URL refresh and real backend source API.
- Network-aware startup preload policy.

### Phase 5.18 Backlog: Configurable Preload Policy

The next preload tuning pass should make lightweight HLS preload counts
configurable without expanding the heavy media-session window.

Why:

- Different surfaces have different preload needs. Home startup, For You feed,
  and single-drama episode playback should not all share one hardcoded count.
- HLS playlist/first-segment preload is cheaper than prepared media sessions and
  can be tuned more safely.
- Prepared media sessions are expensive and carry audio/memory risk, so they
  should remain capped at previous/current/next until device evidence proves a
  different policy is required.

Planned config boundary:

- Add a typed `PlayerPreloadConfig` and provider with local defaults.
- Suggested fields:
  - `homeStartupPreloadCount`, default `1`.
  - `singleDramaForwardHlsPreloadCount`, default `1`.
  - `singleDramaBackwardHlsPreloadCount`, default current behavior.
  - `forYouForwardHlsPreloadCount`, default `1`, tunable to `2` after timing
    review.
  - `forYouBackwardHlsPreloadCount`, default conservative.
  - `maxConcurrentHlsPreloads`, default `1`.
  - `maxPreloadBytes`, default aligned with current HLS preheater.
  - `preloadTimeout`, default aligned with current HLS preheater.
  - `preparedForwardSessionCount`, default and capped at `1` for now.
  - `retainedBackwardSessionCount`, default and capped at `1` for now.
- Use this config only for candidate selection and HLS preload scheduling in the
  first implementation.
- Do not use it to increase prepared media-session counts in the same phase.
- Keep the config local for now; preserve the provider boundary so a future
  server or remote-config policy can supply it later.

Code comment requirements:

- Every config field should have a short doc comment explaining whether it
  affects HLS HTTP preload or media-session preparation.
- Comments must include the default intent and resource risk.
- Comments should say whether the value is safe to tune remotely later.
- Avoid comments on obvious implementation lines; document the policy knobs
  where future developers will tune them.

Testing requirements:

- `forwardHlsPreloadCount=2` preloads the next two playable candidates.
- backward preload count handles previous playable candidates without affecting
  current playback.
- locked, unavailable, and null-source items are skipped and do not consume an
  effective preload slot.
- increasing HLS preload counts does not increase the prepared media-session
  window.
- For You and single-drama configs can diverge without sharing state.
- startup preload remains scoped and does not cancel playback preload.

### Player Visual Fit Backlog: Video Crop And Aspect Ratio

Observed during device playback review. Some videos may not appear fully inside
the player frame because the current video surface is optimized for immersive
full-screen playback and uses cover-style fitting. This is a product/visual
policy issue. After Phase 5.8.2 review, this is promoted to the next P1 player
polish item.

Track this in the next player polish implementation:

- Decide the product rule for non-9:16 sources:
  - immersive full-screen first, allowing crop;
  - complete content first, allowing black bars;
  - or adaptive fit based on source aspect ratio.
- Record source video dimensions and container dimensions in timing/debug logs
  when available.
- Prefer service-provided `aspectRatio`, `width`, and `height` once real source
  APIs exist; fall back to media stream dimensions from the player.
- Keep For You and single-drama strategies configurable separately because the
  feed may prioritize immersion while detail playback may prioritize complete
  content.
- Validate with real-device screenshots before changing the default fit.

Do not change the default video fit as part of Phase 5.8.x unless the product
decision is confirmed. Switching everything to contain too early may make the
short-drama experience feel less immersive.

### Player Visual Safe Area Backlog: Android Navigation Bar

Observed during device playback review on Android with system navigation
buttons. The video frame may be visually affected by the bottom system
navigation bar: the playable image can look off-center, and non-9:16 `contain`
sources make the issue easier to notice.

Track this as a P1 player visual verification item after mock source
stabilization:

- Re-test on Android gesture navigation and three-button navigation.
- Compare the video layout against `MediaQuery.padding`, `viewPadding`, and
  `viewInsets` to confirm whether the system navigation bar is included in the
  video fit container.
- Check the bottom player frame, progress bar, membership/download row, and
  system navigation bar spacing together; do not fix only the `Video` widget in
  isolation.
- Validate both immersive 9:16 `cover` and 16:9/4:3 `contain` sources with
  screenshots.
- If needed, introduce an explicit playback viewport that excludes system
  navigation controls while keeping overlay controls aligned with the visible
  player area.

Do not implement this immediately. First finish the stable mock-source pass,
then run a focused safe-area test so the fix is based on screenshots rather
than guesswork.

Phase 5 defer:

- Phase 5.18 configurable preload policy is implemented.
  - `PlayerPreloadConfig` holds local defaults for Home startup preload,
    single-drama and For You HLS preload counts, max concurrent HLS preloads,
    max preload bytes, timeout, and media-session prepare/retain caps.
  - `playerPreloadConfigProvider` currently returns local defaults and is the
    future remote-config/server-policy boundary.
  - `preloadAround()` now uses configured forward/backward HLS counts and skips
    locked, unavailable, and null-source items without consuming preload slots.
  - HLS preloader timeout and byte budget are injected from the config for both
    playback and startup scopes without sharing pending/release state.
  - Prepared media-session window remains previous/current/next; increasing HLS
    preload counts does not expand prepared sessions.
- Phase 5.16 server/CDN playback source specification is captured in
  `docs/player-source-and-cdn-spec.md`.
  - The spec defines future playback source fields such as `hlsUrl`,
    `backupHlsUrls`, `expiresAt`, refresh info, duration, dimensions,
    aspect ratio, bitrate ladder, poster, preview sprite/VTT, subtitles,
    cache policy, preload policy, and access/DRM placeholders.
  - It documents HLS startup recommendations: small first segment, short segment
    duration, keyframe/GOP alignment, low-bitrate startup variant, compatible
    H.264/AAC encodes, and accurate aspect-ratio metadata.
  - It documents CDN requirements: cache headers, ETag/Last-Modified, Range
    support, short redirect chains, signed URL expiry semantics, edge cache
    expectations, and clear retry/error status meanings.
  - It connects server fields to client behavior for fit policy, seek preview,
    preload limits, source refresh, subtitles, cache eligibility, and retry.
  - It confirms the local HLS proxy spike should remain default-off and should
    not be productionized without a stronger design and timing proof.
- Phase 5.15 local HLS proxy/cache spike has an experimental implementation
  guarded by `PLAYER_HLS_LOCAL_PROXY_SPIKE=false` by default.
  - The spike starts a localhost proxy only when the feature flag is enabled.
  - It rewrites remote HLS playlists to localhost playlist/segment routes.
  - It caches proxied segment bytes in memory for the process lifetime.
  - It records proxy server start/stop, proxy source generation, playlist
    fetch, segment hit/miss, bytes, and remote fallback timing through the
    existing `PLAYER_TIMING_LOGS=true` path.
  - It falls back to the original remote HLS URL if proxy source generation
    fails.
  - It does not change the normal playback/session-window architecture and it
    is not a production cache.
  - Locked, unavailable, and null-source items still do not resolve, proxy,
    preload, or prepare media.
  - The spike should only be promoted if release-device timing shows meaningful
    first-frame improvement versus direct remote HLS playback.
  - Android release spike pass on `R58WC02B69R` with
    `PLAYER_HLS_LOCAL_PROXY_SPIKE=true` showed the proxy path working at the
    HTTP level: server start, playlist rewrite/fetch, segment fetch, and segment
    cache hit logs were emitted. However, the playback did not produce a stable
    first frame inside the sampling window and later segment proxy requests
    timed out. This is worse than the direct remote baseline from Phase 5.14
    (`mux-fast` first frame around 2.7-2.9s).
  - Current conclusion: do not promote the local proxy to production. A real
    local HLS proxy would need stronger runtime fallback, variant selection,
    playlist attribute rewriting such as init-map/key URIs, range handling,
    timeout policy, and quota/cache ownership before it can be reconsidered.
- Real playback source API and signed URL refresh.
- Real CDN header parsing and expiry reconciliation.
- HLS playlist and segment cache.
- Persistent HLS segment cache after segment preheat is proven useful.
- Multi-session prepared player pool.
- Offline download.
- Wi-Fi/cellular preload policy.
- Disk quota, LRU eviction, and cache size UI/debug tooling if local HLS cache is
  later introduced.
- Server progress reporting and cross-device resume.
- Android smoke verification unless playback behavior changes require it.

## Out Of Scope

- No real backend integration.
- No production-grade full video download cache for feed scrolling.
- No offline download feature.
- No DRM.
- No real payment, receipt validation, or entitlement issuing.
- No real playback progress reporting.
- No adaptive bitrate or manual quality selection.
- No requirement to run Android smoke tests on every change.

## Review Requirements

Each phase must pass:

```bash
dart format lib test integration_test
flutter analyze
flutter test
```

For phases that affect real audio lifecycle, manually verify on Android:

- For You playing, switch to Home: audio stops.
- For You playing, switch to My list: audio stops.
- For You playing, switch to Profile: audio stops.
- Single drama playing, navigate back: audio stops.
- App goes to background: audio stops.
