# Short Drama Client Technical Architecture

## 1. Project Goal

Build a Flutter-based short drama client focused on fast browsing, stable video playback, clear paid unlock flows, and measurable growth loops.

The first product version should prioritize:

- Smooth short drama feed and episode playback.
- Reliable login, entitlement, and in-app purchase flows.
- Playback progress, history, recommendation, and analytics events.
- A codebase structure that can grow into domestic Android channels, subscriptions, DRM, and offline caching when needed.

## 2. Version Strategy

### Flutter

Use Flutter stable `3.41.9` as the first locked project version.

Rationale:

- Confirmed by `fvm releases` as stable, released on Apr 30, 2026.
- `media_kit` itself does not force a very new Flutter baseline, but the rest of the client stack benefits from a newer stable version.
- New enough to satisfy packages requiring Dart 3.10 or 3.11, including current routing, package metadata, codegen, and utility packages.
- Avoids the dependency downgrade pressure that would come from starting on an older Flutter line.

Do not downgrade Flutter only because `media_kit` can run on older Dart versions. The player is only one part of the app; the full short drama client also depends on payment, push, analytics, app metadata, storage, and code generation packages.

Version decision matrix:

| Flutter line | Fit | Assessment |
|---|---|---|
| `3.20.x` - `3.29.x` | Not recommended | Can run some `media_kit` versions, but likely forces downgrades across routing, app metadata, utility plugins, and build tooling. The project would start with technical debt. |
| `3.30.x` - `3.37.x` | Possible but awkward | Better than 20.x, but still below the current comfort line for packages requiring Dart 3.10 or Flutter 3.38+. Use only if an existing native dependency forces it. |
| `3.38.x` | Minimum comfortable line | Good fallback line because it aligns with Dart 3.10-era packages and current plugin requirements such as `package_info_plus 10.x`. |
| `3.41.9` | Recommended | Current confirmed stable line in this environment, compatible with `media_kit` and the broader app stack, and avoids unnecessary dependency downgrades. |

Recommendation: use `3.41.9` for new development. If a future blocker appears, the conservative fallback should be the latest `3.38.x` patch, not a 20.x or early 30.x release.

Recommended setup:

```bash
fvm install 3.41.9
fvm use 3.41.9
fvm flutter doctor
```

All Flutter commands should go through FVM:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter test
fvm flutter build apk
fvm flutter build ios
```

### Platform Baseline

Recommended minimum platform versions:

- Android: `minSdkVersion 24`
- iOS: `deployment target 13.0`

This keeps the app aligned with current Flutter plugin support matrices and avoids spending early development time on old-device edge cases.

## 3. Target Platforms

MVP targets:

- Android
- iOS

Secondary targets:

- Web preview or admin preview only if needed.
- macOS only for internal testing if useful.

Domestic Android distribution should be treated as a separate integration track because push, payment, compliance SDKs, and store rules differ across channels.

## 4. Architecture Overview

Use a feature-first Flutter architecture with clear internal layers.

```text
lib/
  app/
    app.dart
    router/
    theme/
    lifecycle/
  core/
    config/
    constants/
    error/
    network/
    storage/
    analytics/
    logging/
    utils/
  features/
    auth/
    home/
    drama/
    player/
      application/
        player_session_controller.dart
        playback_progress_reporter.dart
        playback_preload_coordinator.dart
      data/
        playback_remote_data_source.dart
        playback_repository_impl.dart
      domain/
        playback_media.dart
        playback_repository.dart
      presentation/
        pages/
        widgets/
    wallet/
    profile/
    search/
    notification/
  shared/
    widgets/
    models/
    extensions/
```

Each feature should generally follow:

```text
feature/
  data/
    dto/
    repository_impl.dart
    remote_data_source.dart
    local_data_source.dart
  domain/
    entities/
    repository.dart
    use_cases/
  presentation/
    pages/
    widgets/
    controllers/
```

For very small features, avoid excessive ceremony. Add layers when the feature has real business logic, persistence, or test value.

## 5. Recommended Package Stack

| Area | Package | Purpose |
|---|---|---|
| State management | `flutter_riverpod` | App state, async state, dependency injection |
| Routing | `go_router` | Declarative routes, guards, deep-link entry |
| Network | `dio` | API requests, interceptors, cancellation, upload/download |
| Models | `freezed`, `json_serializable` | Immutable DTOs/entities and JSON parsing |
| Video | `media_kit`, `media_kit_video`, `media_kit_libs_video` | Primary playback engine and video rendering |
| Video fallback | `video_player_media_kit` or `video_player` | Compatibility bridge or lightweight official fallback if needed |
| Image cache | `cached_network_image` | Drama covers, avatars, banners |
| Key-value storage | `shared_preferences` | Non-critical settings and flags |
| Secure storage | `flutter_secure_storage` | Access tokens, refresh tokens, device secrets |
| Local database | `drift` | History, cached metadata, pending events |
| Deep links | `app_links` | App links, universal links, custom schemes |
| In-app purchase | `in_app_purchase` | App Store and Google Play purchases |
| Push | `firebase_messaging` | FCM push for overseas/Google Play path |
| Analytics | `firebase_analytics` or vendor SDK | Event tracking and funnels |
| Crash reporting | `sentry_flutter` or `firebase_crashlytics` | Crash and error monitoring |
| Network status | `connectivity_plus` | Network type signal, not a source of truth |
| App metadata | `package_info_plus` | App version, build number, package name |
| Screen wake lock | `wakelock_plus` | Prevent screen sleep during playback |

## 6. Core Functional Modules

### 6.1 Auth

Responsibilities:

- Guest identity.
- Phone/email/social login if required.
- Token refresh.
- Account binding.
- Logout and account deletion.

Storage:

- Access token and refresh token in `flutter_secure_storage`.
- Non-sensitive profile cache in local database or memory.

Key rules:

- Never store payment entitlements as trusted local-only data.
- Always refresh user entitlement from backend after login, purchase, restore purchase, or unlock.

### 6.2 Home And Recommendation Feed

Responsibilities:

- Recommended drama feed.
- Hot, new, category, ranking, and continue-watching sections.
- Pagination and pull-to-refresh.
- Exposure and click tracking.

Implementation notes:

- Use backend-provided paging cursors instead of page numbers if recommendations are personalized.
- Keep feed cards lightweight. Do not initialize video controllers in the feed list unless the design explicitly requires inline playback.
- Cache cover images and basic drama metadata.

### 6.3 Drama Detail

Responsibilities:

- Drama metadata.
- Episode list.
- Current unlock state.
- Continue watching entry.
- Favorite, share, and related drama.

The detail page should consume a single backend aggregate API where possible:

```text
GET /dramas/{dramaId}
```

Suggested response content:

- Drama profile.
- Episode list or first page of episodes.
- User-specific unlock state.
- Last watched episode and progress.
- Related recommendations.

### 6.4 Player

Responsibilities:

- Episode playback.
- Auto-play and auto-next.
- Preload next episode metadata and playback URL.
- Progress reporting.
- Trial ending and paid unlock overlay.
- Gesture control.
- Playback error handling.

Primary packages:

```yaml
media_kit: ^1.2.6
media_kit_video: ^2.0.1
media_kit_libs_video: ^1.0.7
```

Use `media_kit` as the playback foundation and build a custom player UI on top of it. Initialize it once during app startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const App());
}
```

Short drama playback needs product-specific controls:

- Tap to pause/play.
- Vertical swipe for previous/next episode if product design requires.
- Episode selector.
- Unlock prompt.
- Like/favorite/comment/share controls.
- Playback progress and resume.
- Weak-network retry.

Why `media_kit`:

- Better codec coverage than the official `video_player` path.
- GPU-powered rendering and a stronger fit for a video-heavy app.
- More consistent behavior across platforms because much of the player stack is shared.
- Room for advanced playback work such as playlists, buffering control, and richer player state handling.
- Built-in support for playlists, rate changes, track selection, subtitles, HTTP headers, screenshots, and custom video controls.

`media_kit` implementation rules:

- Own `Player` instances inside the player feature, not directly inside random UI widgets.
- Pair each active `Player` with a `VideoController`.
- Dispose player resources deterministically when leaving playback or replacing a playback session.
- Use `Player.stream.*` for UI state and analytics triggers.
- Use `Media` extras for episode identifiers, drama identifiers, signed URL metadata, and analytics context.
- Do not mix `media_kit_libs_video` and `media_kit_libs_audio`; video libraries already include audio support.

Recommended player subcomponents:

```text
PlayerSessionController
  Owns active Player and VideoController.
  Opens current episode media.
  Handles play, pause, seek, next, previous, retry, dispose.

PlaybackPreloadCoordinator
  Fetches next episode metadata and signed playback URL.
  Prepares queue information without over-allocating native player instances.

PlaybackProgressReporter
  Subscribes to position, playing, completed, and buffering streams.
  Emits local and remote progress events.

PlaybackEntitlementGuard
  Checks trial, unlock, coin, subscription, and purchase state.
  Decides whether playback can continue or should show unlock UI.
```

Playback list strategy:

- For short drama vertical playback, start with one active `Player`.
- Preload metadata and signed URLs for adjacent episodes first.
- Only introduce multiple active players if swipe-to-next latency is proven unacceptable on real devices.
- Use `Playlist` or `player.open` replacement depending on final interaction design.

Android build notes:

- Prefer Android App Bundle for production distribution.
- For APK testing, enable ABI splitting to avoid unnecessarily large universal APKs.
- Test release/profile builds because media performance is substantially better than debug builds.

Player alternatives:

- `video_player_media_kit`: useful if a third-party widget expects the `video_player` API while the runtime should still be backed by `media_kit`.
- `video_player`: useful as a lighter official-plugin fallback if the app only needs platform-native HLS playback and minimal controls.
- `fvp`: useful if FFmpeg-based fallback, Dolby Vision, decoder selection, or lower-level video controls become necessary.

Avoid making `better_player` the default foundation because the original package has slower maintenance. Re-evaluate forks only if a specific advanced feature justifies it.

Playback URL strategy:

- Backend returns signed playback URLs.
- Prefer HLS for adaptive streaming.
- Use HTTPS only.
- Do not hardcode CDN origin URLs in the client.
- Include request headers only when the CDN and player path are confirmed to support them consistently.

Progress reporting:

- Report playback start.
- Report heartbeat at controlled intervals, for example every 10-15 seconds.
- Report pause, resume, seek, completion, and episode switch.
- Store failed progress events locally and retry later.

### 6.5 Wallet, Purchase, And Entitlement

Responsibilities:

- Product list.
- Coin balance.
- Membership or subscription state.
- Episode unlock.
- Order creation and verification.
- Restore purchases.

Primary package:

```yaml
in_app_purchase: ^3.2.3
```

Recommended purchase flow:

```text
Client fetches products from backend
-> Client queries store product details
-> User starts purchase
-> Store returns purchase update
-> Client sends receipt/token to backend
-> Backend verifies with Apple/Google
-> Backend grants coins/subscription/unlock
-> Client refreshes wallet and entitlement
```

Rules:

- Client must not grant final entitlement by itself.
- Backend must be the source of truth for coins, subscriptions, and episode unlocks.
- Call purchase completion only after server-side processing succeeds according to store requirements.
- Consumables must be mapped carefully between store transactions and backend coin grants to avoid double grants.

Domestic Android note:

- Google Play Billing does not cover most domestic Android channels.
- If the product targets Chinese Android app stores, plan separate payment integration through official SDKs or approved payment methods.
- Use Platform Channels for payment SDKs when community plugins are not mature enough.

### 6.6 Search And Category

Responsibilities:

- Search suggestions.
- Drama search results.
- Category filtering.
- Ranking pages.

Keep search API server-driven to support ranking experiments without client releases.

### 6.7 Profile

Responsibilities:

- User profile.
- Watching history.
- Favorites.
- Purchases.
- Settings.
- Customer support entry.
- Terms, privacy, and account deletion.

Compliance-sensitive entries should be visible and easy to reach before app review.

### 6.8 Notification

Responsibilities:

- Push permission request.
- Device token registration.
- Notification click routing.
- Drama update reminders.
- Campaign recall.

Default overseas path:

```yaml
firebase_messaging: ^16.2.0
```

Domestic Android path:

- Huawei Push Kit.
- Xiaomi Push.
- OPPO Push.
- VIVO Push.
- Meizu or other channels if required.

These should be isolated behind a notification service abstraction.

## 7. Data Flow

### API Access

Use `dio` with interceptors:

- Base URL per environment.
- Access token injection.
- Refresh token handling.
- Request ID.
- App version and device info headers.
- Error normalization.
- Retry only for safe operations.
- Log redaction for tokens, receipts, and personal data.

Suggested API client shape:

```text
ApiClient
  AuthInterceptor
  TraceInterceptor
  ErrorInterceptor
  RetryInterceptor
```

### Local Persistence

Use three storage levels:

- `flutter_secure_storage`: sensitive secrets.
- `shared_preferences`: simple non-critical settings.
- `drift`: structured local data.

Suggested local tables:

- `watch_history`
- `episode_progress`
- `favorite_cache`
- `pending_analytics_events`
- `pending_progress_events`
- `cached_drama_metadata`

## 8. Analytics And Observability

### Analytics Events

Track product-critical events from day one:

- `app_open`
- `login_start`
- `login_success`
- `feed_exposure`
- `drama_click`
- `episode_play_start`
- `episode_play_3s`
- `episode_play_10s`
- `episode_complete`
- `episode_unlock_view`
- `purchase_click`
- `purchase_success`
- `purchase_failed`
- `share_click`
- `favorite_click`

Event rules:

- Define a central event schema.
- Avoid scattering raw event names across UI code.
- Queue important events locally when offline.
- Include experiment and channel fields if growth work is planned.

### Crash And Error Monitoring

Recommended:

- Use Sentry if cross-platform and custom error context matter more.
- Use Firebase Crashlytics if Firebase is already the main analytics and push stack.

Capture:

- Flutter errors.
- Platform errors.
- API error rates.
- Player error codes.
- Purchase verification failures.

## 9. Security

Client-side rules:

- Do not hardcode secrets.
- Do not trust local entitlement state.
- Store tokens in secure storage.
- Use HTTPS only.
- Redact logs.
- Avoid exposing raw payment receipts in debug logs.

Backend-dependent rules:

- Signed video URLs.
- Server-side purchase verification.
- Server-side entitlement calculation.
- Rate limiting for unlock and progress APIs.
- Device/session risk controls for abuse prevention.

## 10. Build Environments

Use three environments:

- `dev`: local development.
- `staging`: QA and pre-release testing.
- `prod`: store release.

Recommended Flutter flavors:

```text
dev
staging
prod
```

Each environment should isolate:

- API base URL.
- Firebase app.
- Sentry DSN.
- App icon/name if useful.
- Analytics collection behavior.
- Logging level.

## 11. Testing Strategy

MVP test focus:

- Unit tests for repositories, purchase state machine, entitlement logic, and API error mapping.
- Widget tests for player overlays, unlock dialogs, and major pages.
- Integration tests for login, playback entry, and purchase restore mock flow.

Manual QA must include:

- Weak network playback.
- App background/foreground during playback.
- Incoming call or audio interruption.
- Purchase cancellation.
- Purchase success followed by network failure.
- Restore purchase.
- Token expiration during playback and purchase.

## 12. CI/CD

Recommended pipeline stages:

```text
format
analyze
test
build android
build ios
upload artifacts
```

Use FVM in CI so local and pipeline versions match.

Required checks:

```bash
fvm flutter pub get
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
```

## 13. MVP Implementation Roadmap

### Phase 1: Foundation

- Flutter project scaffolding with FVM.
- App theme, router, environment config.
- Network client and error model.
- Riverpod provider structure.
- Basic analytics abstraction.

### Phase 2: Content And Playback

- Home feed.
- Drama detail.
- Episode playback.
- Player controls.
- Progress reporting.
- Watch history.

### Phase 3: Monetization

- Product list.
- Coin wallet.
- In-app purchase flow.
- Backend receipt verification integration.
- Episode unlock and entitlement refresh.
- Restore purchase.

### Phase 4: Growth And Quality

- Push notifications.
- Deep links.
- Search and category.
- Crash reporting.
- Performance optimization.
- Release flavors and CI.

### Phase 5: Advanced Media

- Player preloading optimization.
- DRM evaluation.
- Offline caching evaluation.
- Domestic Android payment and push channel SDKs.

## 14. Open Decisions

These should be confirmed before implementation:

- Target markets: overseas, China mainland, or both.
- Payment model: coins, subscription, single unlock, full-drama unlock, or mixed.
- Content protection requirement: signed URLs only, DRM, watermarking, or encrypted offline cache.
- Push vendors and app store channels.
- Analytics vendor: Firebase, Sentry-only, Sensors, AppsFlyer, Adjust, or a mixed stack.
- Login methods.
- Whether Web is a real user-facing target or only a preview/debug target.

## 15. Initial Recommendation

Start with:

```yaml
dependencies:
  flutter_riverpod: ^3.3.1
  go_router: ^17.2.3
  dio: ^5.9.2
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
  cached_network_image: ^3.4.1
  shared_preferences: ^2.5.5
  flutter_secure_storage: ^8.1.0
  drift: ^2.33.0
  app_links: ^7.0.0
  in_app_purchase: ^3.2.3
  firebase_core: ^4.7.0
  firebase_messaging: ^16.2.0
  firebase_analytics: ^12.3.0
  sentry_flutter: ^9.20.0
  connectivity_plus: ^7.1.1
  package_info_plus: ^10.1.0

dev_dependencies:
  build_runner: any
  freezed: ^3.2.5
  json_serializable: ^6.13.2
```

Before locking exact package versions, run `fvm flutter pub add` and let Pub resolve compatible transitive versions against Flutter `3.41.9`, then commit `pubspec.lock` for the app.

The initial scaffold resolved `flutter_secure_storage` to `8.1.0`. Keep resolved package versions unless a later upgrade has a clear reason and passes analyze, tests, and device smoke checks.

## 16. Architecture Constraints

These constraints should be treated as project rules, not suggestions.

### Version And Dependency Constraints

- Flutter is locked by FVM at `3.41.9`.
- Commit `.fvm/fvm_config.json`, `pubspec.yaml`, and `pubspec.lock`.
- Do not upgrade Flutter, Dart SDK constraints, Firebase packages, `media_kit`, or payment packages casually during MVP development.
- Add a package only when it has a clear owner, purpose, and maintenance status.
- Prefer first-party or mature packages for payment, storage, routing, analytics, and platform integrations.
- Avoid introducing a second package for the same responsibility unless the architecture document is updated first.

### Code Ownership Constraints

- UI widgets should not call `Dio` directly.
- UI widgets should not directly read or write secure storage.
- UI widgets should not directly grant paid entitlements.
- Feature modules should depend on `core` and `shared`, but `core` must not depend on feature modules.
- Cross-feature communication should go through domain repositories, Riverpod providers, or app-level services.
- Platform Channels should live behind typed service interfaces under `core/platform` or the owning feature.

### State Management Constraints

- Use Riverpod as the only app state management system.
- Do not introduce Bloc, Provider, GetX, MobX, or Redux unless the decision is revisited.
- Use immutable state objects for non-trivial feature state.
- Keep async loading, empty, error, and retry states explicit.
- Avoid storing long-lived business state only inside widgets.

### Routing Constraints

- Use `go_router` as the only routing system.
- Define route paths and route names centrally.
- Auth redirects, entitlement redirects, and deep-link mapping must live in router-level guards or adapters, not inside random page widgets.
- All external deep links should map to internal route names before navigation.
- Player routes must be restorable from URL parameters or typed route extras.

### Player Constraints

- `media_kit` is the primary player engine.
- Initialize `MediaKit.ensureInitialized()` once during app startup.
- Do not instantiate `Player` directly in reusable UI components.
- The active playback session must be owned by the player feature.
- Dispose all `Player` and `VideoController` resources deterministically.
- Start with one active native player; add multi-player prewarming only after profiling real devices.
- Player events must feed progress reporting and analytics through a central reporter.
- Playback URL signing, entitlement, and trial cutoff decisions must come from backend-controlled data.
- Do not implement offline video caching or DRM without a separate design review.

### Payment And Entitlement Constraints

- Use `in_app_purchase` for App Store and Google Play in-app purchase flows.
- The backend is the source of truth for orders, coins, subscriptions, and episode unlocks.
- The client must never permanently grant entitlement based only on local purchase callbacks.
- Every purchase callback must be verified by the backend.
- Purchase restore must refresh entitlements from the backend.
- Domestic Android payment SDKs must be isolated behind a payment service abstraction.

### API And Data Constraints

- All API calls go through the shared `Dio` client and interceptors.
- API responses should be parsed into DTOs, then mapped into domain entities when business logic is involved.
- Backend error codes should be normalized into a small client error model.
- Access tokens, refresh tokens, receipts, signed playback URLs, and personal data must be redacted from logs.
- Local cached data is an optimization, not the source of truth for paid access.
- Offline queues are allowed for analytics and progress events, but must be idempotent.

### Analytics Constraints

- Event names and parameter names must be defined centrally.
- Do not fire raw analytics events directly from leaf widgets.
- Every monetization funnel must include exposure, click, result, and failure events.
- Player analytics must include drama ID, episode ID, playback position, duration, source page, and entitlement state when available.
- Analytics collection must respect environment and privacy settings.

### Security And Compliance Constraints

- No secrets in the client repository.
- No production API keys in debug-only files.
- HTTPS is required for API and media URLs.
- Account deletion, privacy policy, terms, and customer support entry points must be available before store review.
- Permission prompts should be contextual, especially push notifications and tracking consent.
- Logs in release builds must be minimal and redacted.

### Build And Release Constraints

- Use `dev`, `staging`, and `prod` flavors.
- Each flavor must have isolated API base URL, app config, analytics config, and crash reporting config.
- Android production builds should prefer App Bundle.
- iOS production builds must be tested on real devices before review.
- Release candidates must pass analyze, tests, smoke playback, login, purchase sandbox, and restore purchase checks.

### UI And Performance Constraints

- Do not initialize video players inside feed cards unless the product explicitly needs inline preview.
- Feed, episode list, and comments must be paginated.
- Large images should be served by CDN in size-appropriate variants.
- Loading, empty, error, and retry states are required for all network-backed screens.
- Player UI must be tested on small phones, not only large simulators.
- Avoid blocking the main isolate with JSON parsing, image work, or local database migrations when data volume grows.

### Documentation Constraints

- Update this architecture document when changing core packages, Flutter version, routing strategy, player engine, payment strategy, analytics vendor, or supported platforms.
- Add focused docs for payment, player, API error model, analytics schema, and release process before those areas become complex.
- Keep implementation examples in the codebase close to the owning module rather than scattering snippets through broad docs.
