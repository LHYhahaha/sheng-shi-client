import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_popup_names.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_cached_network_image.dart';
import '../application/ad_unlock_popup_analytics.dart';

Future<bool> showAdUnlockPromptDialog(
  BuildContext context, {
  required String? coverUrl,
  required int watchedToday,
  required int dailyLimit,
  required AnalyticsService analytics,
  required String dramaId,
  required String episodeId,
  required String dramaAccessType,
  required String adMaterialId,
}) async {
  final popupParameters = <String, Object?>{
    'popup_name': AnalyticsPopupNames.adUnlock,
    ...adUnlockPopupAnalyticsParameters(
      dramaId: dramaId,
      episodeId: episodeId,
      dramaAccessType: dramaAccessType,
      adMaterialId: adMaterialId,
    ),
  };
  final buttonParameters = <String, Object?>{
    'element_name': 'ad_unlock_button',
    ...adUnlockPopupAnalyticsParameters(
      dramaId: dramaId,
      episodeId: episodeId,
      dramaAccessType: dramaAccessType,
      adMaterialId: adMaterialId,
    ),
  };
  unawaited(
    analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.popupShow, popupParameters),
    ),
  );
  try {
    final selected = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AdUnlockPromptDialog(
          coverUrl: coverUrl,
          watchedToday: watchedToday,
          dailyLimit: dailyLimit,
          onWatchAdTap: () {
            unawaited(
              analytics.track(
                AnalyticsEvent(
                  AnalyticsDefinitions.elementClick,
                  buttonParameters,
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    return selected ?? false;
  } finally {
    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.popupClose, popupParameters),
      ),
    );
  }
}

class _AdUnlockPromptDialog extends StatelessWidget {
  const _AdUnlockPromptDialog({
    required this.coverUrl,
    required this.watchedToday,
    required this.dailyLimit,
    required this.onWatchAdTap,
  });

  final String? coverUrl;
  final int watchedToday;
  final int dailyLimit;
  final VoidCallback onWatchAdTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 82).clamp(280.0, 320.0);
    final limitLabel = dailyLimit == -1 ? '∞' : '$dailyLimit';
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Container(
                width: width,
                padding: const EdgeInsets.fromLTRB(10, 37, 10, 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.adUnlockModalTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: _CoverImage(coverUrl: coverUrl)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          onWatchAdTap();
                          Navigator.of(context).pop(true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF007A),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.adUnlockActionWatch,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.adUnlockTodayProgress(
                                watched: watchedToday,
                                total: limitLabel,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF292929),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white60,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    if (url == null || url.isEmpty) {
      return const SizedBox(width: 126, height: 166);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AppCachedNetworkImage(
        imageUrl: url,
        width: 126,
        height: 166,
        fit: BoxFit.cover,
      ),
    );
  }
}
