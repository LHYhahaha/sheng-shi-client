# Player Loading Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore reliable direct HLS playback by making experimental proxying opt-in, enforcing remote API switches consistently, and exposing the exact failing boundary when a source cannot start.

**Architecture:** The playback controller remains the sole owner of media state. Source selection is made deterministic in repository providers: validated remote API configuration chooses remote vs. mock data, while direct remote HLS remains the production playback path. The localhost HLS proxy remains a manual diagnostic spike only; any failure after a proxy URL has been opened triggers one guarded direct-source retry before the player enters its terminal error state.

**Tech Stack:** Flutter, Riverpod, media_kit, Dart `HttpClient`, Flutter tests.

**Spec:** `docs/player/player-local-hls-proxy-cache.md`

## Global Constraints

- `PLAYER_HLS_LOCAL_PROXY_SPIKE` is false unless explicitly supplied as `true`.
- Do not enable the local HLS proxy/cache through `AppRuntimeConfig` or remote flags.
- Do not expose signed URLs, access tokens, or raw media-kit errors in UI or normal logs.
- Locked, unavailable, and null-source episodes must never resolve, prepare, preload, or open media.
- Preserve existing user-authored worktree changes outside files named in each task.

## Review Focus

- A release build with no playback/proxy dart-defines must use the direct `source_url` and produce no localhost source.
- An explicitly enabled proxy must fall back exactly once to its original remote URL after playlist, segment, or first-frame failure.
- A source that requires HTTP authorization must receive the same safe media headers on direct playback and proxy upstream requests, without serializing the token into a localhost URL or timing log.
- An unavailable, expired, malformed, or 4xx source must surface a classified retry state without being masked as a decoder error.
- A stale retry from a previous PageView item must never replace the current item’s session or state.

---

## File Structure

- `lib/core/network/remote_api_switches.dart`: read compile-time remote API module switches with a safe default.
- `lib/core/network/remote_api_provider.dart`: expose the validated effective switch set used by repositories.
- `lib/features/player/data/player_content_repository_provider.dart`: choose player content source from the effective switch.
- `lib/features/player/data/player_feed_repository_provider.dart`: choose player feed source from the effective switch.
- `lib/features/player/data/player_playback_source_repository_provider.dart`: make proxy use opt-in and construct the three player source repositories consistently.
- `lib/features/player/data/hls_local_proxy_server.dart`: carry approved media headers upstream and define a non-sensitive proxy failure signal.
- `lib/features/player/data/remote_player_playback_source_repository.dart`: retain direct and proxy URLs as a pair for controlled fallback.
- `lib/features/player/application/player_playback_controller.dart`: own a one-time proxy-to-direct retry and record sanitized boundary timing.
- `test/architecture/remote_switch_default_test.dart`: lock safe API defaults.
- `test/features/player/hls_local_proxy_server_test.dart`: cover disabled-by-default proxy, headers, and runtime failure behavior.
- `test/features/player/player_remote_api_skeleton_test.dart`: verify provider-level remote selection and source header propagation.
- `test/features/player/player_playback_controller_test.dart`: cover one-time direct retry and stale-generation protection.

### Task 1: Restore configuration-safe defaults

**Files:**
- Modify: `lib/core/network/remote_api_switches.dart:42-64`
- Modify: `lib/features/player/data/player_content_repository_provider.dart:10`
- Modify: `lib/features/player/data/player_feed_repository_provider.dart:10`
- Modify: `lib/features/player/data/player_playback_source_repository_provider.dart:82-91,174-237`
- Test: `test/architecture/remote_switch_default_test.dart`

**Interfaces:**
- Consumes: `remoteApiEffectiveSwitchesProvider` and `RemoteApiSwitches.isEnabled(RemoteApiModule.player)`.
- Produces: all player repository providers select remote only when the validated player module is enabled; `HlsLocalProxyConfig.enabled` is true only for `PLAYER_HLS_LOCAL_PROXY_SPIKE=true`.

- [ ] **Step 1: Write failing default-path tests**

```dart
test('player remote API and local proxy are disabled without dart-defines', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(useRemotePlayerApiProvider), isFalse);
  expect(container.read(hlsLocalProxyConfigProvider).enabled, isFalse);
});
```

- [ ] **Step 2: Run the default-path tests to prove the regression**

Run: `flutter test --no-pub test/architecture/remote_switch_default_test.dart test/features/player/hls_local_proxy_server_test.dart`

Expected: FAIL because the current code defaults remote modules and `HlsLocalProxyConfig.enabled` to true.

- [ ] **Step 3: Implement the minimal configuration change**

```dart
// remote_api_switches.dart
drama: _envBool('USE_REMOTE_DRAMA_API'),
player: _envBool('USE_REMOTE_PLAYER_API'),
myList: _envBool('USE_REMOTE_MY_LIST_API'),
profile: _envBool('USE_REMOTE_PROFILE_API'),
wallet: _envBool('USE_REMOTE_WALLET_API'),
store: _envBool('USE_REMOTE_STORE_API'),
membership: _envBool('USE_REMOTE_MEMBERSHIP_API'),
entitlement: _envBool('USE_REMOTE_ENTITLEMENT_API'),
auth: _envBool('USE_REMOTE_AUTH_API'),

// player_playback_source_repository_provider.dart
final hlsLocalProxyConfigProvider = Provider<HlsLocalProxyConfig>((ref) {
  const enabled = bool.fromEnvironment('PLAYER_HLS_LOCAL_PROXY_SPIKE');
  return HlsLocalProxyConfig(enabled: enabled);
});
```

Replace direct calls to `RemoteApiSwitches.fromEnvironment()` in player repository providers with `ref.watch(remoteApiEffectiveSwitchesProvider).player`, preserving the mock branch otherwise.

- [ ] **Step 4: Run the focused tests**

Run: `flutter test --no-pub test/architecture/remote_switch_default_test.dart test/features/player/player_remote_api_skeleton_test.dart`

Expected: PASS; no-dart-define execution selects mock player repositories, while explicit provider overrides still select remote repositories.

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/remote_api_switches.dart lib/features/player/data/player_content_repository_provider.dart lib/features/player/data/player_feed_repository_provider.dart lib/features/player/data/player_playback_source_repository_provider.dart test/architecture/remote_switch_default_test.dart test/features/player/player_remote_api_skeleton_test.dart
git commit -m "fix(player): keep remote and HLS proxy opt-in"
```

### Task 2: Preserve source authentication across every media hop

**Files:**
- Modify: `lib/features/player/data/player_playback_source_repository_provider.dart:179-237`
- Modify: `lib/features/player/data/remote_player_playback_source_repository.dart:14-145`
- Modify: `lib/features/player/data/hls_local_proxy_server.dart:59-130,278-620,919-969`
- Test: `test/features/player/player_remote_api_skeleton_test.dart`
- Test: `test/features/player/hls_local_proxy_server_test.dart`

**Interfaces:**
- Consumes: current `ApiRequestContext.accessToken` and `PlaybackSource.httpHeaders`.
- Produces: the player and proxy upstream request both receive an in-memory `Authorization` header when the source contract needs it; no header is included in proxy query parameters or log output.

- [ ] **Step 1: Add a failing header propagation test**

```dart
test('proxy upstream request receives media headers without URL leakage', () async {
  final client = RecordingProxyHttpClient();
  final server = HlsLocalProxyServer(client: client);
  addTearDown(server.stop);

  final proxyUrl = await server.proxyUrlFor(
    'https://cdn.example.test/master.m3u8',
    headers: const {'Authorization': 'Bearer test-token'},
  );
  await readString(Uri.parse(proxyUrl));

  expect(client.lastHeaders, {'Authorization': 'Bearer test-token'});
  expect(proxyUrl, isNot(contains('test-token')));
});
```

- [ ] **Step 2: Run the focused test to prove headers are currently dropped**

Run: `flutter test --no-pub test/features/player/hls_local_proxy_server_test.dart`

Expected: FAIL because `HlsLocalProxyHttpClient.get/open` presently receives only URI and timeout.

- [ ] **Step 3: Implement a header-safe proxy context**

Add an immutable source context keyed by an opaque random proxy request id, not by the remote URL. Extend `HlsLocalProxyHttpClient.get/open` with `Map<String, String>? headers`; pass it to `HttpClientRequest.headers` before `close()`. Build headers in player providers from the current token only when a nonempty token exists. Keep `PlaybackSource.remoteUrl` canonical and retain its headers through `_applyProxy`.

- [ ] **Step 4: Run targeted source and proxy tests**

Run: `flutter test --no-pub test/features/player/hls_local_proxy_server_test.dart test/features/player/player_remote_api_skeleton_test.dart`

Expected: PASS; direct player source headers remain supported and proxied playlist/segment fetches use equivalent headers without leakage.

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/data/player_playback_source_repository_provider.dart lib/features/player/data/remote_player_playback_source_repository.dart lib/features/player/data/hls_local_proxy_server.dart test/features/player/hls_local_proxy_server_test.dart test/features/player/player_remote_api_skeleton_test.dart
git commit -m "fix(player): preserve media authorization through proxy"
```

### Task 3: Add guarded proxy runtime fallback and actionable classification

**Files:**
- Modify: `lib/features/player/domain/player_playback_source.dart`
- Modify: `lib/features/player/data/hls_local_proxy_server.dart`
- Modify: `lib/features/player/application/player_playback_controller.dart:1496-2198,4316-4469`
- Test: `test/features/player/player_playback_controller_test.dart`

**Interfaces:**
- Consumes: `PlaybackSource.remoteUrl`, `playableSource`, `httpHeaders`, current playback generation, and sanitized proxy failure category.
- Produces: `openProxyThenDirectOnce(PlaybackSource, generation)` behavior: a proxy failure before first frame retries the same remote source once; direct-source failure enters the existing classified error state.

- [ ] **Step 1: Add failing playback-controller tests**

```dart
test('proxy first-frame failure retries the canonical source once', () async {
  final repository = FakeSourceRepository.withSource(
    remoteUrl: 'https://cdn.example.test/episode.m3u8',
    playableSource: 'http://localhost:1234/playlist.m3u8?id=opaque',
  );
  final session = ErrorThenPlayableSession(proxyError: 'HTTP 502');
  final controller = buildController(repository: repository, session: session);

  await controller.playItem(item);

  expect(session.openedSources, [
    'http://localhost:1234/playlist.m3u8?id=opaque',
    'https://cdn.example.test/episode.m3u8',
  ]);
});

test('a direct retry cannot reopen after item generation changes', () async {
  final firstOpen = Completer<void>();
  final session = ControlledErrorSession(onProxyOpen: firstOpen.complete);
  final controller = buildController(session: session);
  unawaited(controller.playItem(itemA));
  await firstOpen.future;
  await controller.playItem(itemB);
  session.emitError('HTTP 502');
  await pumpEventQueue();

  expect(controller.state.currentItemId, itemB.id);
  expect(controller.state.currentSource, itemB.episode.videoSource);
  expect(session.openedSources, isNot(contains(itemA.episode.videoSource)));
});
```

- [ ] **Step 2: Run those tests to prove the current terminal failure**

Run: `flutter test --no-pub test/features/player/player_playback_controller_test.dart`

Expected: FAIL because `_handleError` currently calls `_markPlaybackFailed` immediately and `HlsProxyPlaybackSourceResolver` only falls back when proxy URL creation—not runtime playlist/segment fetching—fails.

- [ ] **Step 3: Implement one retry at the source boundary**

Add a non-persisted `usedProxyFallback` field to `PlaybackSource`. When the active source is a proxy URL, no first frame has arrived, and error classification is transport/proxy failure, re-open `remoteUrl` once with the same headers. Guard it with the current generation and item id. Mark the item failed only if that direct attempt fails or reaches the existing first-frame timeout. Do not retry 401/403/404 as transport failures; classify those as source/auth failures.

- [ ] **Step 4: Run focused playback tests**

Run: `flutter test --no-pub test/features/player/player_playback_controller_test.dart`

Expected: PASS; one proxy failure recovers by direct playback, repeated failure does not loop, and stale callbacks cannot alter a newer item.

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/domain/player_playback_source.dart lib/features/player/data/hls_local_proxy_server.dart lib/features/player/application/player_playback_controller.dart test/features/player/player_playback_controller_test.dart
git commit -m "fix(player): fall back from proxy runtime failures"
```

### Task 4: Close the evidence loop on a device and release gate

**Files:**
- Modify: `docs/player/player-local-hls-proxy-cache.md`
- Modify: `docs/release/release-seal-checklist.md`
- Test: existing focused test suite plus a manual device matrix.

**Interfaces:**
- Consumes: `PlayerPlaybackTimingTrace` events and sanitized proxy error categories.
- Produces: a release gate that rejects proxy-on builds unless explicitly marked diagnostic and records first-frame evidence for direct playback.

- [ ] **Step 1: Add the device acceptance table**

Record, for Android and iOS, the source mode, source resolve duration, media-open duration, first-frame duration, error category, and whether the direct fallback was used. Do not record the source URL or authorization headers.

- [ ] **Step 2: Verify build-mode behavior**

Run a release candidate with no player dart-defines and confirm `playableSource` is the direct remote source. Run a separately labeled diagnostic build with `PLAYER_HLS_LOCAL_PROXY_SPIKE=true` and verify either first frame or a single direct fallback.

- [ ] **Step 3: Run the regression suite**

Run: `flutter test --no-pub test/architecture/remote_switch_default_test.dart test/features/player/hls_local_proxy_server_test.dart test/features/player/hls_playlist_preloader_test.dart test/features/player/player_remote_api_skeleton_test.dart test/features/player/player_playback_controller_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/player/player-local-hls-proxy-cache.md docs/release/release-seal-checklist.md
git commit -m "docs(player): gate experimental HLS proxy releases"
```
