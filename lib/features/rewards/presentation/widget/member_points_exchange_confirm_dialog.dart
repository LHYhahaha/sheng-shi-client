import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/analytics_popup_names.dart';
import '../../../../l10n/app_localizations.dart';

Future<bool> showMemberPointsExchangeConfirmDialog(
  BuildContext context, {
  required int memberDays,
  required int pointCost,
  required int tierId,
}) async {
  final analytics = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(analyticsServiceProvider);
  final popupParameters = <String, Object?>{
    'popup_name': AnalyticsPopupNames.memberPointsExchangeConfirm,
    'exchange_tier_id': tierId.toString(),
    'required_member_points': pointCost,
    'grant_vip_days': memberDays,
  };
  // `showGeneralDialog` 创建路由即代表弹框已进入展示流程；关闭事件统一由 finally
  // 兜底，包含点击确认、关闭按钮、系统返回和点击遮罩。
  unawaited(
    analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.popupShow, popupParameters),
    ),
  );
  try {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.76),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MemberPointsExchangeConfirmDialog(
          memberDays: memberDays,
          pointCost: pointCost,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
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
    return confirmed ?? false;
  } finally {
    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.popupClose, popupParameters),
      ),
    );
  }
}

class _MemberPointsExchangeConfirmDialog extends StatelessWidget {
  const _MemberPointsExchangeConfirmDialog({
    required this.memberDays,
    required this.pointCost,
  });

  final int memberDays;
  final int pointCost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);
    final dialogWidth = (MediaQuery.sizeOf(context).width - 64).clamp(
      280.0,
      340.0,
    );

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const Key('member_points_exchange_confirm_dialog'),
            width: dialogWidth,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF211F22),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.memberCenterExchangeDaysMember(memberDays),
                        key: const Key('member_points_exchange_confirm_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight(510),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/rewards/points_icon.png',
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "$pointCost",
                              key: const Key(
                                'member_points_exchange_confirm_points',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.memberCenterModalExchangeRules(memberDays),
                        key: const Key('member_points_exchange_confirm_rules'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          key: const Key(
                            'member_points_exchange_confirm_button',
                          ),
                          onPressed: () {
                            unawaited(
                              ProviderScope.containerOf(context)
                                  .read(analyticsServiceProvider)
                                  .track(
                                    const AnalyticsEvent(
                                      AnalyticsDefinitions.elementClick,
                                      {
                                        'element_name':
                                            'member_points_exchange_confirm_button',
                                      },
                                    ),
                                  ),
                            );
                            Navigator.of(context).pop(true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0080),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            l10n.memberCenterModalExchangeConfirmButton,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('member_points_exchange_confirm_close'),
                    onPressed: () => Navigator.of(context).pop(false),
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
