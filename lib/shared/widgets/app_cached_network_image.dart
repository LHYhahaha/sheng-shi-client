import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatelessWidget {
  const AppCachedNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return _emptyBox;
    }

    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => _emptyBox,
      errorWidget: (context, url, error) => _emptyBox,
    );
  }

  Widget get _emptyBox => SizedBox(width: width, height: height);
}
