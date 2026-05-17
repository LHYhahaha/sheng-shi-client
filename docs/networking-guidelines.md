# 网络层规范

## 目标

接口未最终确定前，客户端先固定网络边界：

- UI 不直接使用 `Dio`。
- Repository 不向外抛 `DioException`。
- 所有网络错误统一转换为 `ApiException`。
- 服务端 envelope 可以调整，但解包逻辑只集中在 `ApiClient`。

## 分层

```text
presentation
  -> controller / state
    -> domain repository interface
      -> data repository impl
        -> remote data source
          -> ApiClient
```

允许：

- `remote_data_source.dart` 使用 `ApiClient`
- `repository_impl.dart` 捕获或透传 `ApiException`
- UI 根据 `ApiException.code` 展示重试、登录失效、空态等

不允许：

- UI 或 widget 直接 import `dio`
- Repository 向 UI 抛出 `DioException`
- 每个接口自己解析 HTTP status
- 每个接口自己处理 token 过期

## ApiClient

统一使用：

```dart
final result = await apiClient.get<MyDto>(
  '/path',
  queryParameters: {'pageToken': pageToken},
  decoder: MyDto.fromJsonObject,
);
```

`ApiClient` 负责：

- baseUrl
- timeout
- JSON response type
- 基础请求 header：`Device-Id`、`Lang`、`Platform`、`App-Version`
- `ApiAuthPolicy` 控制是否注入 `Authorization`
- HTTP status 错误
- Dio 错误映射
- 服务端 envelope 解包

当前成功 envelope：

```json
{
  "code": 0,
  "message": "success",
  "data": null
}
```

`code: 0` 是唯一成功码。`code: 200` 不是业务成功码，会作为业务失败抛出
`ApiException`，并透传 `businessCode`。

如果响应没有 `code/data`，则直接把 body 交给 `decoder`，用于兼容少量非标准
调试接口；正式业务接口应使用统一 envelope。

- 所有接口都必须带 `Device-Id`、`Lang`、`Platform`、`App-Version`。
- 登录、第三方登录、刷新 token 不带 `Authorization`。
- 登录后的业务接口额外带 `Authorization: Bearer <token>`。
- 业务 envelope 中 `code: 0` 是唯一成功码，失败返回 4 位业务错误码。
- Network Contract Phase B 已把这些 header、auth policy、business code 映射落到
  `ApiClient`。
- Phase F 已把 `ApiRequestContext` 接到统一 provider：`Device-Id` / `App-Version`
  当前来自可替换 provider 和 dart-define fallback，`Lang` 来自当前 locale controller，
  `Platform` 自动识别，`accessToken` 来自 `AuthTokenStore` snapshot。
- Post-RC Track A1–A3 已落地：`AuthTokenStore` + storage 抽象（默认 in-memory）、
  `ApiAuthPolicy.required` 空 token 客户端 fail-fast、`ApiClient` 401 单飞 refresh + 重试一次。
- A1.5 / A7：游客 session 模型与 cleanup → `GuestSessionBootstrap`（stub，无网络）。
  仍 defer：生产 guest bootstrap API、account link 登录、生产 secure storage、真实 refresh。

## 异常类型

统一异常是 `ApiException`：

```dart
catch (error) {
  if (error is ApiException && error.canRetry) {
    // show retry
  }
}
```

错误码：

- `sessionRequired`（**客户端本地**：`required` 且无 access token，未发 HTTP）
- `cancelled`
- `timeout`
- `network`
- `unauthorized`
- `forbidden`
- `notFound`
- `conflict`
- `validation`
- `server`
- `badResponse`
- `unknown`

UI 层一般只关心：

- `unauthorized`：进入登录/刷新 token
- `network`、`timeout`、`server`：显示重试
- `validation`：展示业务提示
- 其他：通用失败提示

`ApiException.businessCode` 只用于承载服务端业务码，例如 `1001` 参数错误、
`1002` 请求频繁、`1003` 验签失败、`1004` 系统异常、`2xxx` 用户域、`3xxx`
内容域、`4xxx` 金币/任务/福利域。网络层不根据这些码展示业务 UI。

## 分页约定

UI 和 repository 层统一使用 cursor/token：

```dart
class ApiPage<T> {
  final List<T> items;
  final String? nextPageToken;
}
```

不在 UI 层假设后端是 page number、offset 还是 cursor。

## 多环境

baseUrl 来自 `AppConfig.current`：

```bash
--dart-define=APP_ENV=dev
--dart-define=APP_ENV=staging
--dart-define=APP_ENV=prod
```

如需临时联调指定 host，可用：

```bash
--dart-define=API_BASE_URL=https://staging-api.example.com
```

`API_BASE_URL` 优先级高于 `APP_ENV` 的默认域名。接口域名确定后，优先只改
`AppConfig.forEnvironment`，不要在 feature repository 或页面里写死 baseUrl。

请求上下文可替换项：

```bash
--dart-define=API_DEVICE_ID=local-test-device
--dart-define=APP_VERSION=1.2.3
```

这些 fallback 只用于 skeleton 和联调便利。真实阶段应接持久化 install/device id 和
package info，仍通过 provider 注入，不允许各 feature 自己拼 header。

## 后续待补

- 生产环境默认启用 `FlutterSecureAuthTokenStorage`（实现已存在，provider 仍 in-memory）
- `authRefreshExecutorProvider` 接真实 `POST /auth/refresh`（当前默认 stub 返回 null）
- A7：logout/refresh 失败后 entitlement、wallet、my list、player session 等 cleanup hook
- request id header
- 网络日志脱敏
- Sentry breadcrumb
- API mock switch

## Auth / Session / Token Skeleton

API Skeleton Phase E 已补 Auth / Profile 远程骨架，但仍不做真实 token 生命周期：

- `AuthRemoteDataSource` 只负责登录、OAuth、refresh、session、logout、delete account 的远程调用。
- `RemoteAuthRepository` 输出现有 `AuthSession`，不会把 `accessToken` 暴露给 UI。
- `AuthTokenDto` 只存在 data 层；真实 token storage 和 `ApiRequestContext.accessToken` 注入后续单独实现。
- 登录、第三方登录、refresh 必须继续使用 `ApiAuthPolicy.none`。
- session、logout、delete account、profile 按登录后业务接口处理，使用 `ApiAuthPolicy.required`。
- `GET /auth/session` 当前被定义为“用已有 token 恢复/校验 session”的接口，因此使用
  `ApiAuthPolicy.required`。如果后续服务端需要无 token 的游客 bootstrap，应新增或明确
  public bootstrap 语义，而不是让同一个接口同时承担两种策略。

Post-RC Track A1–A3 已新增/扩展 `AuthTokenStore`、`AuthRefreshCoordinator`、
`ApiSessionAuthHandler`、`SessionCleanupCoordinator`：

- `AuthTokenStore` 委托 `AuthTokenStorage`（默认 `InMemoryAuthTokenStorage`）；UI 不持有
  access/refresh token。可选 `FlutterSecureAuthTokenStorage` 通过 provider 切换，**未改默认**。
- `ApiAuthPolicy.required` 且无 access token：`ApiClient` 拦截器 **fail-fast**，抛
  `ApiErrorCode.sessionRequired`，不伪造 HTTP 401。
- `ApiAuthPolicy.none`：不带 `Authorization`（login/oauth/refresh）。
- `POST /auth/refresh`：`none` + `Options(extra: {apiSkipAuthRefreshExtraKey: true})`，避免
  refresh 请求自身 401 时递归 refresh。
- HTTP 401 + `required`：`ApiSessionAuthHandler` → `AuthRefreshCoordinator` 单飞 refresh →
  成功则原请求 **重试 1 次**；失败则 `SessionCleanupCoordinator` 清 token 并调用已注册 hook。
- `authRefreshExecutorProvider` 默认 stub（返回 null），测试可注入 fake executor；**未接真实服务端**。

约束（仍有效）：

- feature presentation/controller **不得**直接 import token storage 实现或调用 refresh coordinator；
  401 恢复只经 `ApiClient`。
- refresh 失败后 coordinator 必须释放 in-flight，避免永久挡住后续 401。
- A7 已接入 feature cleanup hook；cleanup 后调用 `GuestSessionBootstrap`（stub）。
- Toast/Modal 关闭策略仍 defer。

### ApiAuthPolicy 阶段性语义与未来扩展

**当前 enum（不变）：** `none` | `required`

| 策略 | 当前行为 |
| --- | --- |
| `none` | 不带 `Authorization`。用于 guest bootstrap、login/account link、refresh。 |
| `required` | 必须有 **任意有效 session access token**（游客或正式均可）。无 token → `sessionRequired`，不发 HTTP。 |

**不等于**「必须正式登录用户」。游客 bootstrap 后拿到的 guest access token 同样满足 `required`。

**未来可能扩展（文档先行，接 API 时再改 enum + 全量测试）：**

| 未来策略 | 含义 |
| --- | --- |
| `none` | 完全公开 |
| `guestOrUser` | 游客或正式 token 均可（与当前 `required` 接近） |
| `userRequired` | 必须正式账号 token（钱包、片单、会员订单等） |
| refresh 专用 | 继续 `none` + `apiSkipAuthRefreshExtraKey`，避免 401 递归 refresh |
