import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatefulWidget {
  const AppCachedNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    this.errorWidget,
    this.placeholder,
    this.onError,
    this.fallbackBackgroundColor = const Color(0xFF302A36),
    super.key,
  });

  static const defaultErrorAssetPath = 'assets/images/home/image_error.png';

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? errorWidget;
  final Widget? placeholder;
  final VoidCallback? onError;
  final Color fallbackBackgroundColor;

  @override
  State<AppCachedNetworkImage> createState() => _AppCachedNetworkImageState();
}

class _AppCachedNetworkImageState extends State<AppCachedNetworkImage> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant AppCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = widget.imageUrl.trim();
    if (trimmedUrl.isEmpty || _hasError) {
      return _errorBox;
    }

    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      memCacheWidth: widget.cacheWidth,
      memCacheHeight: widget.cacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => widget.placeholder ?? _loadingBox,
      errorListener: (_) {
        if (mounted && !_hasError) {
          setState(() {
            _hasError = true;
          });
          widget.onError?.call();
        }
      },
      errorWidget: (context, url, error) => _errorBox,
    );
  }

  Widget get _loadingBox => SizedBox(
    width: widget.width,
    height: widget.height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: widget.fallbackBackgroundColor),
    ),
  );

  Widget get _errorBox {
    final customErrorWidget = widget.errorWidget;
    if (customErrorWidget != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: customErrorWidget,
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: widget.fallbackBackgroundColor),
        child: Center(
          child: Image.asset(
            AppCachedNetworkImage.defaultErrorAssetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
