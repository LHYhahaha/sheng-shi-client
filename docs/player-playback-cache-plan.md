# Player Playback And Cache Plan

This plan covers Player and For You playback reliability, loading experience,
preload strategy, and future HTTP/CDN cache boundaries.

## Current Problems

- For You playback may continue with audio after switching to Home, My list, or
  Profile.
- Single drama playback may continue with audio after leaving the Player page.
- App inactive, paused, or detached states must pause playback.
- Switching videos can show a black screen while the next source is loading.
- Larger video files can delay the first frame.
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
- The single drama player back button still needs final Figma alignment.
- Reference short-drama players show a thumbnail preview while dragging the
  progress bar. The current seek UI only shows the time bubble.
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
- Prepare clear boundaries for HLS, CDN cache, HTTP Range, signed URLs, and
  cache policy.
- Keep mock data out of widgets and pages.

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
- `format`: `hls` or `mp4`
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

### VideoCachePolicy

Suggested fields:

- `allowPreload`
- `allowHttpCache`
- `allowDiskCache`
- `preloadStrategy`: `none`, `metadata`, `firstSegment`, `nextItem`
- `maxPreloadBytes`
- `maxCacheAge`
- `requiresAuth`
- `onlyWifi`
- `expiresAt`

### LocalPlaybackCacheManager

Responsibilities:

- `lookup(item, policy, remoteUrl)`
- `download(item, policy, remoteUrl)`
- `releasePending()`
- Return cache states for hit, miss, expired, downloading, and failed.

MVP implementation:

- Uses an in-memory mock cache.
- Simulates download completion with a short async delay.
- Keeps the playable source as the original remote URL until real local files
  exist, so `media_kit` remains able to play videos on device.
- Does not write large video files to disk.

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
- Optionally keep `currentIndex - 1`.
- Keep at most 2 preload sessions.
- Skip locked and unavailable episodes.
- Release stale preload sessions after fast swipes.
- Release preload sessions when leaving the player.
- Keep For You and single drama sessions isolated.

Do not download complete videos aggressively for feed scrolling. Phase 5 may
write a single resolved MP4 source into the app cache directory as an MVP cache
boundary, but production HLS/range caching remains deferred.

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

### MP4 Fallback

Server/CDN must support:

- Faststart MP4 with moov atom at the beginning.
- HTTP Range requests.
- CDN Range caching.
- H.264 + AAC for broad mobile compatibility.

Client strategy:

- Do not download the full MP4.
- Let the player and HTTP stack request ranges.
- Optionally check `Accept-Ranges` and `Content-Length`.

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

### Phase 4: VideoSource And Cache Policy

- Add playback source and cache boundaries:
  `PlayerPlaybackSourceRepository`, `PlaybackCachePolicy`,
  `PlaybackSource`, and `PlayerPlaybackCacheManager`.
- Add a mock playback source repository that resolves a playable URL, cache key,
  expiry, format, and codec hint from the feed item.
- Add an in-memory mock cache manager with hit, miss, expired, downloading, and
  failed behavior.
- Route `PlayerPlaybackController.playItem()` through source resolution before
  opening media.
- On cache hit, open the cached source directly.
- On cache miss or expired cache, simulate a download and then open the cached
  source.
- On resolve/download failure, keep the existing playback error and retry path.
- Keep locked, unavailable, and null-source episodes outside resolve/cache/open.
- Rework `preloadAround()` to prepare source/cache only. Preload no longer
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
- Production file download policy and cache quota management.
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
- Do not extract frames from MP4 on the client.
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

### Phase 5: Cache And Weak-Network MVP

- Add `FilePlayerPlaybackCacheManager` as the first local file cache
  implementation.
- Store downloaded playable MP4 sources under the app temp/cache directory using
  a stable cache-key filename.
- Persist lightweight cache metadata next to the media file:
  remote URL and expiry time.
- Resolve cache hit, miss, expired, and failed states through the existing
  `PlayerPlaybackCacheManager` boundary.
- On cache hit, prefer the local file path as `PlaybackSource.playableSource`.
- On cache miss or expired cache, download through an injectable
  `PlaybackFileDownloader`, then open the local file.
- On unsupported sources such as assets, keep the remote/source URL path and skip
  local disk caching.
- On cache or resolve failure, keep the existing playback error and retry path;
  retry re-runs source resolve/cache/open.
- Keep `preloadAround()` source/cache-only. It does not create media player
  sessions and cannot produce audio.
- Keep preload cancellation wired to hidden tab, single drama dispose, and
  provider dispose through `releasePending()`.
- Add `PlaybackProgressRepository` and an in-memory MVP implementation.
- Single drama sessions save local position/duration and restore the same
  episode on re-entry when the saved position is resumable.
- For You does not restore progress across sessions yet; it only keeps the
  current playback session state.

Phase 5 defer:

- Real playback source API and signed URL refresh.
- Real CDN header parsing and expiry reconciliation.
- HLS segment-aware caching and HTTP Range-aware MP4 caching.
- Disk quota, LRU eviction, and cache size UI/debug tooling.
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
