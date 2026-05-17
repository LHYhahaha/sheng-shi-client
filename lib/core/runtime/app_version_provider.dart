import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 读取真实包信息的 Future；测试可 override。
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// API `App-Version` header（如 `1.0.0`）。
///
/// 优先 `dart-define=APP_VERSION`；否则 [package_info_plus] 的 version（不含 build
/// number，build 仅用于排查时可另加 header）。加载失败时 fallback `1.0.0`。
final apiAppVersionProvider = Provider<String>((ref) {
  const envOverride = String.fromEnvironment('APP_VERSION');
  if (envOverride.isNotEmpty) {
    return envOverride;
  }

  final packageInfo = ref.watch(packageInfoProvider);
  return packageInfo.when(
    data: (info) => info.version.isNotEmpty ? info.version : '1.0.0',
    loading: () => '1.0.0',
    error: (_, _) => '1.0.0',
  );
});
