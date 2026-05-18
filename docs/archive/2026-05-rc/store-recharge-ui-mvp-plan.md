# Store / Recharge UI MVP Plan

本文档记录下一轮充值 / 商店页面 UI 开发计划。它只覆盖 Store / Recharge UI MVP，不包含真实支付、钱包全量、会员全量或服务端接口对接。

## 1. 目标

基于 Figma 设计完成充值 / 商店页面第一版 UI，用 mock 数据跑通本地选择和购买确认交互。

本轮完成后，应能从现有入口进入 Store 页面，并看到符合 Figma 的金币充值 UI。

## 2. 设计依据

- 开发前必须查看 Figma 对应 Store / Recharge 页面和组件。
- 颜色、字体、间距、圆角、卡片比例、选中态、按钮样式以 Figma 为准。
- 不要自由发挥 UI，不要直接套用播放器、首页或 My list 的视觉样式。
- 如果 Figma 与当前资源缺口不一致，优先保留结构和交互，资源缺失项用明确 fallback，不临时重画整套风格。

## 3. 本轮范围

必须做：

- 新增 Store / Recharge 页面 UI。
- 展示金币余额或账户充值状态，具体按 Figma。
- 展示金币套餐列表。
- 支持套餐选中态。
- 支持购买 CTA。
- 点击购买后展示 mock 购买确认 sheet 或等价确认 UI。
- 使用 mock 数据完成 UI 闭环。
- Profile 金币入口继续通过 `RoutePaths.store` 进入该页面。
- 保持 feature-first 分层。

不做：

- 不接真实支付 SDK。
- 不接真实服务端接口。
- 不做 Google / Apple 内购状态机。
- 不做钱包记录全量页面。
- 不做会员页面全量开发，除非 Figma Store 页面自身包含轻量会员入口。
- 不做订单、验单、退款、对账。
- 不扩大到 Player 解锁权益逻辑。
- 不做 ARB/gen-l10n 迁移。

## 4. 建议任务拆分

| 任务 | 内容 | 估时 |
|---|---|---:|
| P1 Figma 对齐 | 确认 Store / Recharge 页面结构、组件、资源缺口 | 0.5 天 |
| P2 domain/data | 定义 coin package model、mock repository/provider | 0.5 天 |
| P3 application | 新增 Store controller，管理加载、选中套餐、确认购买状态 | 0.5 天 |
| P4 页面 UI | 实现 Store page、余额区、套餐列表、CTA、确认 sheet | 1.5-2 天 |
| P5 测试与验证 | controller/widget 测试、format/analyze/test | 0.5 天 |

本轮目标工期：3-4 个工作日。

## 5. 建议目录

```text
lib/features/store/
  application/
    store_controller.dart
  data/
    mock_store_repository.dart
    store_repository_provider.dart
  domain/
    store_package.dart
    store_repository.dart
  presentation/
    pages/
      store_page.dart
    widgets/
      ...
```

可按实际复杂度小步创建，不需要为了形式创建空文件。

## 6. 实现约束

- mock 数据放在 `features/store/data/`，不要写进 widget。
- 业务实体和 repository 接口放在 `features/store/domain/`。
- 页面状态放在 `features/store/application/`，例如 selected package、loading、error、confirmation sheet state。
- 页面只负责 UI 组装、读取 provider state、触发 controller action 和展示确认 sheet。
- 路由继续使用 `RoutePaths.store` / `RouteNames.store`。
- Widget 中不要硬编码通用 UI 文案，新增固定 UI 文案走 `AppLocalizations`。
- Figma 局部一次性尺寸可以保留具体数值；多处重复颜色/间距再沉淀 token，不做过度 token 化。

## 7. 验收标准

- 通过 Profile 金币入口可进入 Store 页面。
- Store 页面结构、色彩、间距、按钮、套餐卡片与 Figma 基本一致。
- 套餐可选中，选中态符合 Figma。
- 点击购买 CTA 能打开 mock 确认 sheet。
- 页面数据来自 mock repository/controller，不写死在 widget。
- 未接真实支付、真实接口或钱包全量逻辑。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。

## 8. 后续任务

本轮完成后再单独评估：

- Membership 页面。
- Wallet 页面与记录。
- Payment sheets 精细化。
- Google / Apple 内购状态机。
- 服务端商品、订单、验单和权益刷新接口。
