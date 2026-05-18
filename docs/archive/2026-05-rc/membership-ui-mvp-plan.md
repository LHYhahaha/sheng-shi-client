# Membership UI MVP Plan

本文档记录 Membership / VIP 页面 UI MVP 的开发计划。本轮只覆盖会员页面第一版 UI，不包含真实支付、钱包、订单、权益发放或服务端接口对接。

## 1. 目标

基于 Figma 对应 Membership / VIP 页面完成会员页面 UI MVP，用 mock 数据跑通会员套餐展示、套餐选择和购买确认交互。

本轮完成后，应能从 Profile 会员入口进入 Membership 页面，并看到符合 Figma 的会员状态、会员套餐和权益说明。

## 2. 设计依据

- 开发前必须查看 Figma 对应 Membership / VIP 页面和组件。
- 页面结构、颜色、字体、间距、圆角、套餐卡片比例、权益区和选中态以 Figma 为准。
- 如果 Figma 资源缺失，优先保留结构和交互，用项目现有资源或 Flutter icon 做明确 fallback。
- 不自由发挥 UI，不套用 Store、Player、Home 或 My list 的不相关视觉样式。

## 3. 本轮范围

必须做：

- 新增 Membership 页面 UI，替换当前 `/membership` placeholder。
- 展示会员状态或会员开通状态，具体按 Figma。
- 展示会员套餐列表。
- 展示会员权益说明。
- 支持套餐选中态。
- 支持购买 CTA。
- 点击购买后展示 mock confirmation sheet。
- Profile 会员入口继续通过 `RoutePaths.membership` 进入该页面。
- 保持 feature-first 分层。

不做：

- 不接真实支付 SDK。
- 不接服务端接口。
- 不做 Google / Apple IAP 状态机。
- 不做 Wallet 全量页面。
- 不做订单、验单、退款、对账。
- 不做真实权益发放或权益刷新。
- 不扩大到 Store / Recharge 真实支付逻辑。
- 不做 ARB/gen-l10n 迁移。

## 4. 建议目录

```text
lib/features/membership/
  application/
    membership_controller.dart
  data/
    mock_membership_repository.dart
    membership_repository_provider.dart
  domain/
    membership_plan.dart
    membership_repository.dart
  presentation/
    pages/
      membership_page.dart
    widgets/
      ...
```

可按实际复杂度创建文件，不为了形式创建空文件。

## 5. 实现约束

- mock 数据放在 `features/membership/data/`，不要写进 widget。
- 业务实体和 repository 接口放在 `features/membership/domain/`。
- 页面状态放在 `features/membership/application/`，例如 loading、error、selected plan、confirmation sheet state。
- 页面只负责 UI 组装、读取 provider state、触发 controller action 和展示确认 sheet。
- 路由继续使用 `RoutePaths.membership` / `RouteNames.membership`。
- Widget 中不要新增硬编码通用 UI 文案，新增固定 UI 文案走 `AppLocalizations`。
- Figma 局部一次性尺寸可以保留具体数值；多处重复颜色/间距再沉淀 token，不做过度 token 化。

## 6. 验收标准

- Profile 会员入口可进入 Membership 页面。
- 页面展示会员状态 / 会员套餐 / 权益说明。
- 会员套餐可选中，选中态符合 Figma。
- 点击购买 CTA 能打开 mock confirmation sheet。
- 页面数据来自 mock repository/controller，不写死在 widget。
- 未接真实支付 SDK、服务端接口、IAP 状态机、Wallet 全量、订单/验单/权益发放。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。

## 7. 后续任务

本轮完成后再单独评估：

- Wallet UI MVP。
- Store / Membership 支付状态机整合。
- Google / Apple 内购。
- 服务端商品、订单、验单和权益刷新接口。
