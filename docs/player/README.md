# Player Docs

本目录放播放器体验、播放源、性能策略、FeedEngine、CDN/HLS 约束相关文档。

## 文档

- [当日有效播放时长缓存方案](daily-effective-watch-time-plan.md)：普通播放页与 For You 的实际观看计时、当日区间去重、持久化与观看任务自动领取（已实现）。
- [Player Experience System Architecture](player-experience-architecture-plan.md)：播放器主架构和 Home / For You / 单剧边界。
- [Player Feed Engine Refactor Plan](player-feed-engine-refactor-plan.md)：当前封板版 FeedEngine、drag/settled、performance policy 的设计说明。
- [Player Android Stable Mode Plan](player-android-stable-mode-plan.md)：Android / iOS / low-end 三档播放 surface 策略。
- [Player Source And CDN Spec](player-source-and-cdn-spec.md)：服务端播放源、HLS、CDN、subtitle、preview 的 contract。
- [Player Local HLS Proxy Cache](player-local-hls-proxy-cache.md)：local proxy/cache spike 结论，仅 diagnostic，不作为生产方案。

## 复用规则

- 播放器主流程、性能策略、低端机策略变更，优先补到 FeedEngine 或 Android stable 文档。
- 播放源字段、CDN、字幕、preview sprite 相关内容，统一写入 [Player Source And CDN Spec](player-source-and-cdn-spec.md)。
- 旧的阶段性播放缓存计划已经归档，不能作为新开发入口。
