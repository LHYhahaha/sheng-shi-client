# Global Playback Resource System Plan

This document evaluates and designs a global playback resource orchestration
system for the short-drama client. It is a read-only architecture plan: no
business code, UI, playback logic, local HLS cache/proxy, or backend integration
is changed by this phase.

## 1. Current Code Assessment

The current player architecture is already split into useful boundaries:

- `PlayerPlaybackController`
  - Owns the real playback state: source, status, first frame, buffering,
    play/pause, seek, speed, completed, retry, visibility pause, and dispose.
  - Calls `PlayerPlaybackSourceRepository.resolve()` before normal open.
  - Calls `preloadAround()` for neighboring HLS preload and next prepare.
  - Keeps `PlayerPlaybackTimingTrace` release-build diagnostics.
- `PlayerPlaybackPrepareManager`
  - Owns the previous/current/next media-session window.
  - Creates real media sessions for prepared next and retained previous.
  - Does muted warm-up and records first-frame/playback-advanced state.
  - Must remain small because it holds real player/decoder/audio resources.
- `PlayerStartupPreloadController`
  - Is triggered from Home after first feed items are stable.
  - Resolves the first playable drama item and runs startup-scoped HLS preload.
  - Does not create a media session.
- `PlayerPreloadConfig`
  - Configures Home startup HLS preload, single-drama HLS preload, For You HLS
    preload, HLS byte budget, timeout, and effective media-session caps.
  - Keeps media-session caps at previous/current/next even if HLS preload count
    grows.
- `PlayerPlaybackSourceRepository`
  - Centralizes source resolve/preload.
  - Current mock implementation returns stable HLS sources and optional local
    proxy spike source.
- HLS preload / local proxy spike
  - `HlsPlaylistPreloader` can fetch playlist and preheat limited first
    segments.
  - Startup and playback preload scopes have separate manager/preloader
    instances, so release/cancel does not cross-contaminate.
  - Local HLS proxy spike is default-off and not recommended for production.
- Home startup trigger
  - `HomePage` watches successful Home feed state and calls
    `preloadFirstPlayableDrama(next.items.first)`.
  - Home sends a drama candidate, not a playable media session.
- For You / single drama `preloadAround()` chain
  - `PlayerPage` listens to feed `currentItem`, calls `playItem(next)`, then
    calls `preloadAround(items, currentIndex)`.
  - Controller filters locked, unavailable, and null-source items.
  - HLS preload can scan forward/backward counts from config; prepared session
    still only prepares the first forward playable item.
- Playback progress
  - `PlaybackProgressRepository` currently has an in-memory implementation.
  - Single drama can save/restore mock position. For You cross-session restore
    remains intentionally disabled.
- `docs/player-source-and-cdn-spec.md`
  - Defines HLS source, CDN, subtitle, aspect-ratio, preload, and expiry fields.
  - Confirms cold first frame is likely source/CDN/media pipeline, not Dart
    source resolve or `media_kit.open()`.
- `docs/api-integration-plan.md`
  - Defines repository/data/DTO boundaries for real API integration.
  - Playback source API must align with the source/CDN spec.

The current architecture is strong at visible-player lifecycle and adjacent
session reuse, but it lacks a cross-entry resource identity and shared resource
catalog. Home, For You, detail, My list, and future server manifests cannot yet
coordinate resource readiness through a common model.

## 2. Design Goal

Build a Global Playback Resource System with one governing principle:

**Globally manage resources, not playback.**

The system should make media resources easier to identify, prepare, reuse,
cancel, observe, and eventually cache. It must not become a second player
controller.

Responsibilities:

- Home, For You, Detail, My list, and server manifests submit playback resource
  intents.
- A global catalog records what is known or prepared for a playback resource.
- A policy engine decides whether an intent should run, be downgraded, or be
  denied.
- A scheduler deduplicates, prioritizes, cancels, and dispatches work.
- Executors perform source resolve, playlist preload, first-segment preheat,
  current-player prepare, or future local cache operations.
- The currently visible `PlayerPlaybackController` remains the only owner of
  play, pause, seek, audio, and media-session truth.

Non-goals:

- No Home media session.
- No global `play()` or `pause()`.
- No production local HLS cache/proxy in this phase.
- No expansion of the prepared media-session window.
- No bypass of access/entitlement checks.

## 3. Resource Identity

### `PlaybackResourceKey`

```text
PlaybackResourceKey
- dramaId
- episodeId
- sourceId
- contentLanguage
- subtitleLanguage
- qualityProfile
- accessLevel
```

Field meaning:

- `dramaId`: groups episodes and links Home/detail/My list identity.
- `episodeId`: the stable playable unit.
- `sourceId`: changes when backend rotates media, encoding, subtitles, or
  signed source version. A sourceId change invalidates old source metadata and
  HLS readiness.
- `contentLanguage`: localized title/description/audio may change resource
  payload and catalog metadata.
- `subtitleLanguage`: subtitle URL/cache and seek preview may vary by language.
- `qualityProfile`: startup/SD/HD variants must not be mixed in cache or
  readiness records.
- `accessLevel`: free, unlocked, membership, paid, or blocked content must not
  reuse each other's resource readiness.

Why URL alone is not enough:

- Public mock sources may reuse one HLS URL for multiple test episodes.
- Signed URLs rotate while representing the same business source.
- Different languages, subtitles, quality, or access states can point to
  different resources for the same episode.

## 4. Resource Catalog

### `PlaybackResourceRecord`

```text
PlaybackResourceRecord
- key
- sourceUrl
- expiresAt
- duration
- aspectRatio
- subtitleTracks
- preloadLevel
- status
- lastAccessedAt
- lastPlayedPosition
- failureCount
- sourceProfile
```

Suggested status:

```text
unknown
metadataResolved
playlistReady
firstSegmentReady
preparedSessionReady
playing
pausedRetained
expired
failed
blocked
```

Catalog role:

- It is not a player.
- It does not own `VideoController`.
- It records resource readiness, metadata, expiry, progress hints, and recent
  failures.
- It lets multiple entry points ask: "Has this episode/source/language/profile
  already been prepared, and to what level?"

Status interpretation:

- `metadataResolved`: source metadata exists, but playlist is not fetched.
- `playlistReady`: HLS playlist fetched/parsed.
- `firstSegmentReady`: limited first segment preheated.
- `preparedSessionReady`: current Player scope prepared a media session.
- `playing`: visible `PlayerPlaybackController` owns active playback.
- `pausedRetained`: a previous session is retained inside current Player scope.
- `expired`: `expiresAt` or `sourceId` invalidated resource.
- `failed`: last executor failed; policy may retry later.
- `blocked`: entitlement/access says do not resolve/preload/open.

Catalog invalidation:

- `sourceId` changes: invalidate metadata, playlist, segment readiness, and
  prepared session references.
- `expiresAt` passes: invalidate source metadata and dependent preload levels.
- `contentLanguage` / `subtitleLanguage` changes: invalidate localized metadata
  and subtitle cache.
- `qualityProfile` changes: invalidate playlist/segment readiness for the old
  variant.
- `accessLevel` changes: re-evaluate blocked/unlocked/membership state.

## 5. Playback Intent

Entry points should submit intents rather than directly invoking preload.

### `PlaybackIntent`

```text
PlaybackIntent
- source
- reason
- priority
- desiredLevel
- resourceKey
```

Suggested intent sources:

- `home`
- `forYou`
- `singleDrama`
- `detail`
- `myList`
- `serverManifest`
- `resume`

Suggested reasons:

- `visible`
- `likelyTap`
- `currentPlaying`
- `nextCandidate`
- `previousCandidate`
- `resume`
- `serverRecommended`

Examples:

- Home first visible card:
  - `source=home`
  - `reason=likelyTap`
  - `desiredLevel=playlistReady`
- For You next item:
  - `source=forYou`
  - `reason=nextCandidate`
  - `desiredLevel=firstSegmentReady`
- Single drama next episode:
  - `source=singleDrama`
  - `reason=nextCandidate`
  - `desiredLevel=preparedSessionReady`
- Detail page entry:
  - `source=detail`
  - `reason=visible`
  - `desiredLevel=metadataResolved`
- My list resume:
  - `source=myList`
  - `reason=resume`
  - `desiredLevel=firstSegmentReady`
- Server preload manifest:
  - `source=serverManifest`
  - `reason=serverRecommended`
  - `desiredLevel=playlistReady`

Important constraint:

- An intent is a request to prepare a resource. It is not permission to play.

## 6. Policy Engine

The policy engine decides whether an intent can run and at what level.

Inputs:

```text
networkType: wifi / cellular / offline
batterySaver
dataSaver
deviceMemoryClass
appLifecycle
userSettings
membership/access
currentRouteVisibility
preloadBudget
serverPolicy
```

Output:

```text
allow / deny / downgrade
targetLevel
maxBytes
timeout
priority
```

Examples:

- Wi-Fi, foreground, Home idle:
  - allow Home likely-tap preload to L1 or L2.
- Cellular with data saver:
  - downgrade Home preload to L0 metadata only or deny.
- For You rapid swipe:
  - allow next candidate but lower timeout/bytes to protect current playback.
- Low-memory device:
  - deny L3 prepare except current Player previous/current/next.
- Background/inactive:
  - cancel non-essential preload; release Player-scope prepared sessions.
- Entitlement not confirmed:
  - deny resource preparation above metadata, mark blocked if needed.
- Server high-priority manifest:
  - increase priority only within local network, memory, access, and lifecycle
    limits.

Policy must preserve current proven constraints:

- Home cannot create media sessions.
- Startup preload and playback preload cannot share pending/release state.
- Prepared media session count cannot grow just because HLS preload count grows.
- Locked, unavailable, null-source, or expired resources must not open/preload
  as playable media.

## 7. Scheduler

### `PlaybackPreloadScheduler`

```text
PlaybackPreloadScheduler
- enqueue(intent)
- cancelBySource(source)
- cancelByKey(key)
- reprioritize(key)
- releaseStale()
```

Responsibilities:

- Deduplicate by `PlaybackResourceKey`.
- Merge compatible intents for the same resource.
- Upgrade target level when a higher-priority intent arrives.
- Downgrade or cancel when policy changes.
- Route work to the correct executor.
- Keep scope cancellation explicit.

Rules:

- Current visible playback is always highest priority.
- Server manifest is advisory and lower than user action.
- Home startup cancellation must not cancel Player playback preload.
- Player hidden releases Player-scope prepared sessions and active player
  preloads.
- App background, offline, data saver, or battery saver can downgrade or cancel
  queued work.
- Scheduler must track generation or token per task so late completion cannot
  write stale success.

Scope model:

- `globalLightweight`: L0-L2 work that does not create a media session.
- `playerScope`: L3 prepare and retained session window owned by visible
  player.
- `futureCacheScope`: L4 local cache, default-off until validated.

## 8. Executors And Preload Levels

```text
L0 SourceResolveExecutor
L1 PlaylistPreloadExecutor
L2 SegmentPreheatExecutor
L3 PrepareSessionExecutor
L4 LocalCacheExecutor
```

### L0: Source Resolve

- Resolves source metadata from mock or real API.
- Produces source id, URL, expiry, duration, dimensions, subtitles, access, and
  preload policy.
- Does not fetch HLS playlist.

### L1: Playlist Preload

- Fetches and parses m3u8 playlist.
- May identify master/media playlist relationship.
- Does not download media segments.

### L2: First Segment Preheat

- Fetches only the first 1-2 segment responses with byte limits.
- Uses local policy and server `preloadPolicy`.
- Does not provide a production cache guarantee.

### L3: Prepare Session

- Creates muted/paused media session.
- Only allowed in current Player scope.
- Limited to previous/current/next window.
- Must pause and release on hidden/dispose/background.

### L4: Local Cache

- Future production local HLS cache/proxy or segment cache.
- Default closed.
- Requires real validation, quota, LRU, expiry, signed URL refresh, and network
  policy.
- Should not be used as a shortcut for current cold-start tuning.

## 9. Cache Store Design

Stores should be separate, not one catch-all cache.

```text
SourceMetadataCache
PlaylistCache
SegmentPreheatCache
PlaybackProgressCache
SubtitleCache
PosterPreviewCache
```

### SourceMetadataCache

- Keyed by `PlaybackResourceKey`.
- Expires by `expiresAt` and `sourceId`.
- Stores source URL, backup URLs, duration, aspect ratio, subtitles, and policy.

### PlaylistCache

- Short TTL.
- Invalidated by source expiry/sourceId change.
- Can store master/media playlist parse result.

### SegmentPreheatCache

- MVP memory-only or transient.
- Persistent storage is L4 and deferred.
- Invalidated by sourceId, qualityProfile, and source expiry.

### PlaybackProgressCache

- Stores last local position and duration.
- Can sync to server later.
- For You cross-session restore stays deferred unless product approves.

### SubtitleCache

- Key includes subtitle language and sourceId.
- Invalidates on language, subtitle URL, or source version change.

### PosterPreviewCache

- Can rely on image cache for poster/thumbnail.
- Preview sprite/VTT cache should include language/sourceId/quality profile if
  those affect assets.

## 10. Server Preload Manifest

The server can suggest resources to prepare, but the client policy decides what
actually runs.

Example:

```json
{
  "preloadManifestVersion": "2026-05-15-1",
  "items": [
    {
      "dramaId": "drama-001",
      "episodeId": "ep-001",
      "sourceId": "src-001",
      "priority": 100,
      "reason": "home_rank_top",
      "desiredLevel": "playlist",
      "expiresAt": "2026-05-15T10:00:00Z",
      "maxBytes": 800000,
      "language": "en-US",
      "subtitleLanguage": "en-US",
      "qualityProfile": "startup",
      "access": "free"
    }
  ]
}
```

Rules:

- Server manifest is advisory.
- Client denies or downgrades based on network, app lifecycle, access, device
  memory, battery/data saver, and budget.
- Server cannot force L3 media-session prepare from Home.
- Manifest entries must include enough identity to build `PlaybackResourceKey`.
- Expired manifest items are ignored.

## 11. Observability

Every resource task should be explainable.

Required log fields:

```text
resourceKey
intentSource
desiredLevel
actualLevel
policyDecision
queueWaitMs
executeMs
bytes
cacheHit
executor
cancelReason
failureReason
firstFrameMs
```

Questions the logs must answer:

- Why did this episode not preload?
- Was preload denied, downgraded, cancelled, or failed?
- Did the player hit metadata, playlist, first segment, prepared session, or
  retained session?
- Did source expiry, access, locale, quality, or sourceId invalidate reuse?
- Did cold first frame remain slow despite L1/L2 preparation?
- Was slow startup due to policy delay, queue wait, network bytes, media open,
  first frame, or buffering?

The existing `PlayerPlaybackTimingTrace` should remain the player-session trace.
The resource system can add a resource trace and link it to playback trace by
`PlaybackResourceKey`, item id, and sourceId.

## 12. Relationship With Existing Architecture

This system is an extension, not a conflict.

Keep:

- `PlayerPlaybackController` as the only real playback state owner.
- `PlayerPlaybackPrepareManager` for previous/current/next media-session
  window.
- `PlayerPreloadConfig` for local default preload policy.
- Startup and playback preload scope isolation.
- `PlayerPlaybackSourceRepository` as source resolve/preload API boundary.
- HLS playlist/segment preloader as a reusable executor implementation.
- Local HLS proxy spike default-off.
- Existing timing trace and release-build diagnostics.

Gradually replace:

- Direct Home call to `preloadFirstPlayableDrama()` can become a Home
  `PlaybackIntent`.
- Direct Player `preloadAround()` scheduling can become scheduler intents while
  still delegating L3 prepare to current Player scope.
- Startup preload state can become a catalog record for the same
  `PlaybackResourceKey`.

Do not change:

- Visible playback ownership.
- Audio lifecycle rules.
- Locked/unavailable/null-source filtering.
- Prepared session window cap.
- Mock/remote repository separation.

Compatibility:

- `PlayerPreloadConfig` can become the local default input for Policy Engine.
- `docs/api-integration-plan.md` supplies future source, progress, entitlement,
  localization, and preload manifest endpoints.
- `docs/player-source-and-cdn-spec.md` supplies the required source metadata,
  sourceId, expiresAt, aspect ratio, subtitles, cache policy, and preload policy.

## 13. Implementation Phases

### Phase 6.0: Architecture Document

- Produce this plan.
- Do not change code.
- Align on boundaries, prohibitions, and phased rollout.

### Phase 6.1: ResourceKey And Catalog

- Add `PlaybackResourceKey`.
- Add in-memory `PlaybackResourceCatalog`.
- Map existing `PlayerFeedItem` / `PlaybackSource` to resource keys where
  sourceId is available; mock may use deterministic source profile.
- Record metadata, readiness, expiry, progress hints, and failure counts.
- Do not route behavior through catalog yet.

### Phase 6.2: Intent And Scheduler MVP

- Add `PlaybackIntent`.
- Add scheduler with dedupe, priority, cancellation, and generation safety.
- Convert Home startup preload to submit a `home/likelyTap` intent.
- Convert Player adjacent HLS preload to submit current player intents.
- Keep existing controller behavior as executor delegate.

### Phase 6.3: Policy Engine

- Add local policy using `PlayerPreloadConfig`.
- Add app lifecycle, network type, data saver, battery saver, route visibility,
  and access inputs where available.
- Output allow/deny/downgrade with target level, max bytes, timeout, and
  priority.

### Phase 6.4: Cross-Entry Reuse

- Reuse catalog state for the same `PlaybackResourceKey` across Home, For You,
  Detail, and My list.
- Avoid duplicate source resolve/preload when one entry has already prepared
  L0-L2.
- Keep L3 prepare inside visible Player only.

### Phase 6.5: Server Preload Manifest Mock

- Add mock manifest ingestion.
- Convert manifest entries to low-priority intents.
- Verify local policy can deny/downgrade manifest work.
- Do not connect real API yet.

### Phase 6.6: Device Regression And Real Source Validation

- Run release-device timing with resource logs.
- Compare startup hit/miss, resource level, queue wait, executor time, and
  first frame.
- Validate with real CDN/source once backend is available.
- Decide whether L4 local cache is still needed.

## 14. Conclusions

### Is This An Extension Or Conflict?

It is an extension. The current player system controls actual playback well, but
resource preparation is still distributed between Home startup preload and
Player adjacent preload. A global resource system would add identity, catalog,
intent, policy, and scheduler layers above existing source/preload/prepare
executors.

### Reusable Existing Code

- `PlayerPlaybackSourceRepository` can serve L0 source resolve.
- `HlsPlaylistPreloader` can serve L1/L2 execution.
- `PlayerPlaybackPrepareManager` can serve L3 prepare inside Player scope.
- `PlayerPreloadConfig` can seed local policy defaults.
- `PlaybackProgressRepository` can become part of `PlaybackProgressCache`.
- `PlayerPlaybackTimingTrace` can remain the playback trace and be linked from
  resource traces.

### Required Future Refactors

- Introduce a resource key mapper from domain feed/source objects.
- Move Home startup preload from direct controller call to intent submission.
- Move `preloadAround()` candidate scheduling toward scheduler ownership while
  keeping Player scope for L3.
- Add catalog-aware source/preload result recording.
- Add access/entitlement inputs once real APIs arrive.

### Deferred Capabilities

- L4 local HLS segment cache/proxy production implementation.
- Real server preload manifest.
- Real network classification and data saver integration if platform support is
  not yet available.
- Remote policy/config rollout.
- Cross-device progress and server-side resume.
- Subtitle selection UI and cache production behavior.

### Should Implementation Start Now?

Recommendation:

- Start with Phase 6.1 only if the team is ready to invest in playback resource
  infrastructure before real API rollout.
- Otherwise, continue real API integration first, especially playback source,
  entitlement, and progress APIs, because `sourceId`, access state, language,
  subtitles, and preload policy are required for a correct resource key.

Practical next step:

- Keep this plan as the Phase 6.0 baseline.
- During real playback source API integration, ensure responses include
  `sourceId`, `expiresAt`, access status, dimensions, subtitle tracks, and
  preload policy so Phase 6.1 can be implemented without guesswork.
