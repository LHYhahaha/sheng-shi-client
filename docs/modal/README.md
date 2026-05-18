# AppModal Docs

本目录放全局弹窗中控、已支持弹窗清单、弹窗队列和 presenter 接入规范。

## 文档

- [AppModal Supported Modals](app-modal-supported-modals.md)：当前已经接入 AppModal 的弹窗、用途、source、channel 和调用方式。
- [Global Overlay / Modal System Plan](global-overlay-modal-system-plan.md)：AppModal 架构、队列、优先级、host、presenter 的设计。

## 复用规则

- 需要跨 Tab、跨页面、阻塞业务流程的弹窗，应通过 AppModal 接入。
- 页面局部工具 sheet，例如播放器详情、分享、倍速，可以继续保留页面内 sheet，但需要在架构测试白名单中明确。
- 新增弹窗必须记录 source、channel、payload、result、dismiss 行为和是否 blocking。
