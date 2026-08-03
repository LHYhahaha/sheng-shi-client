import 'api_mapping_exception.dart';

/// 远程 JSON 字段解析 helper（Post-RC A6 strict/fallback 策略）。
///
/// - **Strict required**：id、token、价格、权益决策、订单状态等 — 缺失或类型错误抛
///   [ApiMappingException]。
/// - **Display fallback**：title、coverUrl 等展示字段 — 使用 [optionalString] 等，由 mapper
///   决定 placeholder/asset。
/// - **Unknown enum**：不得默认成 free / paid / enabled=true 等危险值。
class JsonFieldParser {
  JsonFieldParser._();

  static Map<String, Object?> requireMap(
    Object? json, {
    required String dtoName,
    String field = r'$',
  }) {
    if (json is Map<String, Object?>) {
      return json;
    }
    if (json is Map) {
      return Map<String, Object?>.from(json);
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: field,
      reason: 'expected object map',
    );
  }

  static List<Object?> requireList(
    Object? json, {
    required String dtoName,
    String field = 'items',
  }) {
    if (json is List) {
      return json;
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: field,
      reason: 'expected array',
    );
  }

  static String requireString(
    Map<String, Object?> json,
    String key, {
    required String dtoName,
  }) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }else{
      return value.toString();
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: key,
      reason: 'required non-empty string',
    );
  }

  static String? optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static int requireInt(
    Map<String, Object?> json,
    String key, {
    required String dtoName,
  }) {
    final value = json[key];
    final parsed = _parseInt(value);
    if (parsed != null) {
      return parsed;
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: key,
      reason: 'required int',
    );
  }

  static int? optionalInt(Map<String, Object?> json, String key) {
    return _parseInt(json[key]);
  }

  static bool? optionalBool(Map<String, Object?> json, String key) {
    return _parseBool(json[key]);
  }

  static bool requireBool(
    Map<String, Object?> json,
    String key, {
    required String dtoName,
  }) {
    final value = json[key];
    final parsed = _parseBool(value);
    if (parsed != null) {
      return parsed;
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: key,
      reason: 'required bool',
    );
  }

  static DateTime requireDateTime(
    Map<String, Object?> json,
    String key, {
    required String dtoName,
  }) {
    final value = json[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      final parsed = _parseUtcDateTime(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: key,
      reason: 'required date-time',
    );
  }

  static DateTime? optionalDateTime(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return _parseUtcDateTime(value);
    }
    return null;
  }

  /// API timestamps represent UTC. A timezone-less ISO value is therefore
  /// interpreted as UTC instead of the device's local time.
  static DateTime? _parseUtcDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;

    final hasExplicitOffset = RegExp(
      r'(?:Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return hasExplicitOffset
        ? parsed.toUtc()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
  }

  static T parseEnumStrict<T extends Enum>(
    String raw,
    Map<String, T> values, {
    required String dtoName,
    required String field,
  }) {
    final normalized = raw.trim().toLowerCase();
    final match = values[normalized];
    if (match != null) {
      return match;
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: field,
      reason: 'unknown enum value',
    );
  }

  /// Player / entitlement `unlockType`：unknown 不得默认 free。
  static String parseUnlockType(
    Map<String, Object?> json, {
    required String dtoName,
    String key = 'unlockType',
  }) {
    final raw = json[key];
    if (raw is! String || raw.isEmpty) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'required unlockType',
      );
    }
    return switch (raw.toLowerCase()) {
      'free' => 'free',
      'coins' || 'coin' => 'coins',
      'membership' || 'member' || 'vip' => 'membership',
      _ => throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'unknown unlockType',
      ),
    };
  }

  /// 订单状态：unknown 不得默认 created/paid。
  static String parseOrderStatus(
    Map<String, Object?> json, {
    required String dtoName,
    String key = 'status',
  }) {
    final raw = json[key];
    if (raw is! String || raw.isEmpty) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'required order status',
      );
    }
    const allowed = {
      'created',
      'pending',
      'processing',
      'paid',
      'success',
      'failed',
      'cancelled',
      'canceled',
      'refunded',
    };
    final normalized = raw.toLowerCase();
    if (!allowed.contains(normalized)) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'unknown order status',
      );
    }
    return normalized;
  }

  /// Entitlement decision `type`。
  static String parseDecisionType(
    Map<String, Object?> json, {
    required String dtoName,
    String key = 'type',
  }) {
    final raw = json[key];
    if (raw is! String || raw.isEmpty) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'required decision type',
      );
    }
    const allowed = <String, String>{
      'allowplay': 'allowPlay',
      'gomembership': 'goMembership',
      'showcoinunlockdialog': 'showCoinUnlockDialog',
      'showrechargedialog': 'showRechargeDialog',
      'autounlockandplay': 'autoUnlockAndPlay',
      'waitunlock': 'waitUnlock',
    };
    final normalized = raw.toLowerCase();
    final canonical = allowed[normalized];
    if (canonical == null) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: key,
        reason: 'unknown decision type',
      );
    }
    return canonical;
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return switch (value.toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => null,
      };
    }
    return null;
  }
}
