# Player Feed Engine Refactor Plan

> **Document status: Current (封板结论)** — 下文「Why / Current Vs Target / Phase R1–R7」为
> **Historical** 实施记录；**以本节 Seal 与架构结论为准**。勿按过期 “likely new files” 继续拆文件。

This document records the structural refactor plan for the short-drama player
feed. The refactor **已完成并封板**；后续仅在真实 API、线上指标或明确 P0 时再评估 engine 变更。

## Mainline Seal (封板, 2026-05-16) — Current

**Release 封板前提：** `USE_REMOTE_*=false`；支付与权益走 mock（`grantMock*`）。开启 remote 或真实 IAP 前须处理 401 refresh、secure token、订单验单、strict DTO（见 `docs/remote-contract-index.md`）。

**播放器主线已封板。** 后续仅保留 **Low-end Android Policy** 优化线（`ultraStable`、设备分级 override），不再大拆 `PlayerFeedEngine` / Coordinator 文件结构。

| 项 | 状态 |
| --- | --- |
| `PlayerPage` 为 UI host（PageView / surface / sheet） | **Done** |
| `PlayerFeedEngine` 为应用层统一入口 | **Done** |
| drag 不触发 runtime；settled 才 evaluate/play/preload/sheet | **Done** |
| 真实 `Video` 仅在顶层 active surface | **Done** |
| `PlaybackController` 仅 media truth | **Done** |
| 开源 feed/player 库 | **不引入**；仅参考 pool/reconcile 思想 |
| 独立 Access/Playback coordinator 文件 | **Defer / 不再拆**（见下） |

### 何时才允许重新拆 PlayerFeedEngine（Current policy）

仅在以下任一条件成立时重新立项，**不**为局部优化或文档完整性单独拆文件：

- 真实播放/权益 API 上线后，现有 engine 边界无法承载新契约（有线上证据）；
- 线上 P0（卡顿、错播、权益事故）归因于 engine 职责过载（有 metrics）；
- 产品明确要求的新播放形态且无法以 policy / runtime config 扩展。

**明确不做：** 继续拆 `AccessCoordinator` / `PlaybackCoordinator` 独立文件；引入第三方 feed/player 库；扩大 session window；PageView 内多 Video。

### 封板策略结论（Current）

- **Android** 默认 `stable`；低端 denylist / `low` tier → `ultraStable`。
- **iOS** 默认 `rich`（单实现 + policy，非双播放器 codebase）。
- **drag** 不触发 runtime；**settled** 后才 evaluate / play / preload / sheet。

## Why This Refactor Is Needed — Historical

The current player has already fixed several obvious issues:

- real `Video` has been moved out of PageView item shells;
- drag page offset no longer writes high-frequency state into Riverpod;
- runtime work waits for PageView settled state;
- locked episodes do not open or prepare unauthorized sources;
- previous/current/next session window already exists;
- player teardown and audio lifecycle are much safer than before.

Even with these improvements, Android device testing still reports that vertical
swiping can feel heavy, especially around locked episodes. This suggests the
remaining problem is not one missing delay or one animation value. The deeper
issue is that `PlayerPage` still acts as a page, runtime coordinator, access
coordinator, overlay coordinator, and surface coordinator at the same time.

The next phase should introduce a real feed player engine so that dragging,
playback, entitlement, overlays, and platform performance policy have clear
boundaries.

## Current Vs Target — Historical (pre-seal planning)

Current implementation status:

- settled-only runtime has been partially implemented;
- real `Video` is already outside PageView item shells;
- PageView item shells are lighter than before;
- drag page offset no longer writes high-frequency Riverpod state;
- locked source open/prepare is blocked before authorization;
- several engine-like files may already exist in work-in-progress branches.

Target implementation:

- `PlayerFeedEngine` becomes the single application-layer entry point for
  viewport, access, playback, overlay, and performance policy coordination;
- Android defaults to stable mode;
- iOS can keep rich motion through policy;
- PageView drag never becomes a playback/access command bus.

Important current gap:

- The recent scroll-follow behavior is closer to rich mode. It should not be
  treated as the Android stable target.
- Android stable specifically means no real video-surface transform or opacity
  animation during drag.
- If a release package still uses scroll-follow transform on Android, Phase R6
  is not complete.

## Core Principle

During drag, the player feed must only move lightweight visual shells.

During drag, the following must not happen:

- entitlement evaluation;
- playback open/play/pause/quiesce;
- source resolve;
- HLS preload or media prepare;
- unlock/recharge sheet presentation;
- session window release;
- native video surface attach/detach.

Only after PageView settles should the final item trigger runtime work.

## Target Architecture

```text
PlayerPage
  ├─ PageView shell host
  ├─ Active video surface host
  ├─ Top bar / action rail / meta UI
  └─ Sheet host

PlayerFeedEngine
  ├─ ViewportController
  │  └─ drag / page offset / candidate index / settled item
  │
  ├─ AccessCoordinator
  │  └─ free / coin locked / recharge required / membership / unavailable
  │
  ├─ PlaybackCoordinator
  │  └─ previous retained / current playing / next prepared
  │
  ├─ OverlayCoordinator
  │  └─ Unlock Now / coin sheet / recharge sheet / dismissed state
  │
  └─ PlatformPerformancePolicy
     ├─ Android stable
     └─ iOS rich
```

`PlayerPlaybackController` should remain the media truth for actual player
state, but `PlayerPage` should no longer call it directly from scattered
listeners. Commands should go through the engine/coordinator boundary.

## Platform Policy

### Android Stable

Android stable mode prioritizes touch response over visual richness:

- no video surface transform during drag;
- no opacity animation on the real video surface;
- no press-to-dim overlay effect;
- no scale animation for transient play/pause feedback;
- PageView drags lightweight shell only;
- settled playable item attaches or switches the active video surface;
- locked/unavailable pages never mount a playable video surface.

### iOS Rich

iOS rich mode may keep richer effects where smooth:

- richer overlay transitions;
- optional video surface follow behavior;
- transient play/pause feedback;
- more polished auto-next motion.

Important: iOS and Android must share the same engine. Do not fork business
logic into two player implementations.

## Open Source References

The plan should stay custom because this product combines short-drama playback,
single-drama episode flow, entitlement, coin unlock, recharge, membership, HLS,
and platform-specific performance behavior. Still, open-source projects can be
used as architecture references.

| Reference | Type | Useful Ideas | Not A Fit For |
| --- | --- | --- | --- |
| `video_pool` | Flutter library with `media_kit` support | fixed player pool, source swap/reuse, visibility threshold, lifecycle reconciliation, memory/thermal awareness | entitlement, unlock sheets, single-drama EP business, current UI contract |
| `flutter_video_feed` | Flutter demo app | vertical feed structure, MVVM-style feed separation, LRU-style lifecycle ideas | not a drop-in package, no entitlement/payment flow |
| `tiktoklikescroller` | scroll physics package | vertical full-screen snapping and threshold behavior | playback, preload, surface lifecycle, access control |
| `progressive_video_cache` | video cache package | future HLS/segment cache ideas | drag lifecycle, PageView runtime orchestration, entitlement |
| `media_kit` examples | playback primitives | player/session/media API behavior | feed orchestration must remain app-specific |

Recommended use:

- Keep custom `ViewportController`, `AccessCoordinator`, and
  `OverlayCoordinator` because these are product-specific.
- Borrow the `video_pool` style of fixed player pool/reconcile for the playback
  coordinator, but do not replace the whole player page with a third-party feed
  widget.
- Do not adopt scroll-only packages as the main fix. They do not address
  media-session lifecycle or unlock flows.

Decision:

- Build `PlayerFeedEngine` in this codebase.
- Use `video_pool` as the closest reference for playback pooling and lifecycle
  reconciliation.
- Avoid directly introducing a third-party feed widget until the custom engine
  path is proven insufficient.

## Implementation Phases

### Phase R1a: Engine Skeleton

Goal: introduce the engine boundary without intentionally changing visuals.

Tasks:

- Add `PlayerFeedEngine` or equivalent application-layer controller.
- Move viewport settled events into the engine input.
- Keep existing UI output behavior while routing decisions through the engine.
- Define engine state fields:
  - viewport state;
  - access presentation;
  - playback command state;
  - overlay command state;
  - performance policy.

Acceptance:

- `PlayerPage` can read engine state.
- Drag still behaves as before.
- No entitlement/playback behavior change yet.

### Phase R1b: Policy Wiring

Goal: introduce policy switches without forcing all platforms into the same
motion model.

Tasks:

- Add `PlayerPerformancePolicy`.
- Android selects stable by default.
- iOS selects rich by default.
- Tests can override policy.
- Existing rich scroll-follow behavior must be guarded behind policy.

Acceptance:

- Android stable can disable rich motion without deleting rich behavior.
- iOS/rich can keep richer motion through the same engine.

### Phase R2: Runtime Commands Only After Settled

Goal: make settled item the only runtime trigger.

Tasks:

- Remove direct `feed.currentItem` runtime calls from `PlayerPage`.
- Engine consumes only final settled item.
- Drag/candidate index changes must not trigger access, playback, preload, or
  sheet work.
- Fast swipe across multiple locked items should only process the final settled
  item.

Acceptance:

- Tests prove drag does not call access evaluation.
- Tests prove drag does not call playback/preload/quiesce/release.
- Tests prove only the final settled item can trigger unlock flow.

### Phase R3: AccessCoordinator

Goal: isolate unlock entitlement decisions from the page and playback runtime.

Tasks:

- Move access presentation calculation out of `PlayerPage`.
- AccessCoordinator outputs:
  - `playable`;
  - `lockedCoins`;
  - `lockedRecharge`;
  - `lockedMembership`;
  - `unavailable`.
- AccessCoordinator must not show sheets and must not call playback.
- It should own pending unlock presentation state if needed.

Acceptance:

- PlayerPage item shell receives only an access presentation enum/model.
- Locked page UI can render without triggering playback.
- Unauthorized source is never opened, prepared, or preloaded.

### Phase R4: OverlayCoordinator

Goal: remove sheet timing and dismissal policy from `PlayerPage`.

Tasks:

- Move dwell timing, dismissed item memory, manual Unlock Now handling, and
  recharge -> coin unlock flow into OverlayCoordinator.
- Auto sheet may fire only for a settled locked item.
- Closing an auto sheet records dismissed state for that item.
- Manual `Unlock Now` bypasses dismissed auto state.

Acceptance:

- Closing sheet does not auto-reopen for the same item.
- Manual `Unlock Now` still opens immediately.
- Fast swipe cannot leave stale timers that pop sheets for old items.

### Phase R5: PlaybackCoordinator

Goal: centralize playback/preload/session-window commands.

Tasks:

- PlaybackCoordinator consumes settled access presentation.
- For `playable`: play/resume current item, then preload/prepare allowed next
  items.
- For locked/recharge/membership: quiesce or keep silent surface state without
  opening unauthorized source.
- For unavailable: block only when necessary.
- Keep previous/current/next window fixed.
- Do not expand player pool.

Acceptance:

- Free -> locked -> free swipe-back restores playback.
- Locked pages stay silent.
- Previous retained and next prepared still work.
- Hidden/tab/background still pauses and releases correctly.

### Phase R6: Android Stable Mode Enforcement

Goal: apply the performance policy consistently.

Tasks:

- Add `PlayerPerformancePolicy` provider.
- Android defaults to stable, iOS defaults to rich.
- Android stable disables:
  - press overlay dimming;
  - overlay opacity animations;
  - video surface transform/opacity animations;
  - transient scale feedback.
- Rich mode remains available through policy.

Acceptance:

- Android stable tests prove no animated opacity/transform is applied to the real
  video surface during drag.
- iOS/rich tests prove policy can keep richer behavior.

### Phase R7: Device Verification

Goal: validate the refactor on real Android hardware.

Required manual paths:

- Single drama continuous swipe: free -> free -> locked -> locked -> free.
- Close unlock sheet and keep swiping.
- Tap `Unlock Now`, close sheet, swipe again.
- Unlock by `Play`, confirm video surface resumes.
- Swipe back from locked to previous free item, confirm playback resumes.
- For You continuous 5+ swipes.
- Switch Home/My list/Profile, confirm no audio.
- App background, confirm no audio.

Metrics/logs:

- PageView item build count;
- PlayerPage build count;
- Video mount/unmount count;
- surface attach/detach count;
- session window hit/miss;
- memory/PSS before and after 10-15 swipes;
- any jank/ANR/crash.

## Implementation Status Checklist

Last updated: 2026-05-17 (O2 Player modal migration).

| Area | Status | Notes |
| --- | --- | --- |
| Real `Video` outside PageView item shell | **Done** | `player_chrome_source_test` + active surface only in `player_playback_layer.dart`. |
| Drag page offset no high-frequency Riverpod write | **Done** | `_pagePositionNotifier` + viewport phase. |
| `PlayerFeedEngine` facade | **Done** | Viewport, settled runtime, overlay schedule, access/sheet flow entry. |
| Runtime waits for settled item | **Done** | Drag 不 evaluate/play/preload/sheet；`PlayerRuntimeCoordinator` drag guard. |
| `PlayerPerformancePolicy` | **Done** | rich / stable / ultraStable 三档；`playerPreloadConfigProvider` 派生。 |
| Android stable enforcement | **Done** | Video surface follows PageView, but no opacity dim / press dim / pause scale / rich transition. |
| iOS rich policy | **Done** | Rich follow/dim/scale behind policy + test override. |
| Access presentation in shell | **Done** | `PlayerAccessPresenter` + engine `accessPresentationFor`. |
| Overlay dwell / dismissed | **Done** | `PlayerOverlayOrchestrator`; engine `prepareAutoUnlockSheet` / `markAutoSheetDismissed`. |
| Manual unlock / retry / recharge flow | **Done** | Engine `prepareManualUnlock`, `retryPlayback`, `completeCoinUnlock`, `continueAfterRechargeSuccess`; Player blocking sheets now go through `AppModalService` / Player modal coordinator. |
| PlaybackCoordinator split | **Defer** | `PlayerRuntimeCoordinator` + `PlayerPlaybackController` 仍承担 play/preload/quiesce；未单独 `PlaybackCoordinator` 文件。 |
| AccessCoordinator split | **Defer** | 逻辑在 `PlayerAccessPresenter` + runtime；未单独 coordinator 文件。 |
| Open-source reference decision | **Done** | 参考 `video_pool` pool/reconcile；不替换 PageView/业务 UI。 |

### Phase Status (R1–R7)

| Phase | Status | Summary |
| --- | --- | --- |
| **R1a** Engine skeleton | **Done** | `PlayerFeedEngine` + state aggregation. |
| **R1b** Policy wiring | **Done** | `PlayerPerformancePolicy` + Android stable / iOS rich. |
| **R2** Settled-only runtime | **Done** | Page 无 drag 路径 evaluate/play；测试覆盖。 |
| **R3** AccessCoordinator | **Partial** | Presenter + engine 入口；未独立 coordinator 类。 |
| **R4** OverlayCoordinator | **Mostly done** | Orchestrator + engine sheet intent；Page 仍 host modal UI。 |
| **R5** PlaybackCoordinator | **Partial** | Runtime coordinator 收口；未再拆文件。 |
| **R6** Android stable | **Done** | Policy + widget tests + device stress (stable path on Android). |
| **R7** Device verification | **Ongoing** | Smoke + stress on device; 见下方设备结论。 |

### Device Validation Notes (2026-05)

| Device | Observation |
| --- | --- |
| Samsung Galaxy A14 (`R58WC02B69R`) | 低端机仍可能卡；通过 `playerPerformanceModeOverrideProvider` / 未来设备分级启用 **ultraStable**，不继续大拆引擎。 |
| Huawei / Honor ELS AN00 (`8MY0221119007507`) | 新 Android 在 **stable** 下滑动明显更好；主架构方向有效。 |

### Explicitly Deferred (next optimization line only)

- `PlayerPage` 编程切集 / `feed.currentIndex` → PageView `animateToPage`（已标 TODO，非 drag）。
- Lifecycle teardown 仍直连 `PlayerPlaybackController`（dispose/visibility/memory）。
- 倍速 / tap-to-play 仍直连 playback（纯 UI 控制，非 feed runtime）。
- 独立 `PlaybackCoordinator` / `AccessCoordinator` 文件拆分（当前 engine + 现有 coordinator 已够用）。
- HLS cache/proxy、扩大 prepared window、多 Video 回 PageView：**不做**。

### Low-end Android Player Policy (2026-05)

**Done (minimal):**

- `PlayerPerformanceMode.ultraStable`：视觉同 stable；HLS preload 0；prepared/retained 0；locked 落位跳过 preloadAround。
- Provider 链：`playerPerformancePolicyOverrideProvider` / `playerPerformanceModeOverrideProvider` / `AppRuntimeConfig.player` / `deviceCapabilityProvider` → `RuntimePerformanceMode` 映射（见 App Runtime Phase A.1）。
- `playerPreloadConfigProvider` 从 policy 派生，playback controller 尊重 prepared/retained cap。

**不做的：**

- 不扩大 session window；不增加 PageView 内 Video；不大改 `PlayerFeedEngine`。
- 复杂 RAM/机型真机识别留 Phase B；A14 可用 `devicePerformanceTierOverrideProvider` → `low` 观测 ultraStable。

## Implemented Files (Seal Snapshot) — Current

以下为**已落地**结构（非待办）。**不再**新增 `player_access_coordinator.dart` /
`player_playback_coordinator.dart` 等平行文件。

| 角色 | 路径 |
| --- | --- |
| UI host | `lib/features/player/presentation/pages/player_page.dart` |
| Application 入口 | `lib/features/player/application/player_feed_engine.dart` |
| Viewport / Runtime / Overlay | `player_viewport_controller.dart`、`player_runtime_coordinator.dart`、`player_overlay_orchestrator.dart` |
| Media truth | `player_playback_controller.dart` |
| Policy | `player_performance_policy.dart`、`player_performance_policy_provider.dart` |
| 单 Video surface | `player_playback_layer.dart`（active surface） |
| 测试 | `test/features/player/player_feed_engine_test.dart`、`player_page_test.dart`、`integration_test/app_smoke_test.dart` |

## Explicit Constraints

- Do not change product unlock rules.
- Do not connect real API.
- Do not introduce HLS local cache/proxy.
- Do not increase prepared session window size.
- Do not mount multiple real `Video` widgets in PageView.
- Do not solve Android jank by adding arbitrary delays.
- Do not split into separate Android/iOS player codebases.

## Definition Of Done

- `PlayerPage` is mostly UI host and no longer owns runtime orchestration.
- Drag path is pure viewport movement.
- Settled item is the only runtime trigger.
- Android stable mode removes high-risk animation and video surface transforms.
- Locked flow remains correct and silent.
- Existing unit/widget tests pass.
- Android smoke passes.
- Android release manual test shows materially improved swipe responsiveness.
