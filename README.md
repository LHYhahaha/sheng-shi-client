# Drama Client

Flutter short drama client.

## Documentation

- **重点：播放器本地 HLS proxy/cache 当前不建议生产化。先读
  [Player Local HLS Proxy / Cache Decision](docs/player-local-hls-proxy-cache.md)，
  再考虑任何本地 HLS 缓存、localhost proxy、segment cache 或类似优化。**
- [项目结构与开发规范](docs/project-structure-and-conventions.md)
- [开发约束与 AI 协作规范](docs/development-guidelines.md)
- [底部导航图片资源规范](docs/bottom-navigation-assets.md)
- [Technical Architecture](docs/technical-architecture.md)
- [App Runtime System](docs/app-runtime-system.md)
- [多语言与首页数据架构规范](docs/localization-and-home-data-architecture.md)
- [Player Experience System Architecture](docs/player-experience-architecture-plan.md)
- [Player Android Performance Policy](docs/player-android-stable-mode-plan.md)
- [Player Playback And Cache Plan](docs/player-playback-cache-plan.md)
- [Player Source And CDN Spec](docs/player-source-and-cdn-spec.md)
- [Development Schedule](docs/development-schedule.md)

## Player Device Performance Policy

播放器使用同一套 Feed/Video 架构，通过 `PlayerPerformancePolicy` 按设备能力切换体验，不维护 Android/iOS 两套播放器实现。

| 档位 | 默认设备 | 可见 | 跟手 Transform | opacity 压暗 | chrome 按压渐隐 | pause scale | rich 转场 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rich` | iOS / 高性能设备 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stable` | 普通 Android | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ultraStable` | 低端 Android / denylist / low tier | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

关键原则：

- `stable` 要点：与 `rich` 一样用 `Transform.translate` 跟 PageView；拖动时 opacity 恒为 1.0，无压暗/渐隐/缩放等额外动画。
- `ultraStable`：拖动时切整层 `SizedBox.shrink()`，不挂 surface，优先保证低端机手势流畅。
- 真实 `Video` 只允许挂在顶层 active playback surface，不能放回 PageView item。

详细策略、denylist 和历史决策见 [Player Android Performance Policy](docs/player-android-stable-mode-plan.md)。

## Flutter Version

Use Flutter stable `3.41.9`.

```bash
fvm install 3.41.9
fvm use 3.41.9
fvm flutter doctor
```

This workspace was bootstrapped with a global Flutter `3.41.9` SDK because the local FVM download was interrupted by network instability. Once FVM has the SDK installed, use `fvm flutter ...` for all Flutter commands.
