import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

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
  ProviderSubscription<PopupConfig?>? _pendingPopupSubscription;

  @override
  void initState() {
    super.initState();
    _pendingPopupSubscription = ref.listenManual<PopupConfig?>(
      popupEntryControllerProvider.select((state) => state.pendingPopup),
      (_, pendingPopup) {
        if (pendingPopup == null || identical(_preloadingPopup, pendingPopup)) {
          return;
        }
        _preloadingPopup = pendingPopup;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadPopupImage(pendingPopup);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _pendingPopupSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popup = ref.watch(
      popupEntryControllerProvider.select((state) => state.activePopup),
    );
    if (popup == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: SafeArea(
          child: Center(
            child: _PopupEntryContent(
              popup: popup,
              onClose: () {
                ref
                    .read(popupEntryControllerProvider.notifier)
                    .closeActivePopup();
              },
              onImageError: () {
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

    var preloadFailed = false;
    Object? preloadError;
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
        onError: (error, stackTrace) {
          preloadFailed = true;
          preloadError = error;
        },
      );
      if (!mounted) {
        return;
      }
      if (preloadFailed) {
        debugPrint(
          '[PopupEntryOverlay] Popup image preload failed for '
          '${popup.id ?? 'unknown'}: $imageUrl, error: $preloadError',
        );
        if (identical(_preloadingPopup, popup)) {
          _preloadingPopup = null;
        }
        ref
            .read(popupEntryControllerProvider.notifier)
            .discardPendingPopup(popup);
        return;
      }
      ref
          .read(popupEntryControllerProvider.notifier)
          .markPendingPopupImageReady(popup);
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint(
        '[PopupEntryOverlay] Popup image preload failed for '
        '${popup.id ?? 'unknown'}: $imageUrl, error: $error',
      );
      if (identical(_preloadingPopup, popup)) {
        _preloadingPopup = null;
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

class _PopupEntryContent extends StatefulWidget {
  const _PopupEntryContent({
    required this.popup,
    required this.onClose,
    required this.onImageError,
    required this.onImageTap,
    required this.onPlayTap,
  });

  final PopupConfig popup;
  final VoidCallback onClose;
  final VoidCallback onImageError;
  final ValueChanged<PopupConfig>? onImageTap;
  final ValueChanged<PopupConfig>? onPlayTap;

  @override
  State<_PopupEntryContent> createState() => _PopupEntryContentState();
}

class _PopupEntryContentState extends State<_PopupEntryContent> {
  static const double _imageAspectRatio = 262 / 352;

  bool _actionLocked = false;

  PopupConfig get popup => widget.popup;

  bool get _showsCloseButton => popup.showCloseButton == 1;

  @override
  void didUpdateWidget(covariant _PopupEntryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.popup, oldWidget.popup)) {
      _actionLocked = false;
    }
  }

  void _runOnce(VoidCallback action) {
    if (_actionLocked) {
      return;
    }
    setState(() {
      _actionLocked = true;
    });
    action();
  }

  void _runOnceIfPresent(ValueChanged<PopupConfig>? action) {
    if (action == null) {
      return;
    }
    _runOnce(() => action(popup));
  }

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
      onTap: () => _runOnceIfPresent(widget.onImageTap),
      child: _PopupImage(
        imageUrl: popup.popupImage ?? '',
        width: width,
        aspectRatio: _imageAspectRatio,
        onError: widget.onImageError,
      ),
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          image,
          if (_showsCloseButton)
            Positioned(
              top: 6,
              right: 6,
              child: _PopupCloseButton(
                _actionLocked ? null : () => _runOnce(widget.onClose),
              ),
            ),
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
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
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
                          fontSize: 18,
                          fontWeight: FontWeight(850),
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
                          color: Colors.white.withValues(alpha: 0.5),
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
                        onError: widget.onImageError,
                      ),
                    ],
                  ),
                ),
                if (_showsCloseButton)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _PopupCloseButton(
                      _actionLocked ? null : () => _runOnce(widget.onClose),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: width - 16,
            height: 44,
            child: FilledButton(
              onPressed: _actionLocked
                  ? null
                  : () => _runOnceIfPresent(widget.onPlayTap),
              style: FilledButton.styleFrom(
                backgroundColor: Color(0XFFFF007A),
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: Color(0XFFFF007A),
                disabledForegroundColor: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    "assets/images/home/play_icon.svg",
                    width: 12,
                    height: 12,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Play',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight(590)),
                  ),
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

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onPressed,
      semanticLabel: 'Close popup',
      minSize: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0XFF292929),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(Icons.close_rounded, color: Color(0xFFBCBCBC), size: 18),
        ),
      ),
    );
  }
}
