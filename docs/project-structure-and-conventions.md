# 项目结构与开发规范

本文档用于说明当前 Flutter 客户端项目的目录结构、代码放置规则和协作规范。更完整的技术选型和里程碑计划请参考：

- [技术架构](technical-architecture.md)
- [多语言与首页数据架构规范](localization-and-home-data-architecture.md)
- [开发排期](development-schedule.md)

## 1. 项目概览

本项目是短剧客户端，当前技术栈为 Flutter + Riverpod + GoRouter，播放器底座使用 `media_kit`。项目采用 feature-first 的组织方式：业务功能按 `features/` 拆分，跨功能基础能力放到 `core/`，可复用 UI 和设计 token 放到 `shared/`，应用入口、路由、主题和壳层放到 `app/`。

当前已具备：

- Flutter 工程脚手架。
- `go_router` 路由和底部四 Tab 壳层。
- 首页 mock 分类、瀑布流列表、分页、加载、空态、错误和重试状态。
- 播放页占位。
- 基础主题 token、公共组件和本地多语言能力。

## 2. 顶层目录

```text
client/
  android/                 Android 原生工程与 Gradle 配置
  assets/                  静态资源，目前主要是 mock 图片
  docs/                    项目文档
  ios/                     iOS 原生工程与 Xcode 配置
  lib/                     Flutter 应用源码
  test/                    Flutter widget/unit 测试
  analysis_options.yaml    Dart/Flutter 静态检查配置
  pubspec.yaml             依赖、资源和包元信息
  README.md                项目入口说明
```

放置规则：

- Flutter 业务代码统一放在 `lib/`。
- 平台相关配置放在 `android/` 和 `ios/`，不要把业务逻辑写进原生目录；除非接入支付、推送、播放器或渠道 SDK 需要 Platform Channel。
- 静态资源放在 `assets/`，并在 `pubspec.yaml` 的 `flutter.assets` 下登记。
- 设计、架构、流程、约定类文档放在 `docs/`。
- 测试放在 `test/`，测试文件名建议跟被测模块对应。

## 3. lib 目录结构

```text
lib/
  main.dart
  app/
    app.dart
    router/
    shell/
    theme/
    lifecycle/
  core/
    analytics/
    config/
    error/
    logging/
    network/
    state/
    storage/
    utils/
  features/
    auth/
    drama/
    home/
    membership/
    my_list/
    notification/
    player/
    profile/
    search/
    settings/
    store/
    wallet/
  l10n/
  shared/
    extensions/
    models/
    theme/
    widgets/
```

### 3.1 `main.dart`

职责：

- 初始化 Flutter 绑定。
- 初始化全局运行时依赖，例如 `MediaKit.ensureInitialized()`。
- 包裹 `ProviderScope` 并启动 `DramaClientApp`。

规则：

- 只放全局启动代码，不放业务判断和页面逻辑。
- 后续接入 Sentry、Firebase、崩溃收集等全局初始化时，也应保持这里简洁，把复杂配置下沉到独立服务。

### 3.2 `app/`

`app/` 放应用级装配代码，不放具体业务。

当前职责：

- `app.dart`：`MaterialApp.router`、主题、多语言 delegate、路由配置。
- `router/`：路由路径、路由名称和 `GoRouter` 配置。
- `shell/`：应用主壳层，目前是底部四 Tab 的 `StatefulShellRoute`。
- `theme/`：Material `ThemeData` 配置。
- `lifecycle/`：预留给应用生命周期协调逻辑。

放置规则：

- 新增页面路由时，路径常量放 `app/router/route_paths.dart`，名称常量放 `app/router/route_names.dart`，路由注册放 `app/router/app_router.dart`。
- 底部 Tab 的结构调整放 `app/shell/` 和 `shared/widgets/navigation/`。
- 全局主题配置放 `app/theme/app_theme.dart`，具体颜色、间距、圆角 token 放 `shared/theme/`。
- 业务页面不要直接放在 `app/`，应放到对应 `features/<feature>/presentation/`。

### 3.3 `core/`

`core/` 放跨业务、非 UI 或弱 UI 的基础设施能力。它可以被多个 feature 使用，但不要反向依赖具体 feature。

当前和规划职责：

- `analytics/`：埋点事件定义与上报封装，例如 `AnalyticsEvent`。
- `config/`：环境配置，例如 `AppConfig`、`AppEnvironment`。
- `error/`：统一错误类型、错误转换、错误展示映射。
- `logging/`：日志封装。
- `network/`：网络客户端、拦截器、API 基础配置，例如 `ApiClient`。
- `state/`：通用状态模型，例如 `LoadableState`。
- `storage/`：本地存储抽象，如 secure storage、shared preferences、drift database。
- `utils/`：纯工具函数。使用前先判断是否真的跨模块复用，避免变成杂物箱。

放置规则：

- `core/` 不应该 import `features/`。
- 业务实体和业务仓库接口优先放在 feature 内，不要因为“可能复用”提前放进 `core/`。
- 网络、存储、埋点、配置等基础能力可以放 `core/`，但具体业务 API 调用应放在对应 feature 的 `data/`。

### 3.4 `features/`

`features/` 是业务模块目录。每个功能独立组织自己的 domain、data、application、presentation。

推荐结构：

```text
features/<feature>/
  domain/          业务实体、值对象、仓库接口、业务规则
  data/            DTO、数据源、仓库实现、provider 装配
  application/     状态机、用例编排、controller
  presentation/
    pages/         页面
    widgets/       只服务于该 feature 的组件
    controllers/   UI 状态控制器，如需要
```

使用原则：

- 小功能可以先只建需要的层，不必为了形式创建空文件。
- 当出现真实 API、缓存、复杂状态机或可测试业务规则时，再补齐 `data/`、`application/`。
- 只被一个功能使用的组件放在该 feature 的 `presentation/widgets/`。
- 多个功能都会用的组件再上提到 `shared/widgets/`。

当前 feature 状态：

| Feature | 当前状态 | 主要位置 |
|---|---|---|
| `home` | 已有首页页面、分类 tab、瀑布流、分页状态 | `features/home/presentation/pages/home_page.dart` |
| `drama` | 已有短剧实体、仓库接口、mock repository 和 provider | `features/drama/` |
| `player` | 已有播放页占位、播放领域模型和 session controller 骨架 | `features/player/` |
| `my_list` | 预留模块，当前主路由仍是占位页 | `features/my_list/` |
| `profile` | 预留模块，当前主路由仍是占位页 | `features/profile/` |
| `store` / `wallet` / `membership` | 预留商业化模块，当前为占位入口 | `features/store/`, `features/wallet/`, `features/membership/` |
| `auth` / `search` / `notification` / `settings` | 预留模块 | 对应 feature 目录 |

### 3.5 `l10n/`

当前项目使用手写的 `AppLocalizations`，支持英文和中文：

```dart
context.l10n.navHome
context.l10n.retry
```

应用默认语言为英文。当前在 `MaterialApp.router` 中固定 `locale: Locale('en')`，中文文案仅作为后续语言切换能力的资源储备。

规则：

- 本地 UI 文案统一放 `lib/l10n/app_localizations.dart`。
- 新增本地文案时必须同时补英文和中文。
- Widget 中不要散落通用 UI 文案。
- 服务端内容不进入本地多语言表，例如短剧标题、分类标题、标签、播放量文案。
- 如果后续切换到 Flutter 官方 ARB 工作流，应先迁移现有 key，再移除手写实现。

### 3.6 `shared/`

`shared/` 放可跨 feature 复用的 UI、模型、扩展和设计 token。

当前职责：

- `shared/theme/`：颜色、间距、圆角 token。
- `shared/widgets/`：通用页面框架、按钮、空态、分段 tab、底部弹窗框架等。
- `shared/widgets/navigation/`：底部导航组件。
- `shared/models/`：跨 feature 的通用模型。
- `shared/extensions/`：通用扩展方法。

放置规则：

- 优先在 feature 内实现组件；当第二个 feature 也需要时，再抽到 `shared/widgets/`。
- `shared/` 组件不能依赖具体业务仓库或具体 feature 页面。
- 设计 token 尽量引用 `AppColors`、`AppSpacing`、`AppRadii`，不要在业务 UI 中重复散落颜色和尺寸。

## 4. 路由规范

当前使用 `go_router` 和 `StatefulShellRoute.indexedStack`。

主 Tab：

- Home：`/`
- For you：`/for-you`
- My list：`/my-list`
- Profile：`/profile`

独立页面：

- Player：`/player/:dramaId/:episodeId`
- Store：`/store`
- Wallet：`/wallet`
- Membership：`/membership`
- Language：`/language`
- Transaction history：`/wallet/transaction-history`
- Consumption history：`/wallet/consumption-history`
- Record coins：`/wallet/record-coins`

规则：

- 路由 path 只在 `RoutePaths` 中定义。
- 路由 name 只在 `RouteNames` 中定义。
- 跳转时优先使用 `RoutePaths` 提供的路径或构造方法，例如 `RoutePaths.playerLocation(...)`。
- 底部 Tab 页面保持在 shell branch 内；播放页、钱包、会员等全屏/二级页面放在 shell 外。
- 从路由读取参数后，应尽快转成页面需要的强语义字段，避免在页面深处反复解析 `GoRouterState`。

## 5. 状态管理规范

当前使用 `flutter_riverpod`：

- 全局入口由 `ProviderScope` 包裹。
- 依赖装配使用 provider，例如 `dramaRepositoryProvider`。
- 页面可以使用 `ConsumerWidget` 或 `ConsumerStatefulWidget`。

规则：

- 仓库接口放 `domain/`，具体实现和 provider 装配放 `data/`。
- UI 只依赖 provider 或 controller，不直接 new 远程数据源。
- 页面内简单状态可以先用 `StatefulWidget`；跨页面、可复用、可测试或异步复杂状态应沉到 provider/controller。
- 异步请求需要处理加载、空态、失败、重试和过期请求覆盖问题。
- 通用异步状态可以使用 `core/state/loadable_state.dart`。

## 6. 数据层规范

当前首页只依赖 `DramaRepository`：

```dart
abstract interface class DramaRepository {
  Future<List<DramaCategory>> listHomeCategories();

  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  });
}
```

规则：

- UI 不直接创建业务 mock 数据。
- Mock 数据统一放对应 feature 的 `data/`，例如 `MockDramaRepository`。
- 真实接口接入时，新建 `Remote<Feature>Repository` 或 data source，实现同一个 domain repository 接口。
- 分页优先使用 `nextPageToken` / cursor，不在 UI 层假设 page number。
- 客户端不可信任本地支付权益，金币、会员、剧集解锁状态以后端为准。
- API 基础配置使用 `core/network/ApiClient` 和 `core/config/AppConfig`。

## 7. UI 与主题规范

当前产品基调是深色短剧应用：

- 背景：`AppColors.black`
- 主色：`AppColors.primary`
- 会员/权益强调：`AppColors.gold`
- 文字：`AppColors.textPrimary`、`textSecondary`、`textMuted`
- 圆角：`AppRadii`
- 间距：`AppSpacing`

规则：

- 优先使用已有 `AppColors`、`AppSpacing`、`AppRadii`。
- 新增通用颜色或尺寸前，先确认是否已有 token 可复用。
- 通用按钮、空态、弹窗、页面框架优先使用 `shared/widgets/`。
- 只服务单个页面的小组件可以先写成私有 widget；变大或复用后再拆到 `presentation/widgets/`。
- 页面文件负责状态编排和布局骨架，复杂卡片、tab、footer 等应逐步拆出。
- 小屏适配要优先保证文字不溢出、不遮挡、不因为动态内容导致布局跳动。

## 8. 资源规范

当前资源目录：

```text
assets/
  images/
    home/
      drama_cover.png
      drama_cover_figma.png
      vip_crown_figma.png
  navigation/
    bottom_tab/
      home_selected.png
      home_unselected.png
      ...
```

规则：

- 正式图片按业务或页面放在 `assets/images/`。
- 底部导航图标统一放 `assets/navigation/bottom_tab/`，选中态和未选中态分别导出独立图片。
- 正式图片建议按用途继续拆分，例如 `assets/images/`、`assets/icons/`。
- 新增资源后必须在 `pubspec.yaml` 中登记。
- 业务模型中如果同时支持本地 mock 图和远程图，建议引入明确字段或 value object，避免把 `coverAssetPath` 直接沿用到远程接口。

## 9. 测试与质量规范

当前静态检查继承 `package:flutter_lints/flutter.yaml`。

常用命令：

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run
```

规则：

- 项目 Flutter 版本锁定为 stable `3.41.9`，优先使用 `fvm flutter ...`。
- 提交前至少运行 `fvm flutter analyze` 和 `fvm flutter test`。
- UI 改动至少覆盖关键 widget 测试或手动 smoke test。
- 数据层和状态机逻辑应补 unit test。
- 依赖新增需说明用途，避免提前加入暂时不用的包。

## 10. 新增功能建议流程

以新增一个业务模块为例：

1. 在 `features/<feature>/` 下建立实际需要的目录。
2. 在 `domain/` 定义实体和 repository 接口。
3. 在 `data/` 先提供 mock repository，后续再接 remote repository。
4. 在 `presentation/pages/` 实现页面。
5. 如果有复杂页面状态，在 `application/` 或 `presentation/controllers/` 建 controller/provider。
6. 在 `app/router/route_paths.dart` 和 `route_names.dart` 增加路由常量。
7. 在 `app/router/app_router.dart` 注册页面。
8. 本地 UI 文案补到 `AppLocalizations` 的英文和中文。
9. 需要复用的 UI 再抽到 `shared/widgets/`。
10. 补测试并运行 analyze/test。

## 11. 命名规范

- Dart 文件使用 `snake_case.dart`。
- Widget、类、enum 使用 `PascalCase`。
- 私有 widget 或私有 helper 使用 `_PascalCase` / `_camelCase`。
- Provider 命名使用清晰业务语义，例如 `dramaRepositoryProvider`。
- 路由路径用名词或短横线，例如 `/my-list`。
- 业务 id 字段保持后端语义，例如 `dramaId`、`episodeId`、`categoryId`。

## 12. 当前重点约束

- 首页分类、短剧标题、标签等内容视为服务端内容，不进入客户端本地多语言。
- 本地通用 UI 文案必须通过 `context.l10n` 获取。
- 首页数据必须通过 `DramaRepository`，不要在 UI 层硬编码业务列表。
- 分页状态要处理加载更多、无更多、失败重试。
- 播放器相关资源由 player feature 自己管理，后续接入 `media_kit` 时要明确创建和释放 `Player` / `VideoController`。
- 支付和权益最终以后端校验为准，客户端只驱动 UI 状态和发起验单。
