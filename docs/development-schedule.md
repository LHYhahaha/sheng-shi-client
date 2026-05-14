# Development Schedule

## 1. Goal

Deliver a 5-week MVP plan for the short drama client based on the current Flutter scaffold and the `1.0.1` UI overview.

Main demo loop:

```text
Home -> For you playback -> Episode/Unlock/Share sheets -> Recharge/Membership -> My list/Profile
```

## 2. Current Project Status

- Flutter project scaffold exists.
- Flutter version is locked to `3.41.9`.
- Core dependencies are installed: `go_router`, Riverpod, `media_kit`, `dio`, `in_app_purchase`, Firebase, Sentry, local storage, and code generation.
- The main mock UI screens are implemented: Home, For You, Player, My list,
  Profile, Login/Account, Store/Recharge, Membership, Wallet, and record pages.
- Player playback has moved beyond MVP into HLS/m3u8 experience polishing:
  tap play/pause, progress/seek, speed, completion auto advance, lifecycle
  pause, loading polish, mock progress restore, and HLS preload state are in
  place.
- MP4 whole-file cache/offline-cache compatibility is deprecated for the current
  product direction. Playback now targets remote HLS/m3u8 sources.
- Android release builds have been installed on the connected test device for
  manual playback checks.

## 2.1 Current Focus: Player HLS Playback Experience

This cycle prioritizes playback smoothness before broad backend integration or
new page work.

| Priority | Task | Estimate | Notes |
|---|---:|---:|---|
| P0 | Review current HLS preload state machine | 0.5 day | Confirm pending/success/failed/cancelled, cancellation, and session isolation. |
| P1 | HLS playlist prefetch MVP | 1-1.5 days | Real HTTP GET for m3u8 playlist with timeout/cancel; no segment preheat yet. |
| P1 | Android device playback verification | 0.5-1 day | Check first-frame time, vertical swipes, auto advance, tab pause, retry. |
| P1 | Playback source API contract | 1 day | Define future server fields for m3u8 URL, expiry, access, duration, poster, progress. |
| P2 | Mock-to-real API preparation | 2-3 days | Start after playback source contract is stable. |
| P2 | IAP/payment integration | 3-5 days | Keep separate from player playback work. |
| P2 | QA/release readiness | 3-5 days | Run continuously, not only at the end. |

Near-term rule:

- Do not add new Figma-missing pages.
- Do not reintroduce MP4 whole-file cache.
- Do not implement offline download in the playback-preload path.
- Do not start full backend integration before the playback source contract is
  reviewed.

## 3. Milestone Plan

| Milestone | Duration | Goal |
|---|---:|---|
| M0: 基础工程架构 | 1 天 | 整理当前 Flutter 脚手架，补齐路由、状态、mock 数据和工程约定。 |
| M1: 基础产品架构 + 底部导航 | 2-3 天 | 建立产品主结构、四大 Tab、全局视觉规范和公共组件。 |
| M2: 首页 + 短剧数据 | 3-4 天 | 完成首页分类、剧集卡片、mock 数据和进入播放链路。 |
| M3: 播放器 MVP | Done | `media_kit` 播放、播放器主 UI、弹窗、生命周期、滑动 feed、进度/seek 已完成。 |
| M3.5: HLS 播放体验专项 | 2-3 天 | 完成 HLS playlist prefetch、真机验证、播放源接口契约，为流畅滑动播放打基础。 |
| M4: My list + Profile | 3-4 天 | 完成收藏/播放列表、用户页、会员/金币入口。 |
| M5: 钱包/充值/会员/支付 UI | Done | 商业化相关页面和 mock 购买/权益流已完成。 |
| M6: 内购集成 | 3-4 天 | 接入 `in_app_purchase` 状态机、商品查询、恢复购买和验单占位。 |
| M7: QA/打磨/发布准备 | 4-5 天 | 真机/模拟器验证、视觉修整、构建、埋点和问题收敛。 |

Total:

- Minimum: 25 working days.
- Maximum: 35 working days.
- Target: about 5 weeks with focused execution and controlled scope.

## 4. Weekly Plan

### Week 1: M0 + M1 + M2 前半

Focus:

- 工程架构
- 产品壳
- 底部导航
- 设计系统
- 首页框架

Tasks:

- 完成 M0 基础工程架构。
- 建立 `go_router` 路由结构和主要页面占位。
- 搭建产品主壳和四大 Tab：Home、For you、My list、Profile。
- 建立主题 token、基础颜色、字体、间距、圆角、按钮、卡片、弹窗样式。
- 开始首页框架：头部、分类 tab、剧集卡片布局、mock 数据结构。

Deliverable:

- App 有产品主壳。
- 底部导航可切换。
- 首页框架可见，使用 mock 数据。

### Week 2: M2 后半 + M3 前半

Focus:

- 首页数据
- 进入播放链路
- `media_kit` 播放
- 播放器主 UI

Tasks:

- 完成首页分类、剧集列表、加载/空/错误状态。
- 完成剧集卡片点击进入播放器。
- 接入 `media_kit` sample 视频播放。
- 完成播放器主页面第一版：顶部、右侧操作、底部标题/进度区域。
- 建立播放器生命周期：进入、离开、重新进入、dispose。

Deliverable:

- 首页可以浏览 mock 短剧。
- 可以进入播放器并播放 sample 视频。

### Week 3: M3 后半 + M4

Focus:

- 播放器弹窗
- 解锁/分享/剧集列表
- My list
- Profile

Tasks:

- 完成剧集列表弹窗。
- 完成分享弹窗。
- 完成解锁/会员 CTA 弹窗。
- 完成播放进度上报骨架和播放器事件封装。
- 完成 My list 的 Collection list / Play list。
- 完成 Profile 的游客/登录态、会员卡、金币入口、菜单入口。

Deliverable:

- 播放器 MVP 可演示。
- My list 和 Profile 可用 mock 数据演示。

### Week 4: M5 + M6 前半

Focus:

- 钱包
- 充值
- 会员
- 支付 UI
- 内购状态机

Tasks:

- 完成 Store/recharge 页面。
- 完成 coin package 和 VIP package UI。
- 完成 Membership 页面。
- 完成 Wallet overview、Transaction history、Consumption history、Record coins。
- 完成支付方式弹窗和购买确认弹窗。
- 建立内购状态机：idle、loading、pending、success、failed、canceled。

Deliverable:

- 钱包/充值/会员/支付 UI 可完整走通 mock 流程。
- 内购状态机可以驱动 UI 状态。

### Week 5: M6 后半 + M7

Focus:

- 内购联调/验单占位
- QA
- 真机测试
- 视觉打磨
- 问题收敛

Tasks:

- 完成商品查询接口骨架。
- 完成后端验单接口占位。
- 完成恢复购买接口占位。
- 完成 mock 权益刷新。
- 补最小埋点：home click、player start、unlock view、purchase click、purchase result。
- Android 真机/模拟器 smoke test。
- iOS simulator/device smoke test if local setup allows.
- 修复播放器、支付、导航、布局和小屏适配问题。
- 输出 known issues 和 post-MVP backlog。

Deliverable:

- Demo-ready MVP。
- 主要链路可以不依赖开发者手动操作演示。

## 5. Scope Control

### Must Have

- Bottom navigation: Home, For you, My list, Profile.
- Dark theme and shared UI components matching the design.
- Home grid with category tabs and mock drama data.
- For you/player page with `media_kit` sample playback.
- Player overlays: episode info, episode list, share sheet, unlock/member CTA.
- My list collection/list views with mock data.
- Profile guest/login state, membership card, coin card, menu list.
- Store/recharge page with coin and VIP packages.
- Membership page with plan cards and benefit list.
- Wallet overview, transaction history, consumption history, record coins.
- Payment method and confirmation bottom sheets as UI/state skeletons.
- Mock repositories for UI and flow development.

### Defer

- Real personalized recommendation.
- Full search.
- Push notifications.
- Full analytics event matrix.
- DRM and offline cache.
- Domestic Android payment/push SDKs.
- Complex batch edit.
- Full localization.
- Production store payment approval flow.

## 6. M0: 基础工程架构

Duration: 1 day

Tasks:

- Review current scaffold and remove remaining placeholder/demo code.
- Confirm Flutter `3.41.9`, Android `minSdk 24`, iOS `13.0`.
- Add route placeholders for all major pages.
- Add mock repository structure.
- Add base error/loading/empty state contracts.
- Add environment placeholders for `dev`, `staging`, `prod`.
- Confirm `flutter analyze`, `flutter test`, Android debug build.

Deliverables:

- App foundation is ready for M1/M2 feature work.
- Project conventions are clear.

Exit criteria:

- `flutter analyze` passes.
- `flutter test` passes.
- Android debug build passes.

## 7. M1: 基础产品架构 + 底部导航

Duration: 2-3 days

Tasks:

- Implement global dark theme: black/purple background, pink primary, gold membership accents.
- Define spacing, radius, typography, icon sizes, and sheet styles.
- Build custom bottom navigation: Home, For you, My list, Profile.
- Convert router to `go_router` `ShellRoute`.
- Build shared components: page scaffold, poster card, primary button, icon action, segmented tabs, bottom sheet shell, empty/loading/error state widgets.

## 8. M2: 首页 + 短剧数据

Duration: 3-4 days

Tasks:

- Implement Home header and membership/crown entry.
- Implement category tabs: Popular, New, Ranking, Original, Asian.
- Implement drama poster grid.
- Implement drama card: cover, title, episode count, tag/badge.
- Implement mock drama list repository.
- Implement loading, empty, error states.
- Implement tap from drama card into For you/player route.

## 9. M3: 播放器 MVP

Duration: 5-6 days

Tasks:

- Wire `media_kit` to play a remote sample video.
- Implement `PlayerSessionController` lifecycle with one active player.
- Implement player page: full-screen video, top bar, episode label, speed/more entry.
- Implement right-side actions: favorite/like, episodes, share.
- Implement bottom title, synopsis preview, progress/time display.
- Implement tap to play/pause.
- Implement episode detail bottom sheet with synopsis and episode grid.
- Implement share sheet.
- Implement unlock/member CTA overlay from mock entitlement state.

## 10. M4: My list + Profile

Duration: 3-4 days

Tasks:

- Implement My list page.
- Implement tabs: Collection list, Play list.
- Implement list item cards matching the UI.
- Implement lightweight edit/delete mode.
- Implement My list empty state.
- Implement Profile guest and logged-in mock states.
- Implement membership card.
- Implement coin balance/top-up card.
- Implement profile menu: transaction history, consumption history, record coins, language.

## 11. M5: 钱包/充值/会员/支付 UI

Duration: 4-5 days

Tasks:

- Implement Store/recharge page.
- Implement coin package cards.
- Implement VIP package cards.
- Implement Restore entry UI.
- Implement Membership page with weekly/monthly/yearly plans.
- Implement membership benefits list.
- Implement Wallet overview page.
- Implement Transaction History page.
- Implement Consumption History page.
- Implement Record Coins/check-in page.
- Implement payment method bottom sheet.
- Implement purchase confirmation bottom sheet.
- Implement unlock now/member unlock bottom sheets.

## 12. M6: 内购集成

Duration: 3-4 days

Tasks:

- Add product models and product repository.
- Query store product details through `in_app_purchase` when products are configured.
- Implement purchase state machine: idle, loading, pending, success, failed, canceled.
- Add backend verification interface placeholder.
- Add restore purchase interface placeholder.
- Add mock entitlement refresh after successful mock purchase.
- Add purchase event wrapper: click, success, failure, cancel.

## 13. M7: QA/打磨/发布准备

Duration: 4-5 days

Tasks:

- Visual pass against the UI overview.
- Small phone layout pass.
- Android emulator or real-device smoke test.
- iOS simulator/device smoke test if local setup allows.
- Player lifecycle test: enter, leave, background, foreground.
- Payment mock flow test.
- Add basic Sentry/Firebase initialization stubs or real config if available.
- Fix critical overflow, navigation, and state bugs.
- Document known gaps and post-MVP backlog.
