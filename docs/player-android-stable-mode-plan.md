# Player Android Stable Mode Plan

This document records a standalone player optimization task for Android device
smoothness. The goal is not to fork the whole player into two implementations.
Instead, the player should keep one architecture and switch visual/runtime
policies by platform or device capability.

## Seal Status (封板, 2026-05-16)

- **rich / stable / ultraStable** 三档已落地；Android 默认 stable，iOS 默认 rich。
- Android stable 规则（无 drag 时 video transform/opacity、无 press dim、无 pause scale）已在代码与 widget 测试中验收。
- **后续工作**：仅低端机 policy（`ultraStable`、预留 `playerPerformanceModeFromDeviceProvider`），**不**再拆第二套播放器或 Android/iOS 双实现。
- **不引入**第三方 feed/player 库。

## Background

Recent player-feed work reduced several obvious bottlenecks:

- playback/runtime work now waits for PageView settled state;
- high-frequency page offset no longer writes into Riverpod;
- real `Video` has been removed from PageView item shells;
- poster backdrop can be disabled so the feed shell is lighter;
- locked pages no longer open or prepare unauthorized sources.

However, Android physical-device feedback still reports that vertical swiping
can feel heavy, especially around locked episodes. The likely remaining issue is
not one isolated delay. It is the combined cost of Android video surface
composition, opacity/transform animations, overlay changes, and sheet/runtime
state changes near the swipe path.

## Goal

Android should prioritize stable touch response over rich motion.

The target experience:

- vertical swiping feels light and immediately follows the finger;
- locked/free/unavailable pages do not stall the gesture;
- video never leaks audio when hidden or locked;
- unlocking still follows the product flow;
- iOS can keep richer transitions where they remain smooth.

## Non-Goals

- Do not create separate Android and iOS player codebases.
- Do not put multiple real `Video` widgets back into PageView items.
- Do not expand the prepared media session window.
- Do not change entitlement, payment, or unlock business rules.
- Do not add HLS local cache/proxy work in this task.
- Do not replace `media_kit`.
- Do not connect real backend APIs.

## Proposed Design

Introduce a typed player performance policy:

```dart
enum PlayerPerformanceMode {
  rich,
  stable,
  ultraStable,
}
```

Default behavior:

- Android: `stable`
- iOS: `rich`
- Low-end Android: `ultraStable` via override / future device tier (not auto-detected yet)
- Tests: overrideable provider

The policy must be consumed by presentation/runtime glue only. Playback truth
must remain in `PlayerPlaybackController`.

## Android Stable Rules

### 1. Disable Non-Essential Overlay Animation

On Android stable mode:

- do not dim non-video overlays on press;
- do not animate overlay opacity during drag;
- `_OverlayOpacity` should return the child directly or use a fixed opacity;
- remove scale animation from transient play/pause feedback;
- keep only essential loading, retry, and unlock affordances.

### 2. Avoid Transform/Opacity On Real Video Surface

On Android stable mode:

- do not transform the real `Video` surface during PageView drag;
- do not animate video surface opacity;
- PageView should drag only lightweight shell content;
- after PageView settles, attach or switch the current playable video surface;
- locked and unavailable pages must not mount a playable `Video` surface.

This intentionally sacrifices "video follows finger" polish on Android in favor
of stable touch response.

### 3. Keep Drag Path Pure

During drag:

- no entitlement evaluation;
- no automatic sheet presentation;
- no playback open/prepare/release;
- no source resolve;
- no HLS preload scheduling;
- no heavy native surface attach/detach.

After settled:

- evaluate only the final item;
- play only if playable;
- show unlock UI only for the settled locked item;
- preload only from the settled runtime state.

### 4. Locked Page Handling

On Android stable mode:

- locked pages render a lightweight shell and `Unlock Now` affordance;
- auto sheet may still dwell after settle, but must never schedule during drag;
- closing a sheet should not immediately auto-reopen for the same item;
- manual `Unlock Now` still opens the corresponding flow immediately;
- locked source must not open/preload/prepare before authorization.

### 5. Keep iOS Rich Mode Available

iOS rich mode may keep:

- richer overlay opacity changes;
- video surface follow behavior if stable;
- transient play/pause visual feedback;
- smoother motion around auto-next.

But rich mode must remain behind policy, not scattered platform checks.

## Implementation Phases

### Phase A: Policy Layer

- Add `PlayerPerformancePolicy` and provider.
- Android defaults to stable, iOS defaults to rich.
- Tests can override the policy.
- Add code comments in Chinese for each policy field explaining why it exists
  and what tradeoff it controls.

### Phase B: Disable Android High-Risk Animations

- Disable press overlay dimming on Android stable.
- Make overlay opacity static on Android stable.
- Disable transient play/pause scale animation on Android stable.
- Keep loading/retry/unlock UI functional.

### Phase C: Stabilize Android Video Surface

- Android stable should not transform or opacity-animate the real video surface
  during PageView drag.
- PageView should drag lightweight shell only.
- Settled playable item attaches the active video surface.
- Locked/unavailable/no-source items do not mount video.

### Phase D: Runtime Timing Guard

- Ensure drag does not trigger access, sheet, preload, prepare, open, release,
  or quiesce.
- Settled final item is the only item that can trigger runtime commands.
- Add tests for fast swipes across free/locked/free and locked/locked pages.

### Phase E: Android Device Verification

- Build release package.
- Install on Android test device.
- Test at least:
  - single drama: free -> free -> locked -> locked -> free;
  - close unlock sheet and continue swiping;
  - tap `Unlock Now`, close sheet, swipe again;
  - unlock by Play and confirm video surface resumes;
  - For You continuous 5+ swipes;
  - tab switch and app background no audio.
- Record whether stable mode improves drag feel.

## Suggested Tests

- Android stable policy is selected by default.
- iOS rich policy is selected by default.
- Android stable does not dim overlay on press.
- Android stable does not animate overlay opacity.
- Android stable does not transform the real video surface during drag.
- Dragging across locked items does not trigger entitlement evaluation or sheet.
- Settled locked item shows `Unlock Now`.
- Manual `Unlock Now` opens the correct sheet.
- Free -> locked -> free swipe-back restores playback without background audio.

## Acceptance Criteria

- Android stable mode release build installs and runs on the test device.
- Vertical drag no longer feels blocked by overlay animation or video-surface
  transform work.
- Locked pages remain interactive and do not leak audio.
- iOS/rich behavior is not removed; it is controlled by policy.
- Existing player, entitlement, and smoke tests pass.

## Developer Notes

This task is intentionally about interaction stability, not visual perfection.
If a choice improves Android touch response but slightly reduces animation
richness, choose stability for Android stable mode.

Do not add more timing delays to hide symptoms. Prefer removing work from the
drag path and moving real runtime commands to the settled phase.

## Ultra-stable Tier (Low-end Android, 2026-05)

`PlayerFeedEngine` refactor is complete. Further work on low-end devices uses
**policy only**, not another engine rewrite.

### Ultra-stable vs stable

| Capability | stable | ultraStable |
| --- | --- | --- |
| Video follow / opacity / chrome dim / pause scale | off | off |
| HLS forward/back preload count | 1 | 0 |
| prepared forward session | 1 (cap) | 0 |
| retained backward session | 1 (cap) | 0 |
| preload on settled locked item | allowed | skipped |

### Device observations

- **ELS AN00**: stable mode already feels noticeably smoother than A14-class
  devices; validates settled runtime + single Video architecture.
- **Samsung A14**: may still feel heavy on stable; enable `ultraStable` via
  `playerPerformanceModeOverrideProvider` for field tests before automatic
  device tier detection ships.

### Provider entry points

- `playerPerformancePolicyOverrideProvider` — full policy object
- `playerPerformanceModeOverrideProvider` — `rich` / `stable` / `ultraStable`
- `playerPerformanceModeFromDeviceProvider` — reserved for RAM/API/brand/model

Do not scatter `Platform.isAndroid` or model checks in UI or runtime code.
