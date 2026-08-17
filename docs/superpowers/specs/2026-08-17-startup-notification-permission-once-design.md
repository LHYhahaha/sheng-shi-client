# 单次启动通知权限申请设计

## 目标

应用一次安装周期内，仅在首次启动时尝试申请 Android 通知权限。无论系统最终授权、拒绝、未确定，或请求发生异常，后续启动均不再次申请。

## 范围与约束

- 只影响 Android 的启动通知权限入口；Web 和非 Android 平台维持不申请的现状。
- 使用 `SharedPreferences` 保存安装级状态；卸载会清除该状态，重装后可再次尝试。
- 以发起请求前落库为准，保证请求中断、异常或系统不展示授权框时也不会重试。
- 当前工作区已有的未提交改动不属于此功能，实施时不得修改或回退。

## 数据与状态

新增安装级持久化记录，保存两类信息：

1. `requestAttempted`：是否已执行过首次启动申请流程。
2. `initialResult`：首次申请的标准化结果，取值 `granted`、`denied` 或 `not_determined`。

状态映射如下：

| 系统结果 | 后端 `enabled` | 埋点 `permission_status` |
| --- | --- | --- |
| `granted` 或 `provisional` | `true` | `granted` |
| `denied`、`permanentlyDenied`、`restricted` | `false` | `denied` |
| 无有效结果、请求异常或其他未分类状态 | `false` | `not_determined` |

## 申请与上报流程

1. App 首帧后调用启动申请器。
2. 申请器读取 `requestAttempted`；已存在时直接结束。
3. 未存在时先保存 `requestAttempted=true`，随后请求系统通知权限；将映射后的 `initialResult` 持久化。
4. 若认证尚未完成，结果保留在本地。
5. 认证完成取得 `showId` 后，权限同步器优先消费未上报的 `initialResult`：请求后端 `/api/activity/task/action/report`，并记录 `push_permission_result` 埋点。
6. `initialResult` 的后端上报和埋点各自成功后分别标记完成，失败保留以供下一次账号同步重试。
7. 首次结果上报完毕后，同步器继续使用现有的系统状态检查和“状态变更才上报”的行为；首次 `not_determined` 不会被随后的普通检查改写为 `denied`。

## 组件边界

- `StartupNotificationPermissionRequester` 仅负责一次性请求、标准化并保存首次结果，不依赖账号或网络。
- `StartupNotificationPermissionReporter` 仅负责有账号后的后端同步和埋点，读取并消费申请器保存的待上报结果。
- App 与认证流程维持现有调用点；认证完成触发的 `syncForAccount(showId)` 负责延迟交付。

## 测试

- 申请器：首次申请、已经标记后跳过、授权、拒绝、未知状态与异常都写入正确的安装级结果。
- 同步器：待上报的 `granted`、`denied`、`not_determined` 分别生成正确后端值及埋点值；成功后不会重复上报；失败会在后续同步重试。
- 保留现有普通权限状态同步的测试，确保首次结果消费完成后原行为不回归。
