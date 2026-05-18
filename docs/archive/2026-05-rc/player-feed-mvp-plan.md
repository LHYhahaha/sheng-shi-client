# Player Feed MVP Plan

本文档记录下一轮播放器核心功能开发计划。它只覆盖 Player Feed MVP，不替代整体开发排期，也不纳入工程整改记录。

## 1. 目标

本轮要做出两个播放场景：

- 单部剧播放：从首页或剧集入口进入某部剧后，支持上下滑切换上一集 / 下一集。
- For You 推荐流：底部 `For you` tab 展示推荐播放 feed，支持上下滑切换不同短剧 / 剧集。

两种场景复用同一套播放器 UI 和基础交互，不复制两套播放器页面。

## 2. 本轮范围

必须做：

- 定义播放器 feed 模式和 feed item 模型。
- 新增 `PlayerFeedController` 或等价 application controller。
- `PlayerPage` 支持纵向 `PageView` 切换。
- 首页短剧卡片进入单部剧 feed。
- `For you` tab 不再是 placeholder，进入推荐 feed。
- 保留现有播放器 Figma 视觉结构。
- 保留现有弹窗能力：剧集列表、简介/更多、分享、解锁/会员弹窗。
- 使用 mock 数据完成交互闭环。
- 补 controller/widget 层关键测试。

不做：

- 不接真实服务端接口。
- 不接支付、会员、钱包。
- 不做真实推荐算法。
- 不做复杂预加载。
- 不做 ARB/gen-l10n 迁移。
- 不重画播放器 UI。
- 不扩大到 Store / Wallet / Membership / Payment。

## 3. 建议任务拆分

| 任务 | 内容 | 估时 |
|---|---|---:|
| P1 feed 模型设计 | 定义 `PlayerFeedMode`、`PlayerFeedItem`，明确 single drama 与 For You 的数据差异 | 0.5 天 |
| P2 feed controller | 加载 single drama feed、加载 For You feed、管理 currentIndex、处理滑动切换 | 1 天 |
| P3 PlayerPage 改造 | 使用纵向 `PageView`，每个 page 复用现有 `PlayerChrome` 和 sheets | 1 天 |
| P4 入口接入 | 首页卡片进入 single drama feed，For You tab 进入推荐 feed | 0.5-1 天 |
| P5 测试与验证 | controller 测试、基础 widget 测试、format/analyze/test | 0.5 天 |

本轮目标工期：3.5-4 个工作日。

如果同时接入 `media_kit` 真播放，需另加 1.5-2 个工作日；建议单独开后续任务 `Player Playback Integration`。

## 4. 实现约束

- 继续遵守 feature-first 分层。
- feed 状态放在 `lib/features/player/application/`。
- feed mock 数据放在 `lib/features/player/data/`，不要写进 widget。
- 业务实体和值对象放在 `lib/features/player/domain/`。
- 页面只负责 UI 组装、路由参数读取后的展示协调、弹窗调用。
- 路由路径继续使用 `RoutePaths` / `RouteNames`，不要散落字符串。
- 复用现有 `PlayerChrome`、`PlayerUiController`、player sheets 和 shared widgets。
- 不因为实现纵向 feed 改变已验收播放器视觉结构。

## 5. 验收标准

- 从首页短剧卡片进入播放器后，可以上下滑切换同一部剧的集数。
- 从底部 `For you` tab 进入推荐 feed 后，可以上下滑切换不同短剧 / 剧集。
- 滑动后 UI 展示同步更新：剧名、集数、简介、背景/封面、推荐信息。
- 现有剧集列表、简介、分享、解锁/会员弹窗仍可打开。
- `flutter analyze` 通过。
- `flutter test` 通过。
- 新增或更新的测试覆盖 feed controller 的两种模式和当前 item 切换。

## 6. 后续任务

本轮完成后，再单独评估：

- `media_kit` 真播放切换。
- 播放 URL 获取与错误态。
- 下一集/下一条 feed 预加载。
- 解锁状态与权益接口。
- 播放历史和进度上报。
