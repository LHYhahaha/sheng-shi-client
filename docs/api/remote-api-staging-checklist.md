# Remote API Staging Checklist (A8)

日期：2026-05-17

本文档说明如何**安全**打开 `USE_REMOTE_*`、staging smoke 命令与 guard 规则。  
**不接真实 API 前**：所有开关编译期默认 `false`；`RemoteApiReadinessGuard` 用于校验组合，feature provider **默认仍读** `RemoteApiSwitches.fromEnvironment()`（未自动套用 `effective`，避免隐式行为变化）。

> **与 RC 封板包区分**  
> - **Mock RC / 商店候选 release**：**禁止**任何 `USE_REMOTE_*=true` 与真实 `API_BASE_URL`。见 [release-seal-checklist.md](../release/release-seal-checklist.md) §1–§2。  
> - **本文档**：仅适用于 **internal staging build**（工程/QA 联调），不得与封板 RC 使用同一构建参数。

## Remote API Switch Matrix

| dart-define | 模块 | 风险 | 默认 | 第一阶段 staging |
| --- | --- | --- | --- | --- |
| `USE_REMOTE_DRAMA_API` | Home / Drama | 低 | false | **允许** |
| `USE_REMOTE_API`（legacy） | 仅映射 Drama | 低 | false | 等同 drama |
| `USE_REMOTE_PLAYER_API` | Player 内容 / feed / playback source | 中 | false | 先 dry-run，再按需 |
| `USE_REMOTE_MY_LIST_API` | 片单 / 播放历史 | 中 | false | 需 guest/auth 就绪 |
| `USE_REMOTE_PROFILE_API` | Profile 摘要 | 中 | false | 需 required token |
| `USE_REMOTE_AUTH_API` | 登录 / token / account link | **高** | false | **禁止** |
| `USE_REMOTE_ENTITLEMENT_API` | 权益 / 解锁 | **高** | false | **禁止** |
| `USE_REMOTE_WALLET_API` | 钱包 | **高** | false | **禁止** |
| `USE_REMOTE_STORE_API` | 商店 / 订单 | **高** | false | **禁止** |
| `USE_REMOTE_MEMBERSHIP_API` | 会员 / 订阅 | **高** | false | **禁止** |

实现索引：`lib/core/network/remote_api_switches.dart`、`RemoteApiReadinessGuard.validate`。

## Guard Rules（摘要）

| APP_ENV | 低（Drama） | 中（Player/MyList/Profile） | 高（Auth/Entitlement/Wallet/Store/Membership） |
| --- | --- | --- | --- |
| **dev** | 允许（非 placeholder `API_BASE_URL`；localhost 仅 dev） | 允许 + **warning** | **始终 block** + error |
| **staging** | 允许（真实 staging host） | 允许 + **warning** | **始终 block** + error |
| **prod** | 允许 + warning（真实 host） | **block** + error | **始终 block** + error |

**共同规则：**

- 任一 remote 开启时，`API_BASE_URL` 不得为 `*.example.com`、模板 host 或文档占位符。
- 高风险模块在任何环境下 **effective = false**（fail-closed）。
- Remote 失败 **不** 静默回退 mock（见 `drama_remote_dry_run_test`）。

## Safe Remote Enable Order（后端就绪后）

1. **仅** `USE_REMOTE_DRAMA_API=true` + 真实 `API_BASE_URL`（staging）
2. Player 只读内容（仍不开 playback source）— 需单独评审
3. Guest bootstrap + Auth mock/真实 token 策略确认后，再开 My List / Profile
4. Playback source（签名 URL / `expiresAt` strict）
5. Entitlement / Wallet / Store / Membership / IAP — **支付与验单就绪前禁止**

## Staging Smoke Commands

**注意：** 以下命令用于 **internal staging**，不是 mock RC 封板包。RC 构建见 [release-seal-checklist.md](../release/release-seal-checklist.md) §5。

### 第一阶段（推荐）：仅 Home / Drama

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<your-staging-host> \
  --dart-define=USE_REMOTE_DRAMA_API=true
```

Release 包验证：

```bash
flutter build apk --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<your-staging-host> \
  --dart-define=USE_REMOTE_DRAMA_API=true
```

### 不要同时开启（staging 首次联调）

```bash
# 错误示例 — guard 会 report error，且不应手动绕过
--dart-define=USE_REMOTE_AUTH_API=true
--dart-define=USE_REMOTE_ENTITLEMENT_API=true
--dart-define=USE_REMOTE_STORE_API=true
--dart-define=USE_REMOTE_WALLET_API=true
```

## Smoke 检查项

- [ ] `API_BASE_URL` 为真实 staging host（非 `staging-api.example.com`）
- [ ] 请求头含 `Device-Id` / `Lang` / `Platform` / `App-Version`（A4）
- [ ] Envelope `code == 0` 才成功
- [ ] DTO strict 缺字段 → `ApiMappingException`（不伪装成功）
- [ ] 首页分类 / feed 可加载；失败有明确错误，**不回 mock**
- [ ] 未开 Auth 时不要测 required 接口（片单/钱包/解锁）
- [ ] `RemoteApiReadinessGuard.validate` 无 errors（可在测试或调试日志打印 report）

## 自动化

- `test/core/network/remote_api_readiness_guard_test.dart`
- `test/features/drama/drama_remote_dry_run_test.dart`
- `test/architecture/remote_switch_default_test.dart`

## 下一步接入 provider（可选）

将 feature `useRemote*Provider` 改为读取 `remoteApiEffectiveSwitchesProvider` 可在 prod/staging **强制 fail-closed**。当前 A8 仅提供 report，**不改变**默认 repository 选型。
