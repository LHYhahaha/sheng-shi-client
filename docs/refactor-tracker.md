# 工程整改推进记录

本文档用于记录代码整改项、推进顺序、完成标准和验证结果。后续每次做结构性整改时，先更新本文档，再按小步提交的方式推进，避免零散改动失控。

## 1. 整改原则

- 先收敛高风险页面，再处理低风险样式细节。
- 每轮只解决一类问题，例如状态管理、组件复用、资源规范或网络边界。
- 页面 UI 不直接承载复杂业务状态，复杂状态进入 `features/<feature>/application/`。
- 重复出现两次以上且不绑定具体业务的 UI 能力，沉淀到 `shared/widgets/`。
- 整改不能降低 Figma 还原度，不能改变用户已验收的交互。
- 每轮整改完成后必须跑 `flutter analyze` 和 `flutter test`。

## 2. 整改队列

| 优先级 | 模块 | 问题 | 方案 | 状态 |
|---|---|---|---|---|
| P0 | Home | 页面内承担分类、分页、错误、并发保护等状态 | 新增 `HomeFeedController`，页面只负责 UI 组装 | Done |
| P0 | Player | 播放页 UI 状态散落在页面内 | 新增 `PlayerUiController` 管理播放、集数、解锁弹窗 | Done |
| P1 | Player sheets | 多个弹窗重复实现圆形按钮和 sheet handle | 抽到 `shared/widgets/` 复用 | Done |
| P1 | My list | 编辑态、选择态、左滑删除状态仍偏 UI 层 | 新增 `MyListController`，统一管理 tab、编辑、选择、删除 | Done |
| P1 | Profile | 语言、登录态、金币、会员入口和本地 UI 文案需要更清晰分层 | 补 Profile application 状态和可复用 setting row/card 组件 | Done |
| P1 | L10n | 当前手写本地化可用，但后续语言切换和维护成本会升高 | 评估迁移 ARB/gen-l10n，先保持 key 语义稳定 | Todo |
| P2 | Theme tokens | 部分页面仍可能散落 magic number 和局部颜色 | 抽查核心页面，沉淀颜色、间距、圆角、文本样式 | In Review |
| P2 | Network | Remote skeleton done; integration blocked on backend | 401 refresh、验单、strict DTO 后再默认开 remote | In Review |
| P2 | Player domain | 当前播放页仍以 mock 和 UI 状态为主 | 接入真实播放器 session、解锁状态、自动下一集、错误恢复 | Todo |
| P1 | Global Modal (Track O) | **O1–O5 + O2.1 Done**；Payment Method 已走 `player.payment_method` + `stackOnCurrent`；Modal Ops（活动/强更）另开 | O1–O5、O2.1 complete | O5 Done |

## 3. 已完成记录

### 2026-05-17 Track O1：Global Modal skeleton

完成内容：

- 新增 `lib/core/modal/*`（typed request/result、`AppModalService`、`AppModalHost`、`AppModalQueue` 骨架）
- `DramaClientApp` 挂载 `AppModalHost`；`GoRouter` 使用 `appRootNavigatorKey`
- `test/helpers/recording_app_modal_service.dart`、`test/architecture/modal_boundary_test.dart`
- 未迁移 Auth、Store/Membership/Wallet 现有弹窗

验证：`flutter analyze`、`flutter test` 通过。

### 2026-05-17 Track O4：Store / Membership modal migration

完成内容：

- Store / Membership 购买确认迁移到 `AppModalService`（`StoreModalCoordinator` / `MembershipModalCoordinator`）
- 新增 feature modal channels、payloads、results、presenters；`StorePurchaseModalResult` / `MembershipPurchaseModalResult` 在 core
- `StoreConfirmationSheet` / `MembershipConfirmationSheet` 仍由 presenter 复用；mock purchase 逻辑仍在 controller
- Wallet：**no-op**（无阻塞确认弹窗；restore → toast）
- 页面 dispose 时 `dismissForSource(AppModalSource.store|membership)`
- `modal_boundary_test` 收紧：Store/Membership 页面不再允许 `showModalBottomSheet`

验证：`flutter analyze`、`flutter test` 通过。

### 2026-05-17 Track O2：Player modal migration

完成内容：

- Player coin unlock、recharge 迁移到全局 `AppModalService`
- 新增 Player modal presenter / payload / result / coordinator，复用现有 sheet 内容
- Player route dispose 时按 `AppModalSource.player` 关闭当前 Player modal，避免离开页面后残留
- 架构测试继续禁止 `core/modal` 反向依赖 features，并收紧 Player 业务弹窗的 `showModalBottomSheet` 使用
- Player 详情、分享、倍速等页面局部 sheet 暂时保留本地实现
- Player `Payment Method`（O2.1）：`player.payment_method` AppModal channel + `PaymentModalResult`；`stackOnCurrent` 叠层；已删除充值 sheet 内 `OverlayEntry`

验证：`flutter analyze`、`flutter test` 通过。

### 2026-05-13 第一轮：Home 与 Player 状态收敛

完成内容：

- 新增 `lib/features/home/application/home_feed_controller.dart`。
- 新增 `lib/features/player/application/player_ui_controller.dart`。
- 新增 `AppTapTarget`、`AppRoundIconButton`、`AppSheetHandle` 三个共享组件。
- 精简 `HomePage`，移除页面内分页、分类、错误、并发 generation 状态。
- 精简 `PlayerPage`，移除页面内播放、集数和 paywall 状态。
- 播放弹窗复用共享 sheet handle 和圆形按钮。

验证结果：

```bash
dart format ...
flutter analyze
flutter test
```

结果：

- `flutter analyze`：通过。
- `flutter test`：通过，`All tests passed`。

### 2026-05-13 第二轮：My list 状态收敛

完成内容：

- 新增 `lib/features/my_list/application/my_list_controller.dart`。
- `MyListController` 统一管理当前 tab、collection 编辑态、selectedIds、批量删除、单项删除、play list 左滑打开项、loading、error、empty 和 retry。
- 精简 `MyListPage`，页面保留 UI 组装、Slidable 动画入口和底部导航隐藏/恢复协调。
- 保持 `my_list/domain` 与 `my_list/data` 的 repository 边界，页面不直接读取 repository。
- 新增 `test/features/my_list/my_list_controller_test.dart`，覆盖加载、切 tab、批量删除、单项删除、左滑打开状态清理和错误重试。

验证结果：

```bash
dart format ...
flutter analyze
flutter test
```

当前状态：

- `flutter analyze`：通过。
- `flutter test`：通过，`All tests passed`。
- Review agent 已通过，状态改为 `Done`。

### 2026-05-13 第三轮：Profile 状态与组件边界收敛

完成内容：

- 新增 `lib/features/profile/application/profile_controller.dart`。
- `ProfileController` 承载登录/游客展示、userId、avatar、nickname、会员入口、金币余额/充值入口、语言入口等 Profile 页面状态。
- 拆分 Profile 页面私有组件到 `lib/features/profile/presentation/widgets/`：
  - `ProfileHeader`
  - `ProfileMembershipCard`
  - `ProfileCoinsCard`
  - `ProfileMenuRow`
- `ProfilePage` 保留页面布局组装、路由跳转和 provider state 读取。
- 会员卡和金币卡继续使用当前 Figma 整图，不做视觉重画。
- 新增 `test/features/profile/profile_controller_test.dart`，覆盖 mock profile state 不落在 widget 内。

验证结果：

```bash
dart format ...
flutter analyze
flutter test
```

当前状态：

- `flutter analyze`：通过。
- `flutter test`：通过，`All tests passed`。
- Review agent 已通过，状态改为 `Done`。

### 2026-05-13 第四轮：Shared/theme/l10n 小收口

完成内容：

- `AppColors` 补充语义 token：
  - `surfacePanel`
  - `navigationBar`
  - `navigationInactive`
  - `danger`
  - `textOnCard`
  - `textDisabled`
  - `textTertiary`
- `AppRadii` 补充 `xs = 4`，用于已存在的 4px 小圆角。
- 底部导航、首页卡片、My list 菜单/删除/弱文本等明显重复颜色改为使用 token。
- 修正明显异常文案 `Collection list list` 为 `Collection list`，同步 widget test。
- 保留 Figma 局部单点颜色，例如首页 Exclusive 角标、tag 背景/文字、播放器社交平台色。

明确 defer：

- 不做 ARB/gen-l10n 迁移。
- 不重画会员卡、金币卡、播放器或首页卡片视觉。
- 不在本轮下沉 `player_page.dart` 的内容加载；该问题记录为后续 Player application 收敛项。
- 不触碰 Store、Wallet、Membership、Payment。

验证结果：

```bash
dart format lib test
flutter analyze
flutter test
```

当前状态：

- `flutter analyze`：通过。
- `flutter test`：通过，`All tests passed`。
- 等待 Review agent 复核后，将状态从 `In Review` 改为 `Done`。

## 4. 每轮整改完成标准

- 相关页面没有明显回归。
- 没有新增无用依赖。
- 没有引入平行目录结构。
- 没有把业务 mock 数据写进 widget。
- 没有把通用本地文案写死在 widget。
- 新增复杂状态必须可测试，或至少保留明确测试入口。
- `flutter analyze` 通过。
- `flutter test` 通过。

## 5. 下一轮建议

下一轮建议处理 `Shared/theme/l10n` 小收口：

- 抽查 `shared/widgets` 是否存在重复组件或过度上提组件。
- 抽查核心页面是否仍有可收敛的颜色、尺寸、文案散落。
- 检查 `RoutePaths` 使用，避免页面内散落路由字符串。
- 检查 feature-first 分层，确认 UI 不直接读基础数据源或硬编码 mock 数据。
- 跑 `dart format`、`flutter analyze`、`flutter test`，准备最终工程收口 review。
