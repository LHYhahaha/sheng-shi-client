# Playback Unlock Hotfix Plan

日期：2026-05-15

本文记录真机 + Figma 深度测试发现的播放器解锁链路问题。该任务优先级高于多语言
Phase G。目标是先修复播放生命周期泄漏，再做必要的 Figma 对齐小收口。

## 测试背景

- 真机：Samsung SM A145F / Android 15。
- Figma：`https://www.figma.com/design/lOPBRu3zixY3fGZNQoCslC/Untitled?node-id=0-1`。
- 本轮忽略横向 HLS 测试源导致的顶部黑屏问题；该问题归因于测试视频源比例，不作为缺陷处理。

## P0 必修

### 1. 锁定剧集触发解锁时旧音频泄漏

复现：

1. 进入单剧播放页。
2. 打开选集。
3. 选择锁定剧集。
4. 出现解锁界面后关闭。

实际：上一集音频仍继续播放。继续切换到底部 tab，如 My list / Profile，声音仍存在。

预期：

- 切到锁定剧集并展示 unlock/paywall/recharge UI 时，上一集 playback session 必须立即 pause。
- 关闭解锁弹窗后，如果当前 episode 仍处于 locked / waitUnlock / paywall，不允许旧 episode 恢复播放。
- 播放器不可见或离开播放器页面时，必须可靠 pause/release。

初步判断：

- 锁定集触发 paywall 时，UI 切到了锁定态或隐藏 video surface，但上一集 playback session 没有同步 pause/release。

### 2. 离开播放器后音频未可靠停止

复现：

1. 承接上一步，关闭解锁弹窗。
2. 切换到底部 tab。

实际：仍可听到音频。

预期：播放器不可见、离开播放器、切底部 tab、进入后台时都不能继续出声。

## P1 本轮建议修

### 1. 解锁弹窗与 Figma 对齐

当前真机：

- 大底部 sheet。
- `Confirm unlock`。
- `Price 30 / Balance 120`。

Figma 目标：

- 紧凑卡片。
- `Price 60 / Balance 60`。
- 主按钮 `Play`。
- 包含“自动播放下一集”开关/文案。

要求：

- 金额 mock 按 Figma 对齐，或把金额来源整理到 entitlement/mock config。
- 不复用当前 generic `Confirm unlock` 样式作为最终样式。

### 2. Profile 增加 Settings 入口

Figma Profile 有 `Settings` 行，真机当前只有 `Language`。

要求：

- 增加 Settings 入口。
- 不影响现有 Language / Wallet / Membership 入口。
- 如果 Settings 详情页尚未实现，可先接 placeholder 或记录 defer。

### 3. Wallet mock 默认值确认并对齐

Figma：

- `Coins 4000`
- `Bonus 4000`
- auto unlock 默认开启

真机：

- `Coins 120`
- `Bonus 4000`
- auto unlock 默认关闭

要求：

- 如果当前真机值不是刻意产品策略，按 Figma 调整 mock 默认值。
- 如果保留当前值，必须在文档中说明原因。

## P2 记录，暂不强修

- My List 页面密度偏大。
- Store 底部固定 `Buy Now` 可能压缩 Tips 阅读空间。
- 横向 HLS 测试源画面比例问题本轮忽略，等待真实竖屏源。

## 验收标准

- 播放中选择 locked episode 后旧音频立即 pause。
- 关闭 unlock sheet 后不恢复旧音频。
- paywall/locked 状态下切 My list / Profile 不出声。
- For You / single drama 现有 pause 行为不回归。
- 解锁弹窗至少完成紧凑卡片方向和关键文案/金额对齐。
- Profile 显示 Settings 入口。
- Wallet 默认值按本轮确认结果一致。

## Implementation Status

- P0 fixed：Player 在 entitlement decision 进入会员、金币确认、充值或 waitUnlock
  分支时，会先把当前 item 交给 `PlayerPlaybackController.playItem()`。controller
  对 locked / unavailable item 会立即 pause 当前 media session、失效 pending open，
  并进入 blocked / unavailable 状态，不再让上一集音频留在后台。
- P1 fixed：金币充足但 auto unlock 关闭时的 coin unlock 弹窗改为 Figma 方向的紧凑
  card，显示 `Price / Balance`、`Play` 主按钮和自动播放下一集开关文案，不再展示大
  `Confirm unlock` 双按钮结构。
- P1 fixed：Profile 增加 `Settings` 入口，当前先接 placeholder 页面，真实设置项
  后续补齐。
- P1 fixed：默认 shared entitlement mock 对齐 Wallet Figma 值：Coins 4000、Bonus
  4000、auto unlock 开启。显式 auto-off / low-coins fixture 仍保留用于解锁弹窗和充值
  测试。
- P2 deferred：My List 密度、Store Tips 被固定 CTA 压缩、横屏 HLS 顶部黑屏仍记录为
  后续优化，不在本轮处理。

## 必跑验证

```bash
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart -d R58WC02B69R
```

## 限制

- 不做多语言。
- 不接真实 API。
- 不改播放器预加载/cache 架构。
- 不改 Store / Wallet / Membership 支付逻辑。
- 不大重构 `PlayerPlaybackController`。
- 不移除现有 smoke 覆盖。
