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

## Unlock UX Round 2

日期：2026-05-16

最新产品确认：locked 视频不能因为 auto unlock enabled 或金币充足而直接扣费播放。
当前 locked episode 必须先展示播放器内 `Unlock Now` 覆盖按钮，并进入用户确认流程。

Figma 对照块：

- 图一：`解锁弹窗`
- 图二：`Unlock Now`
- 图三：`播放页-充值`

### 目标流程

1. 用户滑到 locked episode。
2. 播放器中间显示 `Unlock Now` 按钮。
3. 自动判断当前金币余额：
   - 余额足够：弹 `解锁弹窗`。
   - 余额不足：弹 `播放页-充值`。
4. `解锁弹窗` 中用户点击 `Play` 后，才扣金币、解锁并播放。
5. `播放页-充值` 中充值成功后，不直接播放；应回到 `解锁弹窗`，由用户点击
   `Play` 完成解锁。
6. 用户关闭任一弹窗后：
   - 当前 episode 保持 locked poster / fallback。
   - `Unlock Now` 按钮仍可见。
   - 不播放旧视频声音。
   - 用户可以继续上下滑。
7. 用户继续滑到下一个 episode：
   - free / 已解锁：直接播放。
   - locked：重复本流程，继续显示 `Unlock Now` 并弹对应抽屉。

### 需要修正的现有偏差

- `autoUnlockAndPlay` 不能绕过当前 locked episode 的确认弹窗。
- `auto unlock` 开关只能作为“后续自动播放下一集”偏好，不能让当前 locked episode
  静默扣费播放。
- 充值成功后不能直接播放，必须回到 `解锁弹窗`。
- `Unlock Now` 是播放器内覆盖按钮，不是只在底部 sheet 中出现。

### 验收标准

- locked episode 余额足够时，自动弹 `解锁弹窗`，不直接播放。
- locked episode 余额不足时，自动弹 `播放页-充值`。
- 充值成功后自动回到 `解锁弹窗`，不直接播放。
- 关闭 `解锁弹窗` 后，播放器中间仍显示 `Unlock Now`，且无旧音频。
- 点击 `Unlock Now` 可以再次打开对应流程。
- 连续 locked episodes 不偷拉未授权 source，不播放旧 session。
- paywall/locked 状态切 My list / Profile 不出声。

### Round 2 实现备注

- `autoUnlockAndPlay` enum / remote mapper 保留兼容，但播放器当前 locked episode 不再
  静默调用 `unlockWithCoins`；即使 auto unlock 开启，也按 `showCoinUnlockDialog`
  确认流程处理。
- `PlayerCoinUnlockSheet`、`PlayerRechargeUnlockSheet`、
  `PlayerRechargeUnlockController` 和 `PlayerChrome` 原有结构继续复用；本轮只做链路
  串接和 Figma 尺寸/位置小修，不新增第二套 unlock/recharge UI。
- 充值成功只 grant mock entitlement，不直接播放；金币包成功后自动回到金币解锁弹窗，
  等用户点击 `Play` 才扣金币并播放。

## Unlock UX Round 3

日期：2026-05-16

真机体验新增问题：

1. 用户上滑进入 locked episode 时，`PageView` 还没有滑动到位，解锁/充值抽屉就已经弹出，
   导致画面卡顿、滑动体验不顺。
2. 用户在 `解锁弹窗` 点击 `Play` 后，音频和进度条已经开始播放，但画面仍停留在封面，
   说明 unlock success 后 playable video surface 没有可靠恢复，poster 仍然挡住视频。

### 目标

本轮只修 locked episode 的体验时序，不重画弹窗、不新增第二套 UI、不改 entitlement 决策模型。

### 需要修正的行为

1. 自动弹窗必须等滑动稳定后再打开：
   - `PageView` scroll end 后再评估是否自动打开 `解锁弹窗` / `播放页-充值`。
   - 可加短 debounce，例如 150-250ms，避免滑动刚落位时立即抢焦点。
   - 如果用户继续滑动，取消上一轮 pending auto sheet。
   - auto sheet 打开前必须校验当前 item 仍是同一个 locked episode，且当前没有其他 modal/sheet。
2. 手动点击 `Unlock Now` 不需要等待 debounce：
   - 用户主动点击按钮时，应立即打开对应流程。
   - 但仍需校验 current item / modal / access decision。
3. 解锁成功后必须恢复 playable video surface：
   - `Play` 成功扣费后，当前 episode 应重新 evaluate 为可播放。
   - 调用播放前要确保 locked/paywall blocked 状态清掉，Video surface 可以重新 attach。
   - 如果 `playing=true` 或 position 已推进但 `hasFirstFrame=false`，应显示 video surface +
     loading overlay，poster 只能作为底层 fallback，不能继续完整盖住视频。
   - 不允许出现“有声音、进度在走、画面仍是封面”的状态。
4. 关闭弹窗后保持现有 Round 2 行为：
   - 当前 episode 保持 locked poster / fallback。
   - `Unlock Now` 按钮仍可见。
   - 不播放旧音频。
   - 用户可以继续上下滑。

### 验收标准

- 上滑进入 locked episode 时，先完成滑动落位，再弹出对应抽屉；不能在滑动过程中抢弹。
- 快速连续滑 EP04 -> EP05，只允许最终当前 item 的抽屉出现。
- 关闭抽屉后，`Unlock Now` 按钮仍在，且无旧音频。
- 点击 `Unlock Now` 可以立即打开对应流程。
- 余额足够路径：点击 `Play` 后能显示视频画面并播放，不停留在封面。
- 余额不足路径：充值成功后回到 `解锁弹窗`；再点 `Play` 后能显示视频画面并播放。
- locked / unavailable 仍不 preload / prepare / open unauthorized source。

### 建议涉及文件

- `lib/features/player/presentation/pages/player_page.dart`
- `lib/features/player/presentation/widgets/player_chrome.dart`
- `lib/features/player/application/player_playback_controller.dart`
- `lib/features/entitlement/application/entitlement_controller.dart`
- `test/features/player/player_page_test.dart`
- `integration_test/app_smoke_test.dart`

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
