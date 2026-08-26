import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

/// 将 Adjust 返回的设备广告标识关联到当前内部 Device-Id（由公共请求头携带）。
///
/// 此接口是匿名接口，不能等待登录态，也不携带 Authorization。
class AdjustDeviceIdentifierReporter {
  AdjustDeviceIdentifierReporter({
    required ApiClient apiClient,
    AdjustDeviceIdentifierPendingStore? pendingStore,
  }) : _apiClient = apiClient,
       _pendingStore =
           pendingStore ??
           SharedPreferencesAdjustDeviceIdentifierPendingStore();

  final ApiClient _apiClient;
  final AdjustDeviceIdentifierPendingStore _pendingStore;

  /// 在网络恢复或下次启动时补发上次未确认成功的设备标识。
  Future<bool> recoverPending() async {
    try {
      final pending = await _pendingStore.read();
      if (pending == null) return false;
      return report(adjustAdid: pending.adjustAdid, gpsAdid: pending.gpsAdid);
    } catch (error, stackTrace) {
      debugPrint('[Adjust] Pending device identifier recovery failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Returns true only after the backend has confirmed the binding.
  Future<bool> report({required String adjustAdid, String? gpsAdid}) async {
    final normalizedAdjustAdid = adjustAdid.trim();
    if (normalizedAdjustAdid.isEmpty) {
      debugPrint(
        '[Adjust] Device identifier report skipped: ADID unavailable.',
      );
      return false;
    }

    final normalizedGpsAdid = gpsAdid?.trim();
    final identifiers = AdjustDeviceIdentifiers(
      adjustAdid: normalizedAdjustAdid,
      gpsAdid: normalizedGpsAdid?.isEmpty == true ? null : normalizedGpsAdid,
    );
    // 先落盘，确保请求中的进程被系统终止或网络失败后仍可恢复。
    try {
      await _pendingStore.write(identifiers);
    } catch (error, stackTrace) {
      // 本地存储不可用不能阻断本次关键上报。
      debugPrint('[Adjust] Device identifier pending write failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    try {
      await _apiClient.post<void>(
        '/api/user/device/adjust',
        data: <String, String>{
          'adjustAdid': identifiers.adjustAdid,
          if (identifiers.gpsAdid != null) 'gpsAdid': identifiers.gpsAdid!,
        },
        decoder: (_) {},
      );
      try {
        await _pendingStore.clear();
      } catch (error, stackTrace) {
        // 服务端已成功绑定；留下的记录在下次会由服务端幂等处理。
        debugPrint('[Adjust] Device identifier pending clear failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      debugPrint('[Adjust] Device identifiers reported.');
      return true;
    } catch (error, stackTrace) {
      // 广告归因不能影响启动、登录或后续业务流程；待上报记录会在之后重试。
      debugPrint('[Adjust] Device identifier report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}

class AdjustDeviceIdentifiers {
  const AdjustDeviceIdentifiers({required this.adjustAdid, this.gpsAdid});

  final String adjustAdid;
  final String? gpsAdid;

  Map<String, String> toJson() => {
    'adjustAdid': adjustAdid,
    'gpsAdid': ?gpsAdid,
  };

  static AdjustDeviceIdentifiers? fromJson(Map<String, dynamic> json) {
    final adjustAdid = json['adjustAdid'] as String?;
    if (adjustAdid == null || adjustAdid.trim().isEmpty) return null;
    final gpsAdid = json['gpsAdid'] as String?;
    return AdjustDeviceIdentifiers(
      adjustAdid: adjustAdid,
      gpsAdid: gpsAdid?.trim().isEmpty == true ? null : gpsAdid,
    );
  }
}

abstract interface class AdjustDeviceIdentifierPendingStore {
  Future<AdjustDeviceIdentifiers?> read();
  Future<void> write(AdjustDeviceIdentifiers identifiers);
  Future<void> clear();
}

class SharedPreferencesAdjustDeviceIdentifierPendingStore
    implements AdjustDeviceIdentifierPendingStore {
  static const _storageKey = 'adjust.device_identifiers.pending.v1';

  @override
  Future<AdjustDeviceIdentifiers?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AdjustDeviceIdentifiers.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AdjustDeviceIdentifiers identifiers) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(identifiers.toJson()));
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
