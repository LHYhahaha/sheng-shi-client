import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/app_runtime_config_provider.dart';
import '../domain/player_chrome_auto_immersive_config.dart';

/// 测试 / debug：覆盖单剧自动沉浸 UI 配置（最高优先级）。
final playerChromeAutoImmersiveConfigOverrideProvider =
    Provider<PlayerChromeAutoImmersiveConfig?>(
      (ref) => null,
      name: 'playerChromeAutoImmersiveConfigOverride',
    );

/// 单剧 chrome 自动沉浸配置：默认来自 [appRuntimeConfigProvider].player。
final playerChromeAutoImmersiveConfigProvider =
    Provider<PlayerChromeAutoImmersiveConfig>((ref) {
      final override = ref.watch(
        playerChromeAutoImmersiveConfigOverrideProvider,
      );
      if (override != null) {
        return override;
      }
      return PlayerChromeAutoImmersiveConfig.fromRuntime(
        ref.watch(appRuntimeConfigProvider).player,
      );
    }, name: 'playerChromeAutoImmersiveConfig');
