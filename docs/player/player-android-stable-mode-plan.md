# Player Android Stable Mode Plan

> **Document status: Current（封板策略）** — 性能档位与 denylist 以代码与
> `device_performance_tier_rules.dart` 为准；下文 Phase 清单中未勾选项多为 **Historical**。

This document records a standalone player optimization task for Android device
smoothness. The goal is not to fork the whole player into two implementations.
Instead, the player should keep one architecture and switch visual/runtime
policies by platform or device capability.

## Seal Status (封板, 2026-05-16) — Current

- **rich / stable / ultraStable** 三档已落地；Android 默认 stable，iOS 默认 rich。
- Android stable 规则（drag 时 Video 保持可见并跟手 transform，但无 opacity、无 press dim、无 pause scale、无 rich transition）已在代码与 widget 测试中验收。
- **后续工作**：Phase B 真机 RAM/型号自动填入 probe；档位已由 `device_performance_tier_rules` + `deviceCapabilityProvider` 推导。
- **当前**：基础本地 denylist（Samsung A14 / SM-A145* / Galaxy A14）命中 → `low` → `ultraStable`。
- **不引入**第三方 feed/player 库。

### 封板策略（Current）

| 平台 / 条件 | 档位 |
| --- | --- |
| Android 默认 | `stable` |
| Android 低端 denylist / `low` tier | `ultraStable` |
| iOS 默认 | `rich` |
| 实现方式 | 单播放器 + `PlayerPerformancePolicy`，**非** Android/iOS 两套实现 |

### 拖动时 Video surface 策略（Current）

| 档位 | 可见 | 跟手 Transform | opacity 压暗 | chrome 按压渐隐 | pause scale | rich 转场 |
| --- | --- | --- | --- | --- | --- | --- |
| `rich` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stable` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ultraStable` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

当前结论：

- `stable` 要点：与 `rich` 一样用 `Transform.translate` 跟 PageView；拖动时 opacity 恒为 1.0，无压暗/渐隐/缩放等额外动画。
- `ultraStable`：拖动时切整层 `SizedBox.shrink()`，不挂 surface，优先保证低端机手势流畅。
- 不允许为了跟手把多个真实 `Video` 放回 PageView item；真实 Video 仍只在顶层 active playback surface。

后续仅做 **Phase B** 真机 model/RAM 填入 probe；不继续拆 engine、不生产化 local proxy。

## Background — Historical context

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
- Low-end Android: `ultraStable` when `DevicePerformanceTier.low` (denylist / RAM<=3GB / test override; remote override 仍可覆盖)
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

### 2. Keep Stable Drag Follow Lightweight

On Android stable mode:

- keep the real `Video` surface visible during PageView drag;
- allow only the necessary `Transform.translate` that keeps video aligned with the PageView shell;
- do not animate video surface opacity;
- do not add chrome dimming, scale feedback, or rich transitions;
- locked and unavailable pages must not mount a playable `Video` surface.

This keeps the short-drama feed visually coherent on normal Android devices
while still avoiding the heavier visual effects reserved for rich mode.

On Android ultraStable mode:

- hide the real `Video` surface during drag;
- do not transform or opacity-animate the real `Video` surface;
- prioritize touch response over visual continuity.

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

- Android stable should keep the real video surface visible and aligned with
  PageView drag via lightweight transform only.
- Android stable should not opacity-animate, dim chrome, or scale feedback
  during drag.
- Android ultraStable should hide the real video surface during drag.
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
- Android stable transforms the real video surface during drag but keeps
  opacity fixed and disables chrome dim / scale feedback.
- Android ultraStable hides the real video surface during drag.
- Dragging across locked items does not trigger entitlement evaluation or sheet.
- Settled locked item shows `Unlock Now`.
- Manual `Unlock Now` opens the correct sheet.
- Free -> locked -> free swipe-back restores playback without background audio.

## Acceptance Criteria

- Android stable mode release build installs and runs on the test device.
- Vertical drag feels visually coherent on stable devices: video and PageView
  shell move together without extra opacity/scale/chrome animation.
- Low-end ultraStable devices can still hide Video during drag to prioritize
  touch response.
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
- **Samsung A14**: denylist 命中后自动 `ultraStable`；若 probe 尚无真型号（Phase B 前），可用
  `--dart-define=DEVICE_MODEL=SM-A145F` 或 `deviceHardwareSnapshotProvider` override 验证。

### Provider entry points

- `playerPerformancePolicyOverrideProvider` — full policy object
- `playerPerformanceModeOverrideProvider` — `rich` / `stable` / `ultraStable`
- `device_performance_tier_rules.dart` — denylist + RAM 规则
- `device_capability_probe.dart` — 启动硬件快照（Phase B 真机读取）
- `deviceCapabilityProvider` — 一次性分级；override 仍可覆盖
- `appRuntimeConfigProvider.player` — grouped `RuntimePlayerConfig` (remote stub null in Phase A)
- `runtime_performance_mode_mapper.dart` — `RuntimePerformanceMode` → `PlayerPerformanceMode`
- `playerPreloadConfigProvider` — player preload **统一入口**（HLS + policy cap）

Do not scatter `Platform.isAndroid` or model checks in UI or runtime code.
