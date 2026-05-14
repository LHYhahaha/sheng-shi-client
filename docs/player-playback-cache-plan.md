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
- Playback controls are not complete: tap video to play/pause, control overlay,
  real progress, and seek are still pending.
- The Figma player design includes a drag-to-seek state with a stronger progress
  bar and time bubble.
- Reference short-drama players also include lightweight tap feedback, playback
  speed selection, a next-episode entry, and automatic next episode after
  completion.
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
- Support manual next episode in single drama playback.
- Support playback speed selection through a lightweight sheet.
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

### Next Episode

- Single drama playback should expose a lightweight `Next` entry.
- `Next` moves to the next feed item and lets the feed/playback pipeline start
  that item.
- If there is no next item, the entry should be hidden or disabled.
- For You should not gain the single-drama `Next` entry.

### Playback Completion

- Completion must use the media player's completed event, not
  `position >= duration`.
- `media_kit` exposes `player.stream.completed`; use that through
  `PlayerPlaybackSession.completedStream`.
- When the current item completes and the player is visible, the page may
  automatically move to the next item.
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
- Update `seekPreviewPosition` while dragging.
- Disable vertical page swiping while the user is dragging the progress bar.

Drag end:

- Seek to the target position.
- If playback was playing before dragging, continue playing.
- If playback was paused before dragging, remain paused.
- Save progress to the mock progress repository only.

## Preload Strategy

MVP preload:

- Preload `currentIndex + 1`.
- Optionally keep `currentIndex - 1`.
- Keep at most 2 preload sessions.
- Skip locked and unavailable episodes.
- Release stale preload sessions after fast swipes.
- Release preload sessions when leaving the player.
- Keep For You and single drama sessions isolated.

Do not download complete videos for feed scrolling.

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
- Add control overlay display and auto-hide behavior.
- Support For You and single drama player.

### Phase 3: Real Progress And Drag Seek

- Track position, duration, and buffered position.
- Replace fixed progress with real progress.
- Support drag seek.
- Show Figma-style time bubble while dragging.
- Disable vertical page swiping while dragging the progress bar.
- Save progress to mock progress repository.

### Phase 3.5: Completion, Speed, And Lightweight Playback Polish

- Add `completedStream`, `rateStream`, and `setRate` to
  `PlayerPlaybackSession`.
- Track `hasEnded` and `playbackRate` in `PlayerPlaybackController`.
- Add `setPlaybackRate(double rate)`.
- Add replay behavior for ended current source.
- Add `canGoNext` and `goNext()` to `PlayerFeedController`.
- Add single drama `Next` entry.
- Auto advance to the next item on completed playback when safe.
- Add speed selection sheet.
- Add short pause/play tap feedback without building a full control overlay.
- Do not add progress persistence, CDN/cache, or full For You controls in this
  phase.

### Phase 4: VideoSource And Cache Policy

- Add or finalize `VideoSourceRepository`.
- Add or finalize `PlaybackProgressRepository`.
- Add `VideoCachePolicy`.
- Mock signed URL expiry and refresh.
- Mock preload policy.
- Prepare for HLS, CDN cache, and HTTP Range integration.

## Out Of Scope

- No real backend integration.
- No full video download cache for feed scrolling.
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
