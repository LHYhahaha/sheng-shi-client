# Account Cancellation Plan

## 目标

按 Figma `Group 1940698461` 与产品规则补齐账号注销流程：

1. 入口：`Profile -> Settings -> Account cancellation`。
2. 进入独立账号注销页面。
3. 用户阅读注销影响，勾选风险确认。
4. 删除按钮完成倒计时后才可点击。
5. 点击后弹二次确认。
6. 确认后调用账号注销接口或 mock repository。
7. 成功后触发统一 `SessionCleanupCoordinator`，清理 token、权益、钱包、播放器、modal 等状态。

本任务优先级高于多语言，不并行推进。

## 产品规则

### 入口

- 入口位置：我的页面 -> 设置 -> 账号注销。
- 点击后进入账号注销页面。
- Settings 页面还需要展示：
  - `Account cancellation`
  - `User Agreement`
  - `Privacy Policy`

### 风险确认勾选

- 文案：`我接受删除风险并同意删除我的账户`
- 默认状态：未勾选。
- 未勾选时删除按钮置灰不可点击。
- 勾选后仍需等待倒计时结束，才可点击删除。

### 删除按钮倒计时

- 初始文案：`删除账号（9s）`
- 倒计时结束前按钮不可点击。
- 倒计时结束后按钮可点击。
- 可点击文案：`删除账号`
- 倒计时页面离开后应取消 timer；重新进入页面从 9s 重新开始。

### 二次确认

点击删除账号后弹出二次确认弹窗：

- 标题：`确认删除账号？`
- 文案：`删除后账号信息将无法找回，请确认是否继续。`
- 底部按钮：`取消`、`确认删除`

弹窗应走 `AppModalService`，不要新增本地 `showDialog`。

### 服务端注销条件

服务端校验当前账号状态：

1. 充值金币等于 0。
2. 非会员状态。

若不满足条件，服务端应返回业务错误码。客户端展示错误 toast 或页面错误，不执行本地 cleanup。

### 注销对象

#### 已登录状态

- 用户已登录第三方账号、邮箱账号或手机号账号时，注销对象为当前登录账号绑定的主账号。
- 该主账号下的用户信息、资产、会员状态、解锁记录等执行注销处理。
- 注销后：
  - 若本设备为主账号设备：退出 App 登录态。
  - 若该登录账号绑定主账号非本设备：登出，回到我的页面。

#### 游客状态

- 用户当前为游客身份时，注销对象为当前游客账号。
- 若该游客账号曾绑定过第三方账号，其他设备使用该第三方账号登录的会话也需要自动登出。
- 注销后当前设备自动退出 App 登录态，回到 guest bootstrap 状态。

### 数据处理

- 服务端软删除账号。
- 数据范围包含：
  - 用户行为数据
  - 资产
  - 会员状态
  - 解锁记录
  - 第三方账号绑定信息
  - 设备会话

客户端不直接删除服务端数据，只在接口成功后做本地 cleanup。

## 当前代码现状

- `SettingsPage` 仍是 placeholder，只显示说明文案。
- `AccountPage` 目前包含 logout 和简单 delete account，本地 `AlertDialog` 不符合新流程。
- `AuthController.deleteAccount()` 已存在。
- `AuthRepository.deleteAccount()` 已存在。
- `SessionCleanupAuthRepository.deleteAccount()` 成功后会触发 `SessionCleanupCoordinator.cleanup(SessionCleanupReason.deleteAccount)`。
- A7 已接入 feature cleanup hooks，delete 成功后能清理 token、权益、钱包、Profile、MyList、Player、Store、Membership 和阻塞弹窗。

结论：底层 auth/delete/cleanup 边界可以复用；需要新增 Settings UI、Account cancellation 页面、AppModal 二次确认，以及 mock/remote contract 补齐。

## 推荐实现

### 路由

新增 route：

- `RoutePaths.accountCancellation = '/settings/account-cancellation'`
- route name：`accountCancellation`
- 页面：`AccountCancellationPage`

Settings 页面入口：

- `Account cancellation` -> `RoutePaths.accountCancellation`
- `User Agreement` -> placeholder 或后续 web/text page
- `Privacy Policy` -> placeholder 或后续 web/text page

旧 `RoutePaths.account` 保留给 Account actions / 深链，不在 Profile Settings 新入口中使用。

### 页面状态

新增 `AccountCancellationController` 或页面局部 state。

建议使用 controller，避免倒计时、勾选、提交状态散落在 widget：

```dart
class AccountCancellationState {
  final bool acceptedRisk;
  final int remainingSeconds;
  final bool isSubmitting;
  final Object? error;

  bool get countdownFinished => remainingSeconds <= 0;
  bool get canSubmit => acceptedRisk && countdownFinished && !isSubmitting;
}
```

职责：

- 页面进入后启动 9 秒 countdown。
- 页面 dispose 时取消 timer。
- checkbox 切换 `acceptedRisk`。
- `submit()` 只在 `canSubmit` 时可执行。
- 提交成功调用 `AuthController.deleteAccount()` 或专用 repository API。

### 二次确认 AppModal

新增或复用 confirm modal：

- 如果现有 `ConfirmModalRequest` 能满足标题/文案/双按钮，优先复用。
- `source`: `AppModalSource.auth`
- `channel`: `auth.account_cancellation_confirm`
- `priority`: blocking 或 standard，按现有 confirm policy。
- result: `ConfirmResult.confirmed / cancelled / dismissed`

确认后再调用 delete。

### Auth Repository Contract

当前 `deleteAccount()` 无入参。真实阶段建议扩展 data 层 DTO，而 domain 可先保持无入参：

```json
POST /auth/account/delete
{
  "acceptedRisk": true,
  "deviceId": "...",
  "sessionKind": "guest|authenticated"
}
```

返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "deletedAccountId": "...",
    "result": "logged_out|guest_reset|app_exit_required"
  }
}
```

错误码建议：

- `2xxx` 用户域
- 余额不为 0
- 仍是会员
- 会话失效
- 风控/频繁请求

本轮仍不接真实 API，只把 DTO / docs / mock 行为先对齐。

### 成功后的客户端行为

成功后：

1. `SessionCleanupAuthRepository.deleteAccount()` 触发 cleanup。
2. 清理 token 和 feature state。
3. 回到 `RoutePaths.profile`。
4. 展示 toast：`账号已删除` 或 `Account deleted`。

关于“退出 App”：

- iOS/Android 通常不建议主动 kill App。
- 产品说“退出 app / 自动退出 App 登录态”在客户端建议解释为：退出当前登录态，回到 Profile guest 状态。
- 如果服务端返回 `app_exit_required`，客户端可展示说明并回 Profile，不主动调用系统退出。

## 分阶段开发

### AC1: Settings 页面与路由

目标：

- Settings 页面按 Figma 列表展示。
- Account cancellation 入口可跳转。
- User Agreement / Privacy Policy 先做 placeholder 页面或 disabled route。

文件范围：

- `lib/features/profile/presentation/pages/settings_page.dart`
- `lib/app/router/route_paths.dart`
- `lib/app/router/route_names.dart`
- `lib/app/router/app_router.dart`
- `lib/l10n/app_localizations.dart`
- tests

### AC2: Account cancellation 页面

目标：

- 新增账号注销页面。
- UI 对齐 Figma：标题、说明、信息删除卡、风险提示、底部 checkbox + button。
- 倒计时 9s。
- 未勾选/倒计时未结束不可点击。

文件范围：

- `lib/features/auth/presentation/pages/account_cancellation_page.dart`
- 可选：`lib/features/auth/application/account_cancellation_controller.dart`
- `lib/l10n/app_localizations.dart`
- tests

### AC3: 二次确认与删除动作

目标：

- 点击可用按钮后弹 AppModal 二次确认。
- 确认后调用 `AuthController.deleteAccount()`。
- 成功后回 Profile。
- 失败时保留页面，展示 toast 或错误文案。

文件范围：

- `lib/features/auth/presentation/pages/account_cancellation_page.dart`
- `lib/core/modal` 如需 confirm 样式补充
- `lib/features/auth/application/auth_controller.dart` 如需状态细化
- tests

### AC4: Mock / Contract / Cleanup 验证

目标：

- mock 删除路径覆盖 guest/authenticated 两类状态。
- 删除成功必须触发 SessionCleanup。
- 不满足条件的服务端错误先以 fake repository 测试表达。
- 文档同步 remote contract。

文件范围：

- `lib/features/auth/data/dto/delete_account_request_dto.dart`
- `lib/features/auth/data/remote/auth_remote_data_source.dart`
- `lib/features/auth/data/mock_auth_repository.dart`
- `docs/api/remote-contract-index.md`
- tests

## 测试计划

### Widget

- Settings 显示三项入口。
- 点击 Account cancellation 进入注销页面。
- 注销页面默认：
  - checkbox 未勾选
  - button 显示 `删除账号（9s）`
  - button disabled
- 倒计时结束但未勾选：button 仍 disabled。
- 勾选但倒计时未结束：button 仍 disabled。
- 勾选且倒计时结束：button enabled，文案 `删除账号`。
- 点击后展示二次确认 AppModal。
- 点击取消：不调用 delete。
- 点击确认删除：调用 delete，成功回 Profile。

### Controller / Unit

- countdown 正确从 9 到 0。
- dispose 取消 timer。
- submit 防重复。
- delete 失败保留页面和错误。
- delete 成功触发 cleanup。

### Integration / Smoke

- Profile -> Settings -> Account cancellation。
- guest 状态删除。
- logged in 状态删除。
- 删除成功后：
  - 回 Profile guest
  - Wallet/Entitlement/MyList 清理
  - Player 无后台声音
  - AppModal 队列清空

### Architecture

- Settings/Profile UI 不直接调用 network。
- Account cancellation 页面只通过 AuthController / AppModal 调用。
- core/modal 不 import auth feature。
- 删除二次确认不使用本地 `showDialog`。

## 不做

- 不接真实 API。
- 不实现真正退出 App 进程。
- 不做 User Agreement / Privacy Policy 正式内容。
- 不改登录 / account link 主流程。
- 不改支付、钱包、会员业务规则。
- 不把注销接口做成 UI 直接调用 remote datasource。

## 需要产品/后端确认

1. “充值金币等于 0”是否包含 bonus balance？
2. 游客账号注销后，是否立即创建新 guest session，还是停留在无 session 状态？
3. “本设备为主账号则退出 app”客户端是否可以解释为退出登录态并回 Profile？
4. 删除成功是否需要 toast？
5. 服务端错误码：
   - 余额不为 0
   - 会员仍有效
   - 会话失效
   - 账号已注销
6. User Agreement / Privacy Policy 是内置页面、WebView、还是外链浏览器？
