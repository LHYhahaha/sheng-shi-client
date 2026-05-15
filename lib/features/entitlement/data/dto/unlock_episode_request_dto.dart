class UnlockEpisodeRequestDto {
  const UnlockEpisodeRequestDto({
    required this.dramaId,
    required this.episodeId,
    required this.requiredCoins,
    required this.operationId,
  });

  final String dramaId;
  final String episodeId;
  final int requiredCoins;
  final String operationId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'dramaId': dramaId,
      'episodeId': episodeId,
      'requiredCoins': requiredCoins,
      'operationId': operationId,
      'idempotencyKey': operationId,
    };
  }
}
