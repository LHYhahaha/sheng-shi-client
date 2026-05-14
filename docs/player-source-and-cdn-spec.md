# Player Source And CDN Specification

This document defines the playback-source, HLS, CDN, subtitle, and validation
requirements for the short-drama client. It is a contract proposal for future
backend/CDN integration. It does not change the current mock implementation,
player UI, local proxy/cache behavior, or API wiring.

## 1. Verified Client Conclusions

Recent Android release timing on `R58WC02B69R` shows:

- Dart-side source resolve is fast, typically around 40-60ms.
- `media_kit` open calls are fast, typically around 20-100ms.
- Home cold entry can still take about 2.7-2.9s to first frame even when startup
  preload hits.
- For You first entry has a similar cold-start delay.
- Single-drama next/previous is fast when the session window hits:
  - prepared next avoids a normal reopen;
  - retained previous avoids a normal reopen and preserves position.
- The remaining cold first-frame delay is most likely in HLS first segment,
  CDN/source behavior, encoding/GOP structure, startup bitrate, decoder startup,
  or the media pipeline.
- The Phase 5.15 local HLS proxy/cache spike proved the proxy path can be wired,
  but it did not improve first-frame timing on the test device. It is not
  recommended for production in its current form.

The source/CDN contract should therefore optimize the first playable frame
instead of assuming client-side prefetch or proxying will hide slow sources.

## 2. Playback Source API Fields

Future playback source responses should be explicit enough for the client to
choose fit, preload, expiry, subtitles, and retry behavior without guessing.

Recommended response shape:

```json
{
  "episodeId": "ep-001",
  "sourceId": "src-hls-main-001",
  "hlsUrl": "https://cdn.example.com/dramas/a/ep-001/master.m3u8",
  "backupHlsUrls": [
    "https://cdn-backup.example.com/dramas/a/ep-001/master.m3u8"
  ],
  "expiresAt": "2026-05-15T10:00:00Z",
  "signedUrlRefreshEndpoint": "/player/sources/src-hls-main-001/refresh",
  "refreshToken": "opaque-refresh-token",
  "durationMs": 94500,
  "width": 1080,
  "height": 1920,
  "aspectRatio": 0.5625,
  "codec": {
    "video": "h264",
    "audio": "aac",
    "container": "hls"
  },
  "bitrateLadder": [
    { "name": "startup", "width": 360, "height": 640, "bitrateKbps": 450 },
    { "name": "sd", "width": 540, "height": 960, "bitrateKbps": 900 },
    { "name": "hd", "width": 720, "height": 1280, "bitrateKbps": 1600 }
  ],
  "posterUrl": "https://cdn.example.com/dramas/a/ep-001/poster.jpg",
  "thumbnailUrl": "https://cdn.example.com/dramas/a/ep-001/thumb.jpg",
  "previewSpriteUrl": "https://cdn.example.com/dramas/a/ep-001/sprite.jpg",
  "previewVttUrl": "https://cdn.example.com/dramas/a/ep-001/sprite.vtt",
  "subtitleTracks": [
    {
      "language": "en",
      "label": "English",
      "url": "https://cdn.example.com/dramas/a/ep-001/subs/en.vtt",
      "format": "vtt",
      "isDefault": true
    }
  ],
  "audioTracks": [
    { "language": "en", "label": "English", "isDefault": true }
  ],
  "localizedTitle": "Episode 1",
  "localizedDescription": "A concise localized episode description.",
  "localizedEpisodeTitle": "EP.01",
  "cachePolicy": {
    "playlistTtlSeconds": 60,
    "segmentTtlSeconds": 86400,
    "allowLocalHlsCache": false
  },
  "preloadPolicy": {
    "isPreloadAllowed": true,
    "maxPreloadBytes": 1500000,
    "preferredPreloadSegmentCount": 2
  },
  "access": {
    "isLocked": false,
    "requiresMembership": false,
    "drm": null
  }
}
```

Field guidance:

- `episodeId`: stable episode identifier used by feed, progress, and analytics.
- `sourceId`: stable source version identifier. Changes when URLs, encoding, or
  subtitle bundles change.
- `hlsUrl`: primary playable HLS URL. Prefer HTTPS and short redirect chains.
- `backupHlsUrls`: optional ordered fallback sources. Client may try these after
  source expiry, CDN 5xx, or source-specific failure.
- `expiresAt`: signed URL expiry. Client should refresh before opening if close
  to expiry.
- `signedUrlRefreshEndpoint` / `refreshToken`: explicit refresh path for signed
  URLs. Do not force the client to rediscover the whole episode payload.
- `durationMs`: required for progress bars, resume, completion, and seek bounds.
- `width`, `height`, `aspectRatio`: required for video fit policy.
- `codec`: used for compatibility diagnostics and future source selection.
- `bitrateLadder`: lets the client and backend reason about startup bitrate.
- `posterUrl` / `thumbnailUrl`: used before first frame and in lists.
- `previewSpriteUrl` / `previewVttUrl`: used by seek thumbnail preview.
- `subtitleTracks`: selectable text tracks.
- `audioTracks`: future multi-audio support.
- `cachePolicy`: whether and how a future local HLS cache may store content.
- `preloadPolicy`: source-specific preload limits.
- `access`: reserved for entitlement/DRM decisions. Locked or unavailable
  content must not be opened, preloaded, or prepared.

## 3. HLS Encoding Recommendations

Short-drama playback should prioritize fast first frame and smooth vertical
switching over maximum initial quality.

Recommended HLS properties:

- Keep the first media segment small. The first segment should be optimized for
  startup, not for long steady-state buffering.
- Use short segment duration where practical. For short-drama feeds, 1-2 second
  segments are preferred, or another proven configuration that reaches first
  frame quickly on low/mid Android devices.
- Align GOP/keyframes for quick random access and fast first frame.
- Avoid long GOPs that force the decoder to wait too long before a usable frame.
- Provide a low-bitrate startup variant in the master playlist.
- Avoid making the first variant too expensive for cellular or midrange devices.
- Use Android/iOS-compatible codecs:
  - H.264/AVC for broad baseline compatibility;
  - AAC audio;
  - conservative profile/level unless device coverage proves otherwise.
- Avoid excessive init data before the first decodable frame.
- If using fMP4/CMAF, keep init segments and first media fragments small and
  cacheable.
- Ensure all variants have aligned segment boundaries and keyframes.
- Verify both vertical 9:16 and non-vertical sources on device; metadata must
  accurately report aspect ratio.

Suggested starting point for validation, not a hard rule:

- vertical 9:16 primary renditions;
- startup rendition around 360x640 or 540x960;
- initial bitrate roughly 400-900 Kbps;
- first segment or fragment small enough to fetch quickly on ordinary mobile
  networks;
- segment duration 1-2s unless CDN/player tests prove a better tradeoff.

## 4. CDN And HTTP Header Recommendations

CDN behavior should make playlist and segment fetches predictable.

Playlist headers:

- Use short `Cache-Control` for signed playlists, for example
  `public, max-age=30` or `public, max-age=60` depending on URL expiry.
- Include `ETag` and/or `Last-Modified` for revalidation.
- Avoid unnecessary `no-store` unless content protection requires it.
- Ensure master and media playlists have consistent expiry behavior.

Segment headers:

- Use longer `Cache-Control` for immutable media segments, for example
  `public, max-age=86400, immutable` when URLs are content-versioned.
- Include `ETag` and/or `Last-Modified`.
- Support `Range` requests.
- Return stable `Content-Length` where possible.
- Avoid transfer behavior that delays the first bytes of the first segment.

Signed URL and redirect guidance:

- Signed URLs should not expire during a normal playback session.
- `expiresAt` should leave enough headroom for preload, playback, and retry.
- A 403 from an expired URL should be distinguishable from entitlement failure.
- Keep redirect chains short. Prefer zero or one redirect before media bytes.
- Redirects should preserve caching semantics and not force repeated origin
  trips for every segment.

Failure-code semantics:

- `401`: authentication required or invalid token.
- `403_expired`: signed URL expired and may be refreshed.
- `403_forbidden`: access denied; do not retry as a network error.
- `404`: source or segment missing; report as source/media fatal.
- `408` / timeout: retryable network failure.
- `429`: retryable only according to server-provided backoff.
- `5xx`: recoverable/retryable according to retry budget.

CORS:

- Native mobile playback does not require CORS in the same way as browsers, but
  Web/debug tools may. If Web playback or browser diagnostics are expected,
  configure CORS for playlists, segments, subtitles, and sprites.

CDN edge requirements:

- High edge cache hit rate for first playlists and first segments.
- Low origin latency for cache misses.
- Regional routing appropriate for the user's geography.
- Observability for first-byte latency, cache hit/miss, status code, and segment
  size.

## 5. Subtitles And Localization

The client will eventually separate fixed app language from content language.

Recommended request model:

- Client sends `locale` / `language` when requesting content and playback source.
- Backend returns localized content fields for that language where available.
- Playback source includes subtitle tracks with language metadata.

Recommended fields:

- `localizedTitle`
- `localizedDescription`
- `localizedEpisodeTitle`
- `subtitleTracks[].language`
- `subtitleTracks[].label`
- `subtitleTracks[].url`
- `subtitleTracks[].format`
- `subtitleTracks[].isDefault`

Client behavior:

- Prefer subtitle track matching current app/content language.
- If no exact match exists, use server default or no subtitle depending on
  product policy.
- Do not place drama titles, episode titles, descriptions, or subtitles in the
  fixed client language bundle.
- Fixed app text remains in client localization; drama content remains server
  content.

## 6. Client Strategy Mapping

Server fields should map directly to client behavior:

- `aspectRatio`, `width`, `height`
  - drive `BoxFit.cover` for vertical/near-vertical sources;
  - drive `BoxFit.contain` or background-fill strategy for 16:9/4:3 sources;
  - reduce reliance on runtime stream dimensions.
- `durationMs`
  - progress bar;
  - seek bounds;
  - resume playback;
  - completion/auto-next diagnostics.
- `previewSpriteUrl` / `previewVttUrl`
  - replace poster-only seek thumbnail MVP with real frame preview.
- `preloadPolicy`
  - controls HLS preload count, segment count, timeout, and `maxPreloadBytes`;
  - avoids client-side hardcoding for every source profile.
- `expiresAt` / refresh fields
  - refresh source before open if near expiry;
  - retry playback after signed URL expiry without a full page reload.
- `subtitleTracks`
  - populate subtitle language UI and default selection.
- `cachePolicy`
  - determines whether future local HLS cache/proxy is allowed;
  - determines TTL, quota, and invalidation behavior if productionized.
- `backupHlsUrls`
  - fallback after source/CDN failure, with timing logs recording source switch.
- `access`
  - locked/unavailable/DRM-protected content should skip source open, preload,
    and session prepare.

## 7. Real Source Acceptance Checklist

Before a real source profile is accepted as default, validate on Android and iOS
devices:

- Home cold entry first frame:
  - source resolve;
  - media open;
  - first frame;
  - first position advanced.
- For You first item first frame.
- Single-drama prepared next hit.
- Single-drama retained previous hit.
- Auto-next into playable next item.
- Auto-next into locked/unavailable next item.
- App hidden, backgrounded, tab-switched, or route-popped: no audio continues.
- Subtitle language selection matches client language.
- Expired signed URL returns a refreshable status and can recover.
- CDN 5xx / timeout is recoverable within retry budget.
- 403 entitlement failure does not retry endlessly.
- 16:9 / 4:3 / 9:16 fit behavior matches product policy.
- First segment size and first-byte latency are within target.
- Playlist and segment cache headers match this spec.

Recommended timing report matrix:

| Scenario | Source profile | Resolve ms | Open ms | First frame ms | Position advanced ms | Window result | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home cold entry | stable vertical | | | | | window miss | |
| For You first entry | stable vertical | | | | | window miss | |
| Single next | stable vertical | | | | | prepared hit | |
| Single previous | stable vertical | | | | | retained hit | |
| Auto-next | stable vertical | | | | | prepared hit or miss | |

## 8. Current Client Next Steps

Client-side next steps should be ordered by evidence:

- Keep local HLS proxy/cache spike default-off. Do not productionize the Phase
  5.15 implementation.
- Implement `PlayerPreloadConfig` so HLS preload counts, byte limits, timeouts,
  and prepared session limits are typed and documented.
- Use this spec when replacing mock playback sources with real backend data.
- Continue timing real sources before adding heavier client-side caching.
- If real source/CDN tuning cannot meet startup goals, run a new production-grade
  local HLS cache/proxy design with explicit cache policy, range handling,
  signed URL refresh, quota, and fallback.

## 9. Explicit Non-Goals

- This spec does not require offline download.
- This spec does not require DRM implementation in the current client.
- This spec does not make local HLS proxy/cache production-ready.
- This spec does not replace current mock player data.
- This spec does not define payment, entitlement issuing, or receipt validation.
