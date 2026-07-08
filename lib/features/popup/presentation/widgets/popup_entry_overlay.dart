import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_tap_target.dart';
import '../../application/popup_entry_controller.dart';
import '../../domain/popup.dart';

class PopupEntryOverlay extends ConsumerStatefulWidget {
  const PopupEntryOverlay({this.onImageTap, this.onPlayTap, super.key});

  final ValueChanged<PopupConfig>? onImageTap;
  final ValueChanged<PopupConfig>? onPlayTap;

  @override
  ConsumerState<PopupEntryOverlay> createState() => _PopupEntryOverlayState();
}

class _PopupEntryOverlayState extends ConsumerState<PopupEntryOverlay> {
  PopupConfig? _preloadingPopup;

  @override
  Widget build(BuildContext context) {
    _preloadPendingPopup();
    final popup = ref.watch(
      popupEntryControllerProvider.select((state) => state.activePopup),
    );
    if (popup == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: _PopupEntryContent(
              popup: popup,
              onClose: () {
                ref
                    .read(popupEntryControllerProvider.notifier)
                    .dismissActivePopup();
              },
              onImageTap: widget.onImageTap,
              onPlayTap: widget.onPlayTap,
            ),
          ),
        ),
      ),
    );
  }

  void _preloadPendingPopup() {
    final pendingPopup = ref.watch(
      popupEntryControllerProvider.select((state) => state.pendingPopup),
    );
    if (pendingPopup == null || identical(_preloadingPopup, pendingPopup)) {
      return;
    }
    _preloadingPopup = pendingPopup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadPopupImage(pendingPopup);
    });
  }

  Future<void> _preloadPopupImage(PopupConfig popup) async {
    final imageUrl = popup.popupImage?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      ref
          .read(popupEntryControllerProvider.notifier)
          .discardPendingPopup(popup);
      if (identical(_preloadingPopup, popup)) {
        _preloadingPopup = null;
      }
      return;
    }

    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      if (!mounted) {
        return;
      }
      ref
          .read(popupEntryControllerProvider.notifier)
          .markPendingPopupImageReady(popup);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ref
          .read(popupEntryControllerProvider.notifier)
          .discardPendingPopup(popup);
    } finally {
      if (identical(_preloadingPopup, popup)) {
        _preloadingPopup = null;
      }
    }
  }
}

class _PopupEntryContent extends StatelessWidget {
  const _PopupEntryContent({
    required this.popup,
    required this.onClose,
    required this.onImageTap,
    required this.onPlayTap,
  });

  static const double _imageAspectRatio = 262 / 352;

  final PopupConfig popup;
  final VoidCallback onClose;
  final ValueChanged<PopupConfig>? onImageTap;
  final ValueChanged<PopupConfig>? onPlayTap;

  bool get _showsCloseButton => popup.showCloseButton == 1;

  @override
  Widget build(BuildContext context) {
    final contentMode = popup.contentMode;
    if (contentMode == 1) {
      return _buildImageOnly(context);
    }
    if (contentMode == 2) {
      return _buildDramaPrompt(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildImageOnly(BuildContext context) {
    final width = _dialogWidth(context);
    final image = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onImageTap?.call(popup),
      child: _PopupImage(
        imageUrl: popup.popupImage ?? '',
        width: width,
        aspectRatio: _imageAspectRatio,
        onError: onClose,
      ),
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          image,
          if (_showsCloseButton)
            Positioned(top: 8, right: 8, child: _PopupCloseButton(onClose)),
        ],
      ),
    );
  }

  Widget _buildDramaPrompt(BuildContext context) {
    final width = _dialogWidth(context);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your Next Drama',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A story you might love',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PopupImage(
                        imageUrl: popup.popupImage ?? '',
                        width: width - 8,
                        aspectRatio: _imageAspectRatio,
                        onError: onClose,
                      ),
                    ],
                  ),
                ),
                if (_showsCloseButton)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _PopupCloseButton(onClose),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: width,
            height: 40,
            child: FilledButton(
              onPressed: () => onPlayTap?.call(popup),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18),
                  SizedBox(width: 2),
                  Text('Play'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(262, math.max(220, screenWidth - 96));
  }
}

class _PopupImage extends StatelessWidget {
  const _PopupImage({
    required this.imageUrl,
    required this.width,
    required this.aspectRatio,
    required this.onError,
  });

  final String imageUrl;
  final double width;
  final double aspectRatio;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    final height = width / aspectRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AppCachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        onError: onError,
        fallbackBackgroundColor: const Color(0xFF302A36),
      ),
    );
  }
}

class _PopupCloseButton extends StatelessWidget {
  const _PopupCloseButton(this.onPressed);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onPressed,
      semanticLabel: 'Close popup',
      minSize: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(Icons.close_rounded, color: Color(0xFFD7D7D7), size: 18),
        ),
      ),
    );
  }
}
