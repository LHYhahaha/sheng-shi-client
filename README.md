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
- [多语言与首页数据架构规范](docs/localization-and-home-data-architecture.md)
- [Player Experience System Architecture](docs/player-experience-architecture-plan.md)
- [Player Playback And Cache Plan](docs/player-playback-cache-plan.md)
- [Player Source And CDN Spec](docs/player-source-and-cdn-spec.md)
- [Development Schedule](docs/development-schedule.md)

## Flutter Version

Use Flutter stable `3.41.9`.

```bash
fvm install 3.41.9
fvm use 3.41.9
fvm flutter doctor
```

This workspace was bootstrapped with a global Flutter `3.41.9` SDK because the local FVM download was interrupted by network instability. Once FVM has the SDK installed, use `fvm flutter ...` for all Flutter commands.
