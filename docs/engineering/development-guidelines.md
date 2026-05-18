# 开发约束与 AI 协作规范

本文档是后续开发人员和 AI 编码助手必须优先参考的工程规范。它补充 [项目结构与开发规范](project-structure-and-conventions.md)，重点说明哪些事情可以做、应该怎么做，以及哪些事情不要做。

## 1. 基本原则

### 1.1 先看现状，再动代码

任何开发者或 AI 在改代码前必须先阅读相关现有实现：

- 页面改动先看对应 `features/<feature>/presentation/`。
- 数据改动先看 `domain/` 的实体和 repository 接口。
- 路由改动先看 `app/router/`。
- 主题和公共 UI 改动先看 `shared/theme/` 和 `shared/widgets/`。
- Figma 还原改动先看资源目录、现有组件和设计 token。

禁止：

- 不看现有结构就新建平行目录。
- 为了短期实现复制一套已有组件。
- 在不知道业务边界时把逻辑塞进 `main.dart`、`app/` 或 `shared/`。

### 1.2 业务优先放 feature

业务代码默认放在 `lib/features/<feature>/`。只有真正跨多个 feature 使用的能力，才放到 `core/` 或 `shared/`。

判断标准：

- 业务实体、业务状态、业务仓库接口：放 `features/<feature>/domain/`。
- 远程接口、本地数据源、repository 实现：放 `features/<feature>/data/`。
- 页面、页面私有组件：放 `features/<feature>/presentation/`。
- 状态机、用例编排、播放器 session、支付流程 controller：放 `features/<feature>/application/`。
- 网络、配置、日志、存储、错误模型、埋点基础设施：放 `core/`。
- 通用按钮、弹窗、空态、导航、设计 token：放 `shared/`。

## 2. 目录与命名约束

### 2.1 新增目录

新增目录前先确认是否已有同类目录。推荐结构：

```text
features/<feature>/
  domain/
  data/
  application/
  presentation/
    pages/
    widgets/
```

不要创建这些目录：

- `lib/pages`
- `lib/screens`
- `lib/components`
- `lib/services`
- `lib/common`
- `lib/helpers`

除非项目整体重构并同步更新文档。

### 2.2 命名规则

- Dart 文件：`snake_case.dart`。
- 类、Widget、enum：`PascalCase`。
- 私有类和私有方法：`_PascalCase` / `_camelCase`。
- Provider：业务名 + `Provider`，例如 `dramaRepositoryProvider`。
- 页面：`XxxPage`。
- 页面内私有组件：`_XxxCard`、`_XxxHeader`。
- 路由路径：小写短横线，例如 `/my-list`。
- 业务 id：使用明确后缀，例如 `dramaId`、`episodeId`、`categoryId`。

## 3. UI 与 Figma 还原规范

### 3.1 Figma 是视觉依据

涉及视觉还原时，必须优先参考 Figma：

- 颜色。
- 字号、字重、行高。
- 间距。
- 圆角。
- 图片比例。
- 图标选中和未选中态。
- 底部导航高度、图标尺寸、文字位置。

如果当前代码和 Figma 不一致，应先判断：

- 是代码旧了，需要改代码。
- 是 Figma 未更新，需要和设计确认。
- 是当前资源还没切图，需要先保留 fallback。

### 3.2 不要随意改变视觉结构

性能优化不能牺牲设计结构，除非明确得到确认。

例如首页：

- 当前设计是瀑布流，就不要为了性能直接改成固定高度普通 grid。
- tag 自适应高度、卡片文字高度、封面比例要保持设计稿效果。
- 如果要优化滚动性能，优先做图片降采样、减少 rebuild、拆组件、减少阴影/模糊，而不是改变布局形态。

### 3.3 颜色管理

全局颜色放在：

```text
lib/shared/theme/app_colors.dart
```

规则：

- 常用颜色必须沉淀到 `AppColors`。
- 页面内临时颜色只能用于非常局部且不复用的视觉元素。
- 底部导航、背景、卡片、文字色应优先使用 token。
- 从 Figma 新取颜色时，应补充颜色用途说明，避免同色不同名、同名不同色。

禁止：

- 在多个页面重复写同一个十六进制颜色。
- 用“看起来差不多”的颜色替代 Figma 颜色。
- 为了适配某个页面随意改全局 token，导致其他页面变色。

### 3.4 间距、圆角和尺寸

全局 token：

```text
lib/shared/theme/app_spacing.dart
lib/shared/theme/app_radii.dart
```

规则：

- 通用间距优先使用 `AppSpacing`。
- 通用圆角优先使用 `AppRadii`。
- Figma 中有明确尺寸的关键组件可以保留具体数值，但要避免到处散落无法解释的 magic number。
- 底部导航、播放器控制区、充值卡片等核心组件的高度和间距应稳定，不要随内容动态跳动。

## 4. 资源与切图规范

### 4.1 资源目录

正式资源不要放 `assets/mock/`。当前目录约定：

```text
assets/images/home/             首页相关图片
assets/navigation/bottom_tab/   底部导航图标
```

后续可扩展：

```text
assets/images/player/
assets/images/profile/
assets/images/store/
assets/icons/
```

### 4.2 Figma 切图命名

底部导航图标固定命名：

```text
home_selected.png
home_unselected.png
for_you_selected.png
for_you_unselected.png
my_list_selected.png
my_list_unselected.png
profile_selected.png
profile_unselected.png
```

规则：

- 选中和未选中态必须分开导出。
- 图片使用透明背景 PNG。
- 图标颜色由图片本身承载，不依赖 Flutter `Icon` 着色。
- 导出后按同名文件覆盖，不要改 Dart 路径。
- 如果 Figma 中图标尺寸变更，应同步检查 `AppBottomNavigation._iconSize`。

### 4.3 图片性能

- 列表中的图片必须控制解码尺寸，例如使用 `cacheWidth`。
- 不要把超大原图直接放进滚动列表。
- 图片资源应避免无意义透明边距，否则布局看起来会偏。
- 长列表图片优先使用缓存组件或明确尺寸，防止滚动时反复 layout。

## 5. 路由规范

路由相关文件：

```text
lib/app/router/route_paths.dart
lib/app/router/route_names.dart
lib/app/router/app_router.dart
```

规则：

- 新路由必须先加 `RoutePaths` 和 `RouteNames`。
- 页面跳转不要手写散落字符串。
- 带参数路径必须提供构造方法，例如 `playerLocation(...)`。
- 底部四个主 Tab 保持在 `StatefulShellRoute` 内。
- 二级页面、播放页、支付页、详情页默认放在 shell 外。

禁止：

- 在 widget 深层直接拼接路由字符串。
- 同一个业务页面注册多个无说明的路径。
- 页面里到处读取 `GoRouterState`，参数应在 route builder 中解析后传入页面。

## 6. 状态管理规范

当前状态管理使用 Riverpod。

规则：

- 依赖注入通过 provider。
- repository 接口放 `domain/`。
- repository 实现和 provider 装配放 `data/`。
- 页面简单 UI 状态可以用 `StatefulWidget`。
- 跨页面、可复用、可测试或复杂异步状态应放 provider/controller。
- 异步状态必须有 loading、empty、failure、retry。
- 列表分页必须处理：初始加载、加载更多、无更多、加载更多失败、重试。
- 多请求并发时必须防止旧请求覆盖新状态。

禁止：

- UI 直接 new 远程数据源。
- UI 里硬编码业务 mock 列表。
- 直接在页面中散落复杂业务判断。

## 7. 数据层与接口规范

### 7.1 Repository 边界

UI 只依赖 repository 或应用层 controller，不直接依赖 Dio、database、secure storage。

推荐形态：

```dart
abstract interface class XxxRepository {
  Future<XxxPage> listXxx(...);
}
```

规则：

- mock repository 和 remote repository 实现同一个接口。
- mock 数据放 `data/`，不要写在 widget 里。
- API DTO 不要直接污染 UI 层，必要时转换成 domain model。
- 分页优先使用 cursor / `nextPageToken`，UI 不假设 page number。

### 7.2 支付和权益

支付、金币、会员、剧集解锁必须以后端为准。

禁止：

- 客户端根据本地状态直接授予最终权益。
- 客户端把本地缓存当作可信权益。
- 支付成功 UI 和服务端验单成功混为一谈。

## 8. 多语言规范

当前默认语言是英文：

```dart
locale: Locale('en')
```

规则：

- 本地 UI 文案放 `lib/l10n/app_localizations.dart`。
- 新增本地文案必须同时补英文和中文。
- 服务端内容不进入本地多语言表，例如分类标题、短剧标题、标签、播放量。
- Widget 中不要直接写通用文案。
- 如果后续加入语言设置，应通过统一 locale 状态控制，不要在页面内单独判断语言。

### 8.1 远程文案包预留方案

后续如果固定 UI 文案需要支持更多语言，或运营需要不发版调整文案，可以引入服务端远程文案包。当前阶段只记录方案，不实现远程 i18n 代码，不新增 `core/i18n` 目录，不迁移 ARB/gen-l10n。

推荐结构：

```text
本地 AppLocalizations / 内置文案 = 基础兜底
远程 JSON 文案包 = 服务端可更新覆盖层
业务接口文案 = 短剧、分类、商品、权益、活动等业务内容
```

远程 JSON 文案包建议包含：

```json
{
  "version": "2026.05.13.1",
  "locale": "en-US",
  "updatedAt": "2026-05-13T09:00:00Z",
  "messages": {
    "nav.home": "Home",
    "common.delete": "Delete",
    "profile.language": "Language"
  }
}
```

客户端文案读取优先级：

```text
远程 JSON 文案 -> 本地 AppLocalizations / 内置文案 -> 英文兜底 -> key 本身（仅开发环境）
```

服务端更新机制建议：

- 提供版本检查接口，例如 `/app/i18n/version?locale=en-US&appVersion=1.0.0`。
- 返回远程包 `version`、`downloadUrl`、`checksum` 和是否强制更新。
- 客户端启动时先使用本地缓存或内置文案渲染，再后台检查更新。
- 下载成功后校验 checksum，保存本地缓存，下次启动优先使用。
- MVP 阶段优先使用全量 JSON 包，不做增量 patch。

边界规则：

- 固定 UI 文案可以进入远程文案包，但本地必须保留兜底。
- 短剧标题、简介、分类、标签、商品名、会员权益、活动 banner 等业务内容仍由业务接口按当前语言下发。
- 支付、网络和验单错误优先用错误码映射到本地/远程文案 key，不直接展示服务端原始 message。
- 远程文案 key 必须稳定，允许新增，删除或改名需要兼容旧客户端。
- 在服务端接口和语言范围确定前，不提前实现远程文案下载、缓存和 resolver。

## 9. 首页规范

首页是当前核心页面，约束更严格。

必须保持：

- 瀑布流布局。
- 分类 tab 来自 `DramaRepository.listHomeCategories()`。
- feed 数据来自 `DramaRepository.listHomeFeed()`。
- 分类标题、短剧标题、标签视为服务端内容。
- `nextPageToken == null` 表示无更多。
- 切换分类时要防止旧请求覆盖新分类数据。

不要做：

- 把首页改成普通固定高度 grid，除非设计明确调整。
- 在 UI 中硬编码 feed item。
- 因性能问题直接删除视觉元素。
- 在滚动中创建播放器实例。

## 10. 底部导航规范

底部导航由：

```text
lib/shared/widgets/navigation/app_bottom_navigation.dart
assets/navigation/bottom_tab/
```

规则：

- 使用图片图标，分选中和未选中态。
- 图标资源路径集中在 `_items` 配置中。
- 文案走 `AppLocalizations`。
- 背景色、文字颜色、尺寸变更必须对照 Figma。
- 图片缺失时可以短期 fallback 到 Material icon，但正式提交设计验收前必须补齐图片。

不要做：

- 在每个 tab 中手写不同布局。
- 选中态只靠 Flutter tint 改色，除非设计确认。
- 把底部导航图标混放到首页图片目录。

## 11. 播放器规范

播放器使用 `media_kit`。

规则：

- `MediaKit.ensureInitialized()` 只在启动阶段初始化。
- `Player` 和 `VideoController` 由 player feature 管理。
- 离开播放页必须释放播放器资源。
- 播放器状态通过 controller 暴露给 UI。
- 进度上报、解锁判断、自动下一集、预加载应拆成独立应用层组件。

禁止：

- 在 feed 列表卡片中创建真实播放器。
- 在多个 widget 中随意持有 `Player`。
- 不 dispose 播放器资源。

## 12. 网络与错误处理规范

网络基础能力放在：

```text
lib/core/network/
```

规则：

- 统一使用 `ApiClient`。
- 超时、HTTP 错误、业务错误要统一转换。
- token、receipt、手机号、邮箱等敏感信息不要进入普通日志。
- 可重试和不可重试错误要区分。
- 401、支付失败、网络超时、服务端错误应有统一处理策略。

## 13. 测试规范

提交前至少运行：

```bash
flutter analyze
flutter test
```

建议使用：

```bash
fvm flutter analyze
fvm flutter test
```

但当前本机 FVM 可能未完整安装 SDK，可使用全局 Flutter。

测试要求：

- 路由和主壳层改动要有 widget test。
- repository、错误转换、分页状态要有 unit test。
- 支付状态机、播放器 session、复杂 controller 必须有测试。
- 修 bug 时优先补一个能覆盖 bug 的测试。

禁止：

- 为了让测试通过删除有效断言。
- 对异步状态只测 happy path。
- UI 大改后不跑 smoke test。

## 14. 构建与发布包规范

常用命令：

```bash
flutter build apk --release
```

规则：

- 发给测试机前必须确认是最新构建产物。
- 安装前确认设备 id，避免装错机器。
- release 包路径默认是：

```text
build/app/outputs/flutter-apk/app-release.apk
```

建议：

- 内部测试用 APK。
- 正式商店分发优先使用 AAB。
- 后续接正式签名时，要补充 keystore 和渠道包规范。

## 15. AI 协作规范

本项目允许使用 AI 写代码，但 AI 必须遵守以下约束。

### 15.0 整改推进规则

结构性整改必须先记录到：

```text
docs/archive/2026-05-rc/refactor-tracker.md
```

规则：

- 整改前先确认目标、范围、完成标准和验证方式。
- 每轮只处理一类问题，避免把状态、视觉、资源、网络一起混改。
- 已验收 UI 不因为整改改变视觉结构或交互节奏。
- 整改完成后更新状态和验证结果。
- 如果整改发现新的风险项，追加到整改队列，不要顺手扩大范围。

### 15.1 AI 开始前必须做的事

AI 在改代码前必须：

- 读取相关文件，而不是凭空猜结构。
- 明确本次改动范围。
- 优先复用已有模式。
- 识别是否已有用户未提交改动，不要覆盖。
- 对视觉任务先确认 Figma 或现有截图。

### 15.2 AI 不能做的事

AI 禁止：

- 擅自大重构。
- 擅自删除用户已有改动。
- 为了性能改变设计稿结构。
- 为了方便把业务逻辑写进 UI。
- 新增未使用依赖。
- 在多个地方散落同一个颜色、资源路径、路由字符串。
- 不跑检查就说完成。
- 用 mock 名义放正式资源。

### 15.3 AI 修改 UI 时的规则

AI 修改 UI 必须：

- 保持 Figma 视觉结构。
- 保持文字不溢出。
- 保持小屏可用。
- 保持滚动性能。
- 对列表图片使用合适尺寸。
- 对底部导航、播放器、支付等关键体验优先做真机验证。

如果设计和性能冲突，AI 应先提出方案，而不是直接牺牲其中一边。

### 15.4 AI 输出结果时必须说明

AI 完成后应说明：

- 改了哪些文件。
- 为什么这么改。
- 跑了哪些验证命令。
- 哪些事情没有做或仍需补资源。
- 是否需要重新打包安装。

## 16. Code Review 检查清单

每次合并前至少检查：

- 是否符合 feature-first 目录结构。
- 是否没有散落路由字符串。
- 是否没有散落通用 UI 文案。
- 是否没有把服务端内容写进本地多语言。
- 是否没有新增无用依赖。
- 是否没有把正式资源放到 mock 目录。
- 是否列表图片做了尺寸控制。
- 是否底部导航图标资源成对存在。
- 是否 `flutter analyze` 通过。
- 是否 `flutter test` 通过。
- 是否对用户可见 UI 做过真机或模拟器 smoke test。

## 17. 需要后续补齐的规范

当前还建议继续补这些专项文档：

- Figma 标注与切图规范：颜色、字体、icon 导出、图片倍率。
- API 接口规范：错误码、分页、鉴权、重试、日志脱敏。
- 埋点规范：事件命名、字段、触发时机、离线队列。
- 支付规范：商品、订单、验单、恢复购买、权益刷新。
- 播放器规范：状态机、手势、预加载、错误恢复、进度上报。
- Git/分支/提交规范：分支命名、commit message、PR checklist。
