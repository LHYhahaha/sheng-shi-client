/// 会员专享短剧接口返回的展示模型。
class VipOnlyDrama {
  const VipOnlyDrama({
    required this.id,
    required this.coverUrl,
    required this.title,
    required this.summary,
  });

  final String id;
  final String coverUrl;
  final String title;
  final String summary;
}

/// 会员专享短剧列表及服务端要求的最小展示数量。
class VipOnlyDramaCollection {
  const VipOnlyDramaCollection({required this.limit, required this.dramas});

  static const minimumDisplayCount = 6;

  final int limit;
  final List<VipOnlyDrama> dramas;

  /// 少于六部时，调用方应连同标题一起隐藏整个区块。
  bool get canDisplay => dramas.length >= minimumDisplayCount;
}
