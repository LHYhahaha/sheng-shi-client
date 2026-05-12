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
- HTTP status 错误
- Dio 错误映射
- 常见服务端 envelope 解包

当前支持的成功 envelope：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

如果响应没有 `code/data`，则直接把 body 交给 `decoder`。

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

- token 注入 interceptor
- 401 refresh token 队列
- request id / device id / app version header
- 网络日志脱敏
- Sentry breadcrumb
- API mock switch
