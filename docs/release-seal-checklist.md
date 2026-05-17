# Release Seal Checklist（Mock RC 封板）

日期：2026-05-17

本文档是 **Release Readiness Review 2** 后的封板与 QA 执行清单。  
**结论**：当前 mock RC 可以封板；无 P0；无封板前必修 P1。真实 API / IAP / secure storage / A8.1 均 defer。

相关文档：

- [Remote API Staging Checklist](remote-api-staging-checklist.md) — **仅** internal staging 联调构建
- [Post-RC Roadmap & Phase Plan](post-rc-roadmap-and-phase-plan.md)
- [Remote Contract Index](remote-contract-index.md)
- [Entitlement Commerce Player Regression](entitlement-commerce-player-regression.md)

---

## 1. Release Build Safety

### 当前 RC 默认行为

- 所有 `USE_REMOTE_*` 编译期默认 **`false`**（含 legacy `USE_REMOTE_API`）。
- 支付与权益走 **mock**（`grantMock*`、mock purchase delay）；不接真实后端。
- `RemoteApiReadinessGuard` 已就绪，但 feature provider **尚未**强制读取 `effective` switches（A8.1 defer）。

### 正式 Release / RC 构建规则

| 规则 | 说明 |
| --- | --- |
| **禁止 remote 开关** | 正式 **release / RC / 商店候选包** 不得携带任何 `USE_REMOTE_*=true`。 |
| **禁止误指后端** | 不得设置 `API_BASE_URL` 指向 staging 或 prod 真实后端，**除非**该包明确标记为 **internal staging build**（见下）。 |
| **联调与封板分离** | 真实 API 联调必须使用 **单独的 internal staging build**（独立 CI job / 手工命令），不得与封板 RC 混用同一构建参数。 |
| **第一阶段联调** | internal staging 首次只允许 `USE_REMOTE_DRAMA_API=true` + 真实 staging `API_BASE_URL`；禁止同时开 Auth / Entitlement / Wallet / Store / Membership / Player remote。 |

### Internal staging build（非 RC）

仅用于工程/QA 联调，**不得**提交商店或对外标为 RC：

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<your-staging-host> \
  --dart-define=USE_REMOTE_DRAMA_API=true
```

详见 [remote-api-staging-checklist.md](remote-api-staging-checklist.md)。

---

## 2. Allowed / Forbidden Dart Defines

### Allowed for RC（封板 / 商店候选包）

| dart-define | 说明 |
| --- | --- |
| `APP_ENV=prod` | 推荐；或使用工程默认 prod |
| （不设置） | 不设置任何 `USE_REMOTE_*` |
| （不设置） | 不设置 `API_BASE_URL`（使用 mock / 内置默认） |
| 内部 QA 包可选 | 仅 **internal QA** 包可开诊断类开关（若有文档化 define）；**不得**进入商店 RC |

### Forbidden for RC

以下 **任一出现** 即视为非封板包，不得标为 RC release：

| dart-define | 原因 |
| --- | --- |
| `USE_REMOTE_DRAMA_API=true` | RC 必须全 mock |
| `USE_REMOTE_API=true`（legacy） | 等同 drama remote |
| `USE_REMOTE_PLAYER_API=true` | 中风险；未接真实 playback 策略 |
| `USE_REMOTE_MY_LIST_API=true` | 需 guest/auth |
| `USE_REMOTE_PROFILE_API=true` | 需 required token |
| `USE_REMOTE_AUTH_API=true` | 高风险 |
| `USE_REMOTE_ENTITLEMENT_API=true` | 高风险 |
| `USE_REMOTE_WALLET_API=true` | 高风险 |
| `USE_REMOTE_STORE_API=true` | 高风险 |
| `USE_REMOTE_MEMBERSHIP_API=true` | 高风险 |
| `API_BASE_URL=<real backend>` | 仅 internal staging build 允许 |
| `PLAYER_HLS_LOCAL_PROXY_SPIKE=true` | 实验特性，禁止生产/RC |

**CI 建议（文档约定，非本轮实现）**：release 流水线 assert 构建日志中不包含上述 forbidden defines。

---

## 3. QA Smoke Checklist（Mock RC）

执行前确认：安装包为 **无 remote defines** 的 release/profile 构建。  
建议设备：**Android 低端机（denylist 或同级）** + **iPhone** 各一台。

### 3.1 自动化（工程门禁）

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [ ] `flutter analyze`（0 issues）
- [ ] `flutter test`（全绿）
- [ ] 可选（真机连接）：`flutter test integration_test/app_smoke_test.dart -d <deviceId>`

### 3.2 冷启动与导航

- [ ] 冷启动进入 **Home**，Popular / 分类正常展示
- [ ] 点击 Home 卡片进入 **单剧播放器**（EP.01 等）
- [ ] 底部 Tab：**For You**、**My List**、**Profile** 可切换无崩溃

### 3.3 Player — 单剧

- [ ] 单剧 feed **连续向上滑动 5 集**，无黑屏卡死、无异常后台声音
- [ ] 返回 Home / 再进入播放器，状态正常

### 3.4 Player — For You

- [ ] For You **连续滑动 5 条**，滑动流畅
- [ ] Watch Now / 进入单剧路径正常

### 3.5 Player — Locked episode（权益 / 充值主链路）

在 **锁定集** 上验证（mock 金币/会员）：

- [ ] 金币 **足够**：小 **Play** 解锁弹窗 → 确认 → 可播放
- [ ] 金币 **不足**：**充值** 弹窗出现
- [ ] 充值流程：**payment confirmation** 弹窗
- [ ] **Mock 充值成功** 后回到 Play / 自动继续播放意图正常
- [ ] **Mock 会员** 开通后锁定集可直接播放（无需再弹金币解锁）

### 3.6 Auth — Login modal（O3）

- [ ] **Profile** → 点击「Log in」→ 全局 **Auth login modal** 出现
- [ ] **取消** → modal 关闭，仍 guest 态
- [ ] **Mock 登录成功**（Google/Facebook mock）→ modal 关闭，Profile 展示已登录态

### 3.7 Store

- [ ] 进入 Store，选择商品 → **购买确认** AppModal
- [ ] **Cancel** → 无扣费、无异常 toast
- [ ] **Mock success** → 金币/权益变化符合 mock 规则（经 EntitlementController）

### 3.8 Membership

- [ ] 套餐卡 **横向滑动居中** 正常（Figma 对齐）
- [ ] 购买 → **确认 AppModal** → **Cancel**
- [ ] **Mock success** → 会员态 / Player 锁定集播放符合预期

### 3.9 Wallet

- [ ] **Auto unlock** Switch 与 **Player coin unlock sheet** 内展示/逻辑 **状态同步**（开关开闭后两边一致）

### 3.10 Tab / 返回 / 后台

- [ ] 播放中切 Tab、按返回：播放器 **pause**，**无后台声音**
- [ ] 弹出过解锁/充值/登录/Store/Membership modal 后切 Tab 或 logout：**modal 不残留**、不挡点击
- [ ] App 进后台再回前台：无意外续播（除非用户仍在 Player 且未离开）

### 3.11 Android 低端机

- [ ] 单剧 / For You **滑动不卡死**（`ultraStable`：拖动时 surface 可隐藏，属预期）
- [ ] 落位后视频可正常起播；连续滑 5 条/5 集可接受

### 3.12 iPhone

- [ ] For You / 单剧播放正常
- [ ] 各类 **AppModal**（登录、解锁、充值、Store/Membership 确认）**safe area** 正常，底部不被 Home Indicator 遮挡

---

## 4. Final Defers（封板后 / 真实联调前）

以下 **不在** mock RC 封板范围，按 Post-RC Track 排期：

| 项 | 说明 |
| --- | --- |
| **A8.1** | `remoteApiEffectiveSwitchesProvider` 接入各 repository，prod fail-closed |
| **Secure storage 默认** | `FlutterSecureAuthTokenStorage` 作为默认（当前 in-memory） |
| **Guest bootstrap HTTP** | `GuestSessionBootstrap` 真实 `POST /auth/guest/session` |
| **Real OAuth** | Google/Facebook SDK + 服务端 token 交换 |
| **Real IAP / order verification** | 商店验单、订单状态机 |
| **Remote entitlement / wallet / store / membership** | 支付与权益后端就绪前禁止 |
| **Profile DTO strict** | 开 `USE_REMOTE_PROFILE_API` 前对齐 `JsonFieldParser` |
| **PlayerPlaybackController 拆分** | 维护性重构，测试已锚定 |
| **Modal Ops** | 运营活动 / 强更 / 风控弹窗（与 O1–O5 业务 modal 分列） |

---

## 5. Commands（封板门禁）

### 工程验证（每次封板 / 发 RC 前）

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

### Release 包构建（RC — 无 remote defines）

```bash
flutter build apk --release
# iOS:
# flutter build ipa --release
```

**不得**在以上命令追加 `USE_REMOTE_*` 或 `API_BASE_URL`。

### 可选：真机集成冒烟

```bash
flutter test integration_test/app_smoke_test.dart -d <deviceId>
```

### Internal staging（非 RC，仅供联调）

见 [remote-api-staging-checklist.md](remote-api-staging-checklist.md)。

---

## 6. Sign-off

| 角色 | 项 | 签字 / 日期 |
| --- | --- | --- |
| 工程 | format / analyze / test 全绿 | |
| 工程 | RC 构建无 forbidden defines | |
| QA | §3 QA Smoke 全项 | |
| QA | Android 低端机 + iPhone 抽测 | |
| 产品 | mock 支付/权益行为符合预期 | |

**封板判定**：§3 无 P0 阻塞 + §5 命令通过 + RC 包符合 §1–§2 → **可封板**。
