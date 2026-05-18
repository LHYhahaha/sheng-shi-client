# Drama Client Docs

本文档夹只保留当前仍有效的工程规范、封板说明、联调契约和架构说明。已完成的 MVP 计划、热修记录、阶段跟踪已归档到 [2026-05 RC Historical Archive](archive/2026-05-rc/README.md)。

## 当前入口

| 分类 | 文档 |
| --- | --- |
| 封板 / QA | [Release Docs](release/README.md), [Release Seal Checklist](release/release-seal-checklist.md) |
| 全局弹窗 | [Modal Docs](modal/README.md), [AppModal Supported Modals](modal/app-modal-supported-modals.md), [Global Overlay / Modal System Plan](modal/global-overlay-modal-system-plan.md) |
| Runtime / 设备策略 | [Runtime Docs](runtime/README.md), [App Runtime System](runtime/app-runtime-system.md) |
| 账号 / Auth | [Auth Docs](auth/README.md), [Account Cancellation Plan](auth/account-cancellation-plan.md) |
| API / 联调 | [API Docs](api/README.md), [Remote Contract Index](api/remote-contract-index.md), [Remote API Staging Checklist](api/remote-api-staging-checklist.md), [API Integration Readiness Plan](api/api-integration-readiness-plan.md), [Networking Guidelines](api/networking-guidelines.md) |
| 播放器 | [Player Docs](player/README.md), [Player Experience System Architecture](player/player-experience-architecture-plan.md), [Player Android Stable Mode Plan](player/player-android-stable-mode-plan.md), [Player Feed Engine Refactor Plan](player/player-feed-engine-refactor-plan.md), [Player Source And CDN Spec](player/player-source-and-cdn-spec.md) |
| 多语言 / 首页数据 | [Localization Docs](localization/README.md), [Localization And Home Data Architecture](localization/localization-and-home-data-architecture.md) |
| 工程规范 | [Engineering Docs](engineering/README.md), [Project Structure And Conventions](engineering/project-structure-and-conventions.md), [Development Guidelines](engineering/development-guidelines.md), [Technical Architecture](engineering/technical-architecture.md) |
| 历史归档 | [2026-05 RC Historical Archive](archive/2026-05-rc/README.md) |

## 归档规则

- **当前文档**：仍代表代码现状、测试边界、QA 流程、联调契约或下一版本设计输入。
- **历史文档**：已经完成的 MVP 计划、阶段拆分、真机问题记录、一次性 hotfix 方案、旧 roadmap。
- 开新版本前，先检查 `docs/README.md` 和 `README.md`，避免把旧计划当成新任务。
