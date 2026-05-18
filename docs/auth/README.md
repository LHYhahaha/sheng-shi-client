# Auth / Account Docs

本目录放登录、游客账号、账号绑定、退出登录、账号注销和 session cleanup 相关文档。

## 文档

- [Account Cancellation Plan](account-cancellation-plan.md)：账号注销入口、风险确认、倒计时、二次确认、服务端校验和 cleanup 方案。

## 复用规则

- 涉及 token、guest session、account link、logout/delete cleanup 的需求，应优先放在本目录。
- UI 层入口可以来自 Profile / Settings，但账号真相和破坏性动作必须通过 Auth / Session cleanup 边界。
- 账号注销属于破坏性流程，不能只做本地状态清理；真实阶段必须等待服务端校验与注销接口成功。
