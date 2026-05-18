# Runtime Docs

本目录放全局运行时配置、设备能力分级、性能策略、远程配置预留和启动期 runtime 合并规则。

## 文档

- [App Runtime System](app-runtime-system.md)：`AppRuntimeConfig`、设备分级、播放器策略、多语言配置、feature flags 的统一说明。

## 复用规则

- 新增全局配置时，先判断是否属于 runtime 根配置，而不是散落到 feature provider 或 dart-define。
- 设备能力、性能档位、播放器预加载数量、多语言开关等，都应从 runtime 派生。
- 环境打包配置方案尚未进入本版本，后续如果做 build-time env mapping，应在本目录新增独立文档。
