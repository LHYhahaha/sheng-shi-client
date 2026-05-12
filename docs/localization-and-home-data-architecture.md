# 多语言与首页数据架构规范

## 当前代码 Review

### 已修复问题

- 首页之前在 UI 层用 `_buildPage` 直接造分类和内容，后续接后端时会导致页面大改。现在已改为 `DramaRepository` 提供分类和 feed 分页数据，首页只负责渲染和状态流转。
- 首页分类 tab 使用过可变 `List` 传给 `SliverPersistentHeaderDelegate`，数据加载后 delegate 可能不重建。现在传入不可变快照，避免可变引用导致 UI 不刷新。
- 导航、占位页、错误/空态等本地 UI 文案之前散落在 widget 里。现在统一收口到 `AppLocalizations`。
- 首页分页现在有初始加载、加载更多、失败、空态和重试状态，不再只有一个本地延迟模拟。

### 仍需注意

- 首页视觉代码仍集中在一个文件内。M2 收尾时建议把 `HomeDramaCard`、`HomeCategoryTabs`、`HomeFeedFooter` 拆到 `widgets/`，让页面文件只保留状态编排。
- 底部导航图标仍是内置 icon 占位。等拿到干净切图后，只替换图标实现，不改布局。
- 当前 mock repository 使用本地 asset。真实后端接入时，`coverAssetPath` 应替换为 `coverUrl` 或设计一个 `DramaCover` value object，以同时支持本地 mock 和远程图片。

## 多语言边界

### 本地多语言

这些文案由客户端维护，走 `AppLocalizations`：

- 底部导航：Home、For you、My list、Profile
- 通用状态：Loading、Retry、Load failed、Empty
- 功能入口/占位页：Store、Wallet、Membership、Language 等
- 本地 UI 标签：例如 `Exclusive`

使用方式：

```dart
context.l10n.navHome
context.l10n.retry
```

新增本地文案时，必须同时补英文和中文，不允许在 widget 中直接写散落字符串。

### 服务端内容

这些内容来自服务端，不走客户端多语言表：

- 首页分类标题，例如 Popular、New、Ranking
- 短剧标题
- 标签，例如 Rebirth
- 播放量展示文案，如果服务端已经格式化，例如 84.1 M

如果未来需要按用户语言返回内容，客户端只透传当前语言参数给接口，仍由服务端返回最终展示文本。

## 首页数据接口

首页只依赖 `DramaRepository`：

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

### 分类模型

```dart
class DramaCategory {
  final String id;
  final String title;
}
```

`id` 是稳定业务字段，用于请求 feed；`title` 是服务端返回的展示文本。

### Feed 模型

```dart
class DramaFeedPage {
  final List<Drama> items;
  final String? nextPageToken;
}
```

分页统一用 `nextPageToken`，不要在 UI 层假设页码。后端可以实现为 page、cursor 或 offset，UI 不感知。

## Mock 策略

当前 `MockDramaRepository` 是唯一测试数据来源：

- `listHomeCategories()` 模拟后端分类接口
- `listHomeFeed()` 模拟按分类分页加载
- `nextPageToken == null` 表示没有更多

后续接真实 API 时，新建 `RemoteDramaRepository` 实现同一接口，再在 `dramaRepositoryProvider` 中按环境切换。

## 开发约束

- UI 组件不能直接创建业务 mock 数据。
- 分类和内容标题默认视为服务端内容，不进入本地多语言表。
- 本地 UI 文案必须通过 `context.l10n` 获取。
- 异步加载要防止过期请求覆盖新状态，当前首页用 `_loadGeneration` 处理分类切换竞态。
- 给 `SliverPersistentHeaderDelegate` 等 delegate 传数据时，避免传可变集合引用。
