# API / Remote Integration Docs

本目录放真实 API 联调、网络层、DTO contract、remote switch 和 staging 验收相关文档。

## 文档

- [Remote Contract Index](remote-contract-index.md)：远程接口、模块开关、auth policy、strict DTO 的总索引。
- [Remote API Staging Checklist](remote-api-staging-checklist.md)：真实 staging 联调时的打开顺序和验收清单。
- [API Integration Readiness Plan](api-integration-readiness-plan.md)：联调前基础设施、token、guest、cleanup、headers 的准备状态。
- [API Integration Plan](api-integration-plan.md)：mock 到真实 API 的整体演进方案。
- [Networking Guidelines](networking-guidelines.md)：`ApiClient`、header、envelope、错误码、refresh 的网络规范。
- [Mock Data And API Readiness Review](mock-data-and-api-readiness-review.md)：mock 数据结构与真实 API contract 的对齐 review。

## 复用规则

- 新接口、新 remote provider、新 DTO strict 规则，优先补到 [Remote Contract Index](remote-contract-index.md)。
- 网络层行为变化，补到 [Networking Guidelines](networking-guidelines.md)。
- 真实 staging 验收步骤，补到 [Remote API Staging Checklist](remote-api-staging-checklist.md)。
- 不在本目录放一次性 UI 计划或播放器体验调优记录。
