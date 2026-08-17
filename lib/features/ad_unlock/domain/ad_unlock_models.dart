enum AdUnlockDramaKind { normal, member }

enum AdEpisodeUnlockStatus {
  unlockable,
  memberOnly,
  outOfSequence,
  unavailable;

  static AdEpisodeUnlockStatus fromWire(int value) => switch (value) {
    1 => memberOnly,
    2 => outOfSequence,
    3 => unavailable,
    _ => unlockable,
  };
}

enum AdMaterialType {
  image,
  video;

  static AdMaterialType fromWire(int value) =>
      value == 2 ? AdMaterialType.video : AdMaterialType.image;
}

class AdUnlockStatus {
  const AdUnlockStatus({
    required this.enabled,
    required this.normalDailyLimit,
    required this.normalUsedCount,
    required this.normalRemainCount,
    required this.memberDailyLimit,
    required this.memberUsedCount,
    required this.memberRemainCount,
    required this.episodeUnlockStatus,
    this.resetTime,
    this.message,
  });

  final bool enabled;
  final int normalDailyLimit;
  final int normalUsedCount;
  final int normalRemainCount;
  final int memberDailyLimit;
  final int memberUsedCount;
  final int memberRemainCount;
  final AdEpisodeUnlockStatus episodeUnlockStatus;
  final String? resetTime;
  final String? message;

  bool canShowPrompt(AdUnlockDramaKind kind) =>
      canShowPaywallAction(kind) && hasRemaining(kind);

  bool canShowPaywallAction(AdUnlockDramaKind kind) =>
      enabled &&
      episodeUnlockStatus != AdEpisodeUnlockStatus.outOfSequence &&
      episodeUnlockStatus != AdEpisodeUnlockStatus.unavailable;

  bool hasRemaining(AdUnlockDramaKind kind) {
    final count = kind == AdUnlockDramaKind.normal
        ? normalRemainCount
        : memberRemainCount;
    return count == -1 || count > 0;
  }

  int usedCount(AdUnlockDramaKind kind) =>
      kind == AdUnlockDramaKind.normal ? normalUsedCount : memberUsedCount;

  int dailyLimit(AdUnlockDramaKind kind) =>
      kind == AdUnlockDramaKind.normal ? normalDailyLimit : memberDailyLimit;
}

class AdMaterial {
  const AdMaterial({
    required this.id,
    required this.fileUrl,
    required this.type,
  });

  final int id;
  final String fileUrl;
  final AdMaterialType type;
}

class AdUnlockSession {
  const AdUnlockSession({
    required this.sessionNo,
    required this.material,
    required this.watchSeconds,
    required this.expiresAt,
    required this.reused,
    this.h5Url,
    this.materialFilePath,
  });

  final String sessionNo;
  final AdMaterial material;
  final int watchSeconds;
  final DateTime expiresAt;
  final bool reused;
  final String? h5Url;
  final String? materialFilePath;

  AdUnlockSession copyWith({String? materialFilePath}) {
    return AdUnlockSession(
      sessionNo: sessionNo,
      material: material,
      watchSeconds: watchSeconds,
      expiresAt: expiresAt,
      reused: reused,
      h5Url: h5Url,
      materialFilePath: materialFilePath ?? this.materialFilePath,
    );
  }
}
