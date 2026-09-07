import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preference: independent of account entitlements and session cleanup.
/// TODO(download): The download task manager must listen for this becoming false
/// and pause active tasks on cellular networks, leaving Wi-Fi tasks unaffected.
/// It must also check this preference before starting/resuming cellular tasks.
final cellularDownloadPreferenceProvider =
    AsyncNotifierProvider<CellularDownloadPreference, bool>(
      CellularDownloadPreference.new,
    );

class CellularDownloadPreference extends AsyncNotifier<bool> {
  static const storageKey = 'settings.allow_cellular_download';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(storageKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    // Finish restoration before writing, so a late load cannot replace a choice.
    await future;
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(storageKey, enabled)) {
      throw StateError('Unable to save cellular download preference');
    }
    state = AsyncData(enabled);
  }
}
