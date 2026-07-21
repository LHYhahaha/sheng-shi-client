import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final externalUrlLauncherProvider = Provider<ExternalUrlLauncher>((ref) {
  return const PlatformExternalUrlLauncher();
});

abstract interface class ExternalUrlLauncher {
  Future<bool> open(String url);
}

class PlatformExternalUrlLauncher implements ExternalUrlLauncher {
  const PlatformExternalUrlLauncher();

  @override
  Future<bool> open(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[ExternalUrlLauncher] Failed to open external URL: $error');
      return false;
    }
  }
}
