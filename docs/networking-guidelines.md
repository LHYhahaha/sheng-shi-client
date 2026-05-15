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
  `ApiClient`。当前 token 仍是 mock/default，真实 token storage 和 refresh queue
  后续再接。

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

接口域名确定后，只改 `AppConfig.forEnvironment`。

## 后续待补

等登录模块接入后，再增加：

- 真实 token storage
- 401 refresh token 队列
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

后续接真实登录时，应该替换 `apiRequestContextProvider` 的 token 来源，并增加统一 refresh
queue。不要让页面、controller 或 feature repository 自己保存 access token；否则 401 刷新、
logout 清理和并发请求会变得不可控。

logout / delete account 成功后，还需要统一清理 secure token、各 feature cache 和播放器
session/window。Phase E skeleton 只定义远程契约，不做本地全局清理，避免在 mock 阶段误伤
已经验收的页面状态。
