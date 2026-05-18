# Release / QA Docs

本目录放封板、QA、回归、RC 验收和 release 风险边界文档。

## 文档

- [Release Seal Checklist](release-seal-checklist.md)：当前版本封板规则、验证命令、禁止开关和 QA smoke 路径。
- [Entitlement Commerce Player Regression](entitlement-commerce-player-regression.md)：权益、充值、播放器组合路径的回归清单。

## 复用规则

- 每次 RC / release 封板时优先更新本目录。
- 一次性问题分析、阶段任务拆分完成后，应归档到 `docs/archive/`，不要长期留在 release 目录。
- release 文档只记录可执行验收项，不承载大版本规划。
