# App Runtime Foundation Plan

This document defines the global runtime foundation for the client app. It is
not a feature-specific system. It provides one place for device capability,
runtime config, feature flags, localization package metadata, and performance
policy.

The player low-end Android policy is the first consumer, but the system must be
usable by Home, Store, Membership, Wallet, Localization, API switches, and later
experiments.

## Goals

- Initialize global runtime state once during app startup.
- Expose device capability to the whole app.
- Prepare a single remote-config boundary for server-controlled behavior.
- Provide feature flags and performance policy through one typed model.
- Prepare localization package version/update metadata.
- Avoid feature modules making their own device/model/config decisions.
- Keep mock/local defaults working before real backend integration.

## Phase A Status (2026-05-16) — Done

Implemented skeleton (no UI / no player flow changes / no real API):

| Item | Location |
| --- | --- |
| `DeviceCapability` + `DevicePerformanceTier` | `lib/core/runtime/device_capability.dart` |
| Device providers + test overrides | `lib/core/runtime/device_capability_provider.dart` |
| Grouped `AppRuntimeConfig` | `lib/core/runtime/app_runtime_config.dart` |
| `RuntimePlayerConfig` | `lib/core/runtime/runtime_player_config.dart` |
| `RuntimeLocalizationConfig` | `lib/core/runtime/runtime_localization_config.dart` |
| `RuntimeFeatureFlagConfig` + keys | `lib/core/runtime/runtime_feature_flag_config.dart` |
| `RuntimePerformanceMode` (feature-neutral) | `lib/core/runtime/runtime_performance_mode.dart` |
| Config providers (defaults / remote stub / test override) | `lib/core/runtime/app_runtime_config_provider.dart` |
| Player tier mapping | `lib/features/player/application/runtime_performance_mode_mapper.dart` |
| `playerPerformanceModeFromDeviceProvider` | `player_performance_policy_provider.dart` |
| `playerPreloadConfigProvider` (final preload entry) | `player_preload_config_provider.dart` |
| Architecture boundary test | `test/architecture/runtime_boundary_test.dart` |

## Phase A.1 Status (2026-05-16) — Done

**Structured runtime config** — `core/runtime` has **no** `features/` imports.

```text
AppRuntimeConfig
  ├─ player: RuntimePlayerConfig      # HLS preload, performance mode, timing logs
  ├─ localization: RuntimeLocalizationConfig
  └─ featureFlags: RuntimeFeatureFlagConfig
```

Player consumes runtime via application-layer mapping:

`RuntimePerformanceMode` → `PlayerPerformanceMode` → `PlayerPerformancePolicy`

`playerPreloadConfigProvider` remains the **single entry** for HLS preloader / startup / playback preload.

**Priority (production path):**

```text
Player: full policy override > mode override > AppRuntimeConfig.playerPerformanceModeOverride > device tier > platform default
AppRuntimeConfig: test override > remote merge > device rules > defaults
```

**Still deferred (Phase B+):** real RAM/model via `device_info_plus` / platform channel, `package_info` for app version, secure local config cache, remote config fetch/repository, startup `AppRuntimeController`, localization bundle download, `RuntimeExperimentConfig`.

Remote config fetch failure must not block app boot — Phase A remote provider is always `null`.

**API metadata (unchanged this phase):** `apiDeviceIdProvider` / `apiAppVersionProvider` remain dart-define fallbacks; future install id / package info may reuse runtime device layer without coupling to performance tier.

## Non-Goals For Phase 1

- Do not connect a real remote config API.
- Do not download real localization JSON packages yet.
- Do not implement full A/B experiments.
- Do not replace existing l10n implementation yet.
- Do not change player business logic beyond consuming runtime-derived policy.
- Do not add feature-specific remote fetches inside player/home/store directly.

## Target Structure

```text
lib/core/runtime/
  app_runtime_controller.dart
  app_runtime_state.dart
  app_runtime_repository.dart
  app_runtime_config.dart
  app_runtime_feature_flags.dart
  app_runtime_performance_policy.dart
  app_runtime_localization_config.dart

lib/core/device/
  device_capability.dart
  device_capability_repository.dart
  platform_device_capability_repository.dart
  mock_device_capability_repository.dart
```

The exact file names can be adjusted to match existing project conventions, but
the boundary should stay global and feature-neutral.

## Runtime State Model

Suggested top-level state:

```dart
class AppRuntimeState {
  final bool isLoading;
  final Object? error;
  final DeviceCapability device;
  final AppRuntimeConfig config;
  final AppRuntimeFeatureFlags featureFlags;
  final AppRuntimePerformancePolicy performancePolicy;
  final AppRuntimeLocalizationConfig localization;
}
```

### DeviceCapability

Suggested fields:

- `platform`: `android`, `ios`, `web`, `macos`, etc.
- `brand`
- `manufacturer`
- `model`
- `device`
- `androidSdk`
- `supportedAbis`
- `totalMemoryMb`
- `cpuCores`
- `tier`: `low`, `medium`, `high`
- `isLowEnd`

Suggested enum:

```dart
enum DevicePerformanceTier {
  low,
  medium,
  high,
}
```

Initial tier rules:

- Android RAM <= 4096 MB -> low
- Android CPU cores <= 4 -> low
- Android SDK <= 29 -> low
- known low-end model list -> low
- other Android -> medium
- iOS -> high
- unknown platform -> medium

These are defaults only. Remote config can override later.

### AppRuntimeConfig

Suggested fields:

- `configVersion`
- `fetchedAt`
- `deviceRules`
- `player`
- `home`
- `commerce`
- `localization`

Keep feature-specific values typed. Do not expose raw JSON maps to UI.

### AppRuntimeFeatureFlags

Suggested fields:

- `enableRemoteDramaApi`
- `enableRemotePlayerApi`
- `enableRemoteMyListApi`
- `enableRemoteWalletApi`
- `enableRemoteStoreApi`
- `enableRemoteMembershipApi`
- `enableRemoteAuthApi`
- `enableRuntimeLocalizationBundle`
- `enableLowEndAndroidPolicy`

These should complement existing `--dart-define` switches, not remove them in
Phase 1.

### AppRuntimePerformancePolicy

Suggested fields:

- player performance mode: `rich`, `stable`, `ultraStable`
- image quality tier
- animation policy
- list preload policy
- shimmer/skeleton policy

The first real consumer is player:

- low-end Android -> `PlayerPerformanceMode.ultraStable`
- normal Android -> `PlayerPerformanceMode.stable`
- iOS/high -> `PlayerPerformanceMode.rich`

### AppRuntimeLocalizationConfig

Suggested fields:

- `fixedBundleVersion`
- `remoteBundleVersion`
- `bundleUrl`
- `supportedLanguages`
- `contentLanguage`
- `lastUpdatedAt`

Phase 1 only models this data. Real JSON download and l10n lookup migration are
deferred.

## Source Priority

Runtime decisions should be merged in this order:

```text
Test/debug override
> Remote config
> Device capability rules
> Local cached config
> App defaults
```

Phase 1 can implement:

```text
Test override
> Device capability rules
> App defaults
```

Remote and local cache boundaries should exist but can stay mock/in-memory.

## Startup Flow

```text
App start
  ↓
Create default AppRuntimeState
  ↓
Load cached runtime config if available
  ↓
Read device capability
  ↓
Merge defaults + cached config + device rules
  ↓
Expose AppRuntimeState to app
  ↓
Later: fetch remote runtime config in background
  ↓
Persist and notify consumers if config changes
```

The UI should be able to start with defaults. Runtime loading failure must not
block app boot.

## Repository Boundaries

### DeviceCapabilityRepository

Responsibilities:

- read platform/device info;
- read Android RAM and CPU cores when possible;
- return safe fallback values when unavailable.

Android implementation options:

- `device_info_plus` for brand/model/sdk/ABI;
- platform channel for:
  - `ActivityManager.MemoryInfo.totalMem`;
  - `Runtime.getRuntime().availableProcessors()`.

Phase 1 can use platform channel or a small local Android helper. If the team
wants to avoid native code initially, return null RAM/CPU and rely on model/API
rules.

### AppRuntimeRepository

Responsibilities:

- load cached runtime config;
- fetch remote runtime config later;
- save runtime config;
- return mock/local defaults for Phase 1.

Do not let feature modules fetch runtime config directly.

## Player Integration

Current player policy provider should become a consumer of runtime foundation.

Target:

```text
AppRuntime.performancePolicy.playerMode
  -> PlayerPerformancePolicy.forMode(...)
```

Rules:

- Test override remains highest priority.
- Player-specific override remains available for tests.
- Runtime-derived mode should be the normal production path.
- Android low-tier device maps to `ultraStable`.
- Android medium maps to `stable`.
- iOS/high maps to `rich`.

Do not move playback logic into runtime. Runtime only supplies policy.

## Localization Integration

Phase 1 only models localization package metadata.

Later phases:

- compare local fixed bundle version with remote version;
- download JSON language bundle;
- store it locally;
- expose l10n lookup through a runtime localization repository;
- request content APIs with current `Lang`.

Content localization remains separate from fixed UI strings:

- fixed UI text: runtime language package / app fallback;
- drama content: backend returns localized title/synopsis/subtitles based on
  `Lang`.

## Remote Config Shape Example

```json
{
  "configVersion": "2026.05.16.1",
  "deviceRules": {
    "lowEndRamMb": 4096,
    "lowEndCpuCores": 4,
    "lowEndAndroidSdkMax": 29,
    "lowEndModels": ["SM-A145F"]
  },
  "player": {
    "androidDefaultMode": "stable",
    "lowEndMode": "ultraStable",
    "singleDramaForwardPreload": 1,
    "forYouForwardPreload": 1
  },
  "localization": {
    "fixedBundleVersion": "1.0.3",
    "remoteBundleVersion": "1.0.4",
    "bundleUrl": "https://example.com/l10n/en.json",
    "supportedLanguages": ["en", "es", "pt", "hi"]
  },
  "featureFlags": {
    "enableRemoteDramaApi": false,
    "enableRuntimeLocalizationBundle": false
  }
}
```

## Implementation Phases

### Phase A: Runtime Foundation Skeleton — **Done (2026-05-16)**

Delivered:

- `DeviceCapability` / `DevicePerformanceTier` + platform fallback providers.
- `AppRuntimeConfig` + merge (defaults → device rules → remote stub → test override).
- Player policy + preload wired; tests in `test/core/runtime/`.

Not in Phase A (deferred):

- `AppRuntimeState` / `AppRuntimeController` monolith.
- Separate repository files under `lib/core/device/` (names in plan are illustrative).
- Real remote fetch / local cache.

Acceptance: met — providers testable; missing remote/device info falls back safely.

### Phase B: Platform Device Capability

Tasks:

- Add platform device repository.
- Use `device_info_plus` or existing platform info for brand/model/sdk.
- Add Android RAM/CPU retrieval through platform channel if approved.
- Compute low/medium/high tier.

Acceptance:

- Android device returns model/sdk and best-effort RAM/CPU.
- iOS returns high fallback.
- Tests can override device capability.

### Phase C: Player Runtime Policy Integration — **Done in Phase A (2026-05-16)**

`playerPerformancePolicyProvider` and `playerPreloadConfigProvider` consume
`deviceCapabilityProvider` and `appRuntimeConfigProvider`. Test overrides unchanged.

Acceptance: covered by `player_performance_policy_test.dart` and
`player_preload_config_provider_test.dart`.

### Phase D: Runtime Config / Feature Flags Skeleton

Tasks:

- Add mock remote runtime config parsing.
- Add cached config boundary (in-memory or local placeholder only).
- Add feature flag provider access.
- Do not turn on remote feature switches by default.

Acceptance:

- Tests can override runtime config and feature flags.
- Existing `--dart-define` switches continue working.
- No real server dependency.

### Phase E: Localization Metadata Skeleton

Tasks:

- Add runtime localization config model.
- Add version/bundle URL fields.
- Add tests for supported language metadata.
- Do not replace current `AppLocalizations` yet.

Acceptance:

- Runtime state can expose localization metadata.
- Future JSON language package download has a clear place to attach.

## Validation

Required:

```bash
dart format lib test integration_test
flutter analyze
flutter test
```

When player integration is touched:

```bash
flutter test integration_test/app_smoke_test.dart -d 8MY0221119007507
```

If old low-end device is connected:

```bash
flutter test integration_test/app_smoke_test.dart -d R58WC02B69R
```

## Explicit Constraints

- Do not block app launch if runtime config/device detection fails.
- Do not let feature modules fetch runtime config directly.
- Do not store raw remote JSON in UI/application state.
- Do not turn on real remote APIs through runtime config in Phase 1.
- Do not replace current localization lookup in Phase 1.
- Do not move player playback logic into runtime foundation.

## Definition Of Done

- A global runtime provider exists and is usable by any feature.
- Device capability and performance tier are typed and testable.
- Player policy can be derived from runtime tier.
- Runtime config, feature flags, and localization metadata have typed skeletons.
- Tests cover fallback behavior and override priority.
- Documentation clearly states deferred remote config and localization download.

