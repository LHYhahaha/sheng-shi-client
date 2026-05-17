# AppModal Supported Modals（全局弹窗清单）

日期：2026-05-17

本文档列出当前已经接入 `AppModalService` 的全局阻塞式弹窗、用途、调用方式和扩展规则。  
页面局部弹窗（例如播放器详情、分享、倍速）不在本文档范围内。

## 1. 什么时候使用 AppModal

使用 `AppModalService` 的场景：

- 需要跨页面、跨 tab、跨播放器层级展示的阻塞式业务弹窗。
- 调用方需要等待明确结果：成功、取消、关闭、失败。
- 弹窗不能被 bottom tab、局部 Stack、播放器层级或 safe area 遮挡。
- 弹窗需要在 logout / refresh failed / delete account 等 session cleanup 时统一关闭。

不使用 `AppModalService` 的场景：

- 页面内菜单、tooltip、dropdown。
- 纯局部 UI sheet，例如 Player detail / share / speed。
- toast。瞬态提示继续使用 `AppToastService`。
- 需要长驻页面的普通 view。

## 2. 全局入口

通用入口：

```dart
final modal = ref.read(appModalServiceProvider);
```

常用 API：

```dart
abstract class AppModalService {
  Future<ConfirmResult> showConfirm(ConfirmModalRequest request);
  Future<AppModalResult> show(AppModalRequest request);
  void dismissCurrent({AppModalResult? result});
  void dismissByRequestId(String requestId, {AppModalResult? result});
  void dismissForSource(AppModalSource source, {AppModalResult? result});
  void dismissAllBlockingBusinessModals({AppModalResult? result});
}
```

请求必须有：

- `requestId`：使用 `appModalControllerProvider.nextRequestId()` 生成。
- `source`：弹窗来源，用于诊断、cleanup 和按来源关闭。
- `priority`：队列排序。
- `dismissPolicy`：遮罩 / 返回键关闭策略。
- `type`：业务类型。

业务自定义弹窗使用 `FeatureAppModalRequest`：

```dart
final request = FeatureAppModalRequest(
  requestId: ref.read(appModalControllerProvider).nextRequestId(),
  source: AppModalSource.player,
  channel: 'player.coin_unlock',
  type: AppModalType.coinUnlock,
  payload: payload,
  priority: AppModalPriority.high,
  dismissPolicy: AppModalDismissPolicy.standard,
);

final result = await ref.read(appModalServiceProvider).show(request);
```

## 3. 当前支持的弹窗总表

| 弹窗 | Channel / Type | Source | Presenter | Result |
| --- | --- | --- | --- | --- |
| 通用确认弹窗 | `AppModalType.confirm` | 调用方指定 | `ConfirmAppModalPresenter` | `ConfirmResult` |
| Player 金币解锁小弹窗 | `player.coin_unlock` / `coinUnlock` | `player` | `PlayerAppModalPresenter` | `CoinUnlockModalResult` |
| Player 充值/支付抽屉 | `player.recharge_unlock` / `recharge` | `player` | `PlayerAppModalPresenter` | `RechargeModalResult` |
| Auth 登录弹窗 | `auth.login` / `login` | `auth` / 触发来源 | `AuthAppModalPresenter` | `LoginModalResult` / `AuthLoginModalResult` |
| Store 购买确认 | `store.purchase_confirmation` / `storeConfirm` | `store` | `StoreAppModalPresenter` | `StorePurchaseModalResult` |
| Membership 购买确认 | `membership.purchase_confirmation` / `membershipPurchase` | `membership` | `MembershipAppModalPresenter` | `MembershipPurchaseModalResult` |

Presenter 注册入口：

```dart
lib/bootstrap/app_modal_registry_bootstrap.dart
```

当前注册：

- `ConfirmAppModalPresenter`
- `PlayerAppModalPresenter`
- `StoreAppModalPresenter`
- `MembershipAppModalPresenter`
- `AuthAppModalPresenter`

## 4. 通用确认弹窗

用途：

- 通用确认 / 取消。
- 简单阻塞式确认，不承载 feature 复杂业务。

调用：

```dart
final result = await ref.read(appModalServiceProvider).showConfirm(
  ConfirmModalRequest(
    requestId: ref.read(appModalControllerProvider).nextRequestId(),
    source: AppModalSource.system,
    title: 'Confirm',
    message: 'Continue?',
    confirmLabel: 'OK',
    cancelLabel: 'Cancel',
  ),
);

if (result.isConfirmed) {
  // Continue.
}
```

结果：

- `ConfirmResult.confirmed`
- `ConfirmResult.cancelled`
- `ConfirmResult.dismissed`

适合：

- 简单业务确认。

不适合：

- 支付、登录、权益、解锁等有复杂状态的弹窗。这类应使用 feature presenter。

## 5. Player 金币解锁小弹窗

用途：

- 锁定剧集金币足够时，展示小 Play 弹窗。
- 用户点击 Play 后，再由 `PlayerFeedEngine` 执行扣币解锁和播放。

入口：

```dart
PlayerUnlockModalCoordinator.showCoinUnlock(...)
```

Channel:

```dart
PlayerModalChannels.coinUnlock // player.coin_unlock
```

Payload:

```dart
PlayerCoinUnlockModalPayload(
  sessionKey: sessionKey,
  itemId: item.id,
  price: item.episode.requiredCoins,
)
```

Result:

- `CoinUnlockModalResult.completed()`：用户点击 Play。
- `CoinUnlockModalResult.cancelled()`：用户取消。
- `CoinUnlockModalResult.dismissed()`：用户关闭 / 外部关闭。

行为：

- `completed` 后调用 `PlayerFeedEngine.completeCoinUnlock(item)`。
- 成功后显示 toast：`playerUnlockSuccessful`。
- 自动弹出的 sheet 被用户关闭后，会记录 dismissed，避免同一 item 反复自动弹。
- 手动点击 `Unlock Now` 不受自动 dismissed 记录影响。

注意：

- 弹窗不直接扣币。
- 弹窗不直接播放。
- 弹窗不读取或修改播放器 session。

## 6. Player 充值/支付抽屉

用途：

- 金币不足时展示充值大抽屉。
- 会员剧非会员时展示会员购买入口。
- 充值抽屉内包含 payment confirmation 内页。

入口：

```dart
PlayerUnlockModalCoordinator.showRechargeUnlock(...)
```

Channel:

```dart
PlayerModalChannels.rechargeUnlock // player.recharge_unlock
```

Payload:

```dart
PlayerRechargeUnlockModalPayload(
  sessionKey: sessionKey,
  itemId: item.id,
  requiredCoins: item.episode.requiredCoins,
)
```

Result:

- `RechargeModalResult.completed()`：mock 支付成功。
- `RechargeModalResult.cancelled()`：用户取消。

行为：

- 弹窗打开前调用 `PlayerRechargeUnlockController.open(...)`。
- 用户选择金币包 / 会员包后，在抽屉内进入 payment confirmation。
- 金币包成功后：
  - `PlayerFeedEngine.grantRechargeSelection(...)`
  - `continueAfterRechargeSuccess(...)`
  - 回到金币解锁小弹窗，用户点 Play 后扣币播放。
- 会员包成功后：
  - 授予 mock membership
  - 直接播放当前会员集
  - toast：`playerMembershipActivated`
- 用户取消 / 关闭后：
  - `PlayerRechargeUnlockController.close()`
  - locked poster + Unlock Now 保留。

注意：

- 该弹窗使用 root modal host，避免 For You / bottom tab 遮挡。
- payment confirmation 目前属于充值抽屉内部状态，不是单独的 AppModal channel。

## 7. Auth 登录弹窗

用途：

- Profile 主动登录。
- 业务动作需要正式用户身份时提示登录。
- session expired 后由用户操作触发登录提示。

入口：

```dart
final result = await ref.read(authModalCoordinatorProvider).showLogin(context);
```

需要正式用户身份：

```dart
final result = await ref.read(authModalCoordinatorProvider).showLoginRequired(
  context,
  reason: AuthLoginRequiredReason.wallet,
);

if (result.isSuccess) {
  // Continue protected action.
}
```

session expired 提示：

```dart
await ref.read(authModalCoordinatorProvider).showSessionExpiredLogin(context);
```

Channel:

```dart
AuthModalChannels.login // auth.login
```

Payload:

```dart
AuthLoginModalPayload(
  intent: AuthLoginIntent.loginRequired,
  reason: AuthLoginRequiredReason.wallet,
  triggerSource: AppModalSource.wallet,
  message: '...',
)
```

Result:

Feature 层：

- `AuthLoginModalSuccess`
- `AuthLoginModalCancelled`
- `AuthLoginModalDismissed`
- `AuthLoginModalFailed`

Core 层：

- `LoginModalResult.success`
- `LoginModalResult.cancelled`
- `LoginModalResult.dismissed`
- `LoginModalResult.failed`

行为：

- 已登录用户会短路返回 success，不重复弹窗。
- 登录弹窗不直接写 token。
- 真实阶段登录成功后应通过 AuthController / AuthRepository / AuthTokenStore 边界更新 session。
- refresh failed 不自动弹登录；用户操作或 `showLoginRequired` 才弹。

## 8. Store 购买确认弹窗

用途：

- Store 金币包 / VIP 商品购买前确认。

入口：

```dart
await ref
    .read(storeModalCoordinatorProvider)
    .presentPurchaseConfirmation(context);
```

Channel:

```dart
StoreModalChannels.purchaseConfirmation // store.purchase_confirmation
```

Payload:

```dart
StorePurchaseModalPayload(packageId: package.id)
```

Result:

- `StorePurchaseModalResult.completed()`
- `StorePurchaseModalResult.cancelled()`
- `StorePurchaseModalResult.dismissed()`

行为：

- 弹窗内容复用 `StoreConfirmationSheet`。
- confirm 后继续走 `StoreController` 的 mock purchase。
- cancel / dismiss 不触发购买。
- Store restore 当前不是阻塞确认弹窗，继续走 toast。

注意：

- Store 弹窗不直接写权益。
- mock purchase success 由 StoreController 写入 `EntitlementController`。

## 9. Membership 购买确认弹窗

用途：

- Membership 页面点击套餐卡后的购买确认。

入口：

```dart
await ref
    .read(membershipModalCoordinatorProvider)
    .presentPurchaseConfirmation(context);
```

Channel:

```dart
MembershipModalChannels.purchaseConfirmation // membership.purchase_confirmation
```

Payload:

```dart
MembershipPurchaseModalPayload(planId: plan.id)
```

Result:

- `MembershipPurchaseModalResult.completed()`
- `MembershipPurchaseModalResult.cancelled()`
- `MembershipPurchaseModalResult.dismissed()`

行为：

- 弹窗内容复用 `MembershipConfirmationSheet`。
- confirm 后继续走 `MembershipController` 的 mock purchase。
- success 后写入 shared entitlement membership。
- cancel / dismiss 不触发购买。

## 10. Queue / Priority / Dismiss Policy

Priority:

```dart
enum AppModalPriority { low, normal, high, critical }
```

队列规则：

- 当前 modal 展示中时，新请求进入 pending queue。
- pending 按 priority 降序排序。
- 同 priority 按 createdAt / enqueue order FIFO。
- 默认不抢占当前 modal。
- pending 最大长度默认 5。
- 超过长度返回 `AppModalRejectedResult(queueFull)`。

Dismiss policy:

| Policy | 点击遮罩 | 返回键 | 说明 |
| --- | --- | --- | --- |
| `standard` | 可关闭 | 可关闭 | 默认业务弹窗 |
| `blocking` | 不可关闭 | 可关闭 | 阻塞式，但允许系统返回 |
| `nonDismissible` | 不可关闭 | 不可关闭 | 必须明确 action 或 API 关闭 |
| `critical` | 不可关闭 | 不可关闭 | 强更 / 风控预留 |

默认业务弹窗目前仍使用 `standard`，不改变既有关闭体验。

## 11. Cleanup 与关闭

按来源关闭：

```dart
ref.read(appModalServiceProvider).dismissForSource(AppModalSource.player);
```

按 requestId 关闭：

```dart
ref.read(appModalServiceProvider).dismissByRequestId(requestId);
```

关闭全部阻塞式业务弹窗：

```dart
ref.read(appModalServiceProvider).dismissAllBlockingBusinessModals();
```

session cleanup 中会关闭来源：

- `player`
- `store`
- `membership`
- `auth`

不会主动关闭 toast。toast 会自然消失。

## 12. Diagnostics

`AppModalObserver` 预留诊断事件：

- `queued`
- `presented`
- `completed`
- `dismissed`
- `cancelled`
- `failedToPresent`
- `queueRejected`
- `replaced`（预留）

字段：

- requestId
- source
- type
- channel
- priority
- resultKind
- elapsedMs
- rejectReason

默认 observer 为 no-op。测试可使用 `RecordingAppModalObserver`。

## 13. 如何新增一个业务弹窗

推荐步骤：

1. 在 feature 层定义 channel：

   ```dart
   abstract final class ExampleModalChannels {
     static const confirmSomething = 'example.confirm_something';
   }
   ```

2. 定义 payload / result：

   ```dart
   class ExampleModalPayload {
     const ExampleModalPayload({required this.id});
     final String id;
   }
   ```

3. 写 feature presenter：

   ```dart
   class ExampleAppModalPresenter implements AppModalPresenter {
     @override
     bool canPresent(AppModalRequest request) {
       return request is FeatureAppModalRequest &&
           request.channel == ExampleModalChannels.confirmSomething;
     }

     @override
     Future<AppModalResult> present({
       required BuildContext context,
       required AppModalRequest request,
     }) {
       // Build root-hosted modal content.
     }
   }
   ```

4. 在 `lib/bootstrap/app_modal_registry_bootstrap.dart` 注册 presenter。

5. 在 application 层写 coordinator，页面只调用 coordinator。

6. 补测试：

   - presenter registry
   - coordinator result
   - cancel/dismiss
   - architecture boundary

约束：

- `core/modal` 不能 import feature。
- feature 页面不要直接散落 root navigator patch。
- 阻塞式业务弹窗不要绕过 `AppModalService`。
- 瞬态提示用 `AppToastService`。

## 14. 当前保留的本地弹窗

| 位置 | 原因 |
| --- | --- |
| `PlayerPage` detail / share / speed | 页面局部 UI，不跨 feature，不需要全局队列 |
| `AccountPage` delete confirmation | 账号删除确认后续真实账号体系再决定是否迁移 |
| Store restore toast | 非阻塞提示，使用 `AppToastService` |
| Wallet auto unlock switch | 页面内设置，不是弹窗 |

如未来这些流程变成跨页面阻塞式业务流程，应迁移到 AppModal。

