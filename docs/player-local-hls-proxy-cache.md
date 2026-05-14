# Player Local HLS Proxy / Cache Decision

This document explains the current decision around local HLS proxy/cache for
the short-drama player. It should be read before adding or enabling any local
HLS cache, localhost proxy, segment cache, or offline-like playback workaround.

## Current Decision

The local HLS proxy/cache approach is **not approved for production use yet**.

The Phase 5.15 spike proved that the client can technically start a localhost
HLS proxy, rewrite playlists, proxy segment requests, and cache segment bytes in
memory. However, Android release-device testing did not show reliable playback
improvement. In the sampled run, the proxy path connected at the HTTP level, but
playback did not produce a stable first frame inside the sampling window and
later segment requests timed out.

Direct remote HLS playback remains the default path.

The spike is guarded by:

```text
PLAYER_HLS_LOCAL_PROXY_SPIKE=true
```

This flag must stay disabled by default.

## Why It Is Not Production-Ready

HLS playback is more than a playlist and a few `.ts` or `.m4s` files. A
production local proxy/cache would need to correctly handle many runtime cases:

- master playlists and media playlists;
- variant selection and startup bitrate;
- relative URLs, redirects, and CDN host changes;
- `#EXT-X-MAP` initialization segments;
- `#EXT-X-KEY` key URIs for encrypted streams;
- byte-range segments and HTTP Range requests;
- discontinuities and playlist attributes that reference external resources;
- timeout, cancellation, and fallback while media_kit is reading through the
  proxy;
- signed URL expiry and refresh;
- memory/disk quota, expiry, and LRU cleanup;
- Android/iOS differences in HLS pipeline behavior.

Without these pieces, a local proxy can be slower or less stable than direct
remote playback.

## CDN And Source Conditions

A local client cache can only help if the HLS source is cache-friendly and
startup-friendly. It is not a substitute for good source packaging or CDN
behavior.

The CDN/source should satisfy these basics before local cache is reconsidered:

- small first media segment;
- short segment duration appropriate for fast startup, commonly around 1-2s for
  short-form playback;
- keyframe/GOP alignment that allows quick first-frame decode;
- reasonable startup bitrate or a low-bitrate startup variant;
- stable playlist and segment `Cache-Control`;
- support for Range requests where applicable;
- short redirect chains;
- predictable signed URL expiry and refresh behavior;
- stable CDN edge cache hit rate.

If these are not true, a client proxy mostly moves the problem into the app and
can make debugging harder.

## Recommended Optimization Order

Use this order for playback smoothness work:

1. Keep the current direct remote HLS playback path stable.
2. Preserve the previous/current/next session window for vertical swipe and
   swipe-back reuse.
3. Keep startup preload and playback preload separated by scope.
4. Make lightweight HLS preload counts configurable through
   `PlayerPreloadConfig`.
5. Define and enforce the server/CDN playback source specification.
6. Re-test real business HLS sources on device with timing logs.
7. Only if direct playback remains slow after source/CDN tuning, run a second
   local proxy/cache spike with a production-like HLS fixture.

Do not use offline download as a workaround for online playback smoothness.
Offline download is a separate product feature.

## When To Reconsider Local HLS Cache

Reconsider a production local HLS cache/proxy only if all of the following are
true:

- direct remote HLS still has unacceptable cold first-frame timing;
- session window hits are already working for next and previous playback;
- CDN/source packaging has been reviewed and tuned;
- timing logs prove repeated segment fetches or first-segment fetches are a real
  bottleneck;
- a controlled local proxy spike shows meaningful first-frame improvement on
  Android and iOS;
- fallback to the original remote HLS source is reliable;
- quota, expiry, cancellation, and signed URL behavior are specified.

Until then, keep the local proxy spike as a diagnostic experiment, not a product
runtime path.

## Required Timing Evidence

Any future local HLS cache/proxy work must compare at least these timings:

- direct remote Home cold entry to first frame;
- local proxy Home cold entry to first frame;
- direct remote For You first item to first frame;
- local proxy For You first item to first frame;
- prepared next hit timing;
- retained previous hit timing;
- proxy playlist hit/miss;
- proxy segment hit/miss;
- fallback-to-remote timing;
- background audio behavior after tab switch, route pop, and app background.

The result must be recorded in `docs/player-experience-architecture-plan.md` or
`docs/player-playback-cache-plan.md` before production implementation starts.

## Current Implementation Status

The current spike implementation is intentionally experimental:

- `HlsLocalProxyServer`
- `HlsLocalCacheStore`
- `HlsProxyPlaybackSourceResolver`
- `PLAYER_HLS_LOCAL_PROXY_SPIKE`

These pieces should not be expanded casually. If the team decides to revisit
local cache, first create a fresh production design covering:

- cache ownership;
- quota and eviction;
- signed URL refresh;
- playlist rewrite completeness;
- segment and init-map caching;
- Range support;
- runtime fallback;
- release-device metrics.

