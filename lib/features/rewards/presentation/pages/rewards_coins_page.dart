import 'dart:async';

import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../../../../app/router/route_paths.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../../core/auth/user_info_store.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../application/reward_coins_controller.dart';
import '../../domain/reward_coins_check_in_status.dart';
import '../../domain/reward_task.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../../core/toast/app_center_toast.dart';
import '../widget/reward_rules_sheet.dart';
import '../widget/reward_coins_check_in_success_dialog.dart';
import '../widget/reward_coins_claim_success_toast.dart';

const _gold = Color(0xFFFFD392);
const _muted = Color(0xFF77777B);
const _card = Color(0xFF1B1D23);
const _goldButtonText = Color(0xFF743000);
const _disabledButton = Color(0xFF696A6E);
const _goldButtonBorder = GradientBoxBorder(
  width: 1,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromRGBO(255, 255, 255, 0.52),
      Color.fromRGBO(255, 255, 255, 0.10),
      Color.fromRGBO(255, 255, 255, 0.04),
      Color.fromRGBO(255, 255, 255, 0.08),
    ],
    stops: [0, 0.2767, 0.8906, 1],
  ),
);

class RewardsCoinsPage extends ConsumerStatefulWidget {
  const RewardsCoinsPage({
    this.isActive = true,
    this.useParentBackground = false,
    super.key,
  });

  final bool isActive;
  final bool useParentBackground;

  @override
  ConsumerState<RewardsCoinsPage> createState() => _RewardsCoinsPageState();
}

class _RewardsCoinsPageState extends ConsumerState<RewardsCoinsPage>
    with WidgetsBindingObserver {
  bool _awaitingNotificationSettingsReturn = false;
  bool _notificationSettingsWasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingNotificationSettingsReturn) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _notificationSettingsWasBackgrounded = true;
      return;
    }
    if (state != AppLifecycleState.resumed ||
        !_notificationSettingsWasBackgrounded) {
      return;
    }

    _awaitingNotificationSettingsReturn = false;
    _notificationSettingsWasBackgrounded = false;
    unawaited(_refreshNotificationPermissionTask());
  }

  @override
  void didUpdateWidget(RewardsCoinsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refreshIfNeeded();
    }
  }

  void _refreshIfNeeded() {
    if (!widget.isActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      ref.read(rewardCoinsControllerProvider.notifier).loadCheckInStatus();
      ref.read(rewardCoinsControllerProvider.notifier).loadTasks();
      ref.read(entitlementControllerProvider.notifier).refreshFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewardCoinsState = ref.watch(rewardCoinsControllerProvider);
    final entitlement = ref.watch(entitlementControllerProvider);
    final supportedTasks = _supportedTasks(rewardCoinsState.tasks);

    return DecoratedBox(
      key: const Key('rewards_coins_page'),
      decoration: BoxDecoration(
        gradient: widget.useParentBackground
            ? null
            : const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF50390D), Color(0xFF121318)],
                stops: [0, 0.159],
              ),
      ),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          10.w,
          8.w,
          10.w,
          MediaQuery.paddingOf(context).bottom + 24.w,
        ),
        children: [
          _BalanceHeader(
            balance: entitlement.coinBalance + entitlement.bonusBalance,
          ),
          if (rewardCoinsState.isCheckInLoading)
            const _RewardsSectionLoading(
              key: Key('rewards_coins_check_in_loading'),
            )
          else if (rewardCoinsState.checkInError != null &&
              rewardCoinsState.checkInStatus == null)
            _RewardsSectionLoadFailed(
              key: const Key('rewards_coins_check_in_error'),
              onRetry: () {
                ref
                    .read(rewardCoinsControllerProvider.notifier)
                    .loadCheckInStatus();
              },
            )
          else if (rewardCoinsState.checkInStatus case final status?)
            if (status.days.isEmpty)
              const _RewardsSectionNoData(
                key: Key('rewards_coins_check_in_empty'),
              )
            else
              _CheckInPanel(
                status: status,
                isClaiming: rewardCoinsState.isClaiming,
                onCheckIn: (day) => _claimCheckIn(context, day),
              )
          else
            const _RewardsSectionNoData(
              key: Key('rewards_coins_check_in_empty'),
            ),
          SizedBox(height: 20.w),
          Text(
            context.l10n.rewardsTabRewardTaskTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final task in supportedTasks) ...[
            SizedBox(height: 8.w),
            _RewardTaskCard(
              key: Key('reward_task_${task.taskKey}'),
              task: task,
              onTap: () => _handleTaskTap(context, task),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimCheckIn(BuildContext context, int checkInDay) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'check_in_claim_button',
              'check_in_day': checkInDay,
            }),
          ),
    );
    try {
      final result = await ref
          .read(rewardCoinsControllerProvider.notifier)
          .claimCheckIn();
      if (!context.mounted) return;
      if (result?.isSuccess != true) {
        showAppCenterToast(context.l10n.networkError);
        return;
      }
      await showRewardCoinsCheckInSuccessDialog(
        context,
        rewardAmount: result!.rewardAmount,
      );
    } catch (_) {
      if (context.mounted) showAppCenterToast(context.l10n.networkError);
    }
  }

  List<RewardTask> _supportedTasks(List<RewardTask> tasks) {
    const keys = <String>{
      'coin.bind_account',
      'coin.enable_push',
      'coin.share_drama',
      'coin.watch.5m',
      'coin.watch.10m',
      'coin.watch.15m',
    };
    return tasks.where((task) => keys.contains(task.taskKey)).toList();
  }

  Future<void> _handleTaskTap(BuildContext context, RewardTask task) async {
    if (task.claimed) return;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'task_action_button',
              'task_code': task.taskKey,
              'task_action': task.completed ? 'claim' : 'go_complete',
            }),
          ),
    );
    if (task.completed) {
      await _claimTask(context, task.taskKey);
      return;
    }
    switch (task.taskKey) {
      case 'coin.bind_account':
        await context.push(RoutePaths.auth);
        if (mounted) {
          await ref.read(rewardCoinsControllerProvider.notifier).loadTasks();
        }
        return;
      case 'coin.enable_push':
        final currentStatus = await permissions.Permission.notification.status;
        if (_hasNotificationPermission(currentStatus)) {
          await _refreshNotificationPermissionTask();
          return;
        }
        _awaitingNotificationSettingsReturn = true;
        _notificationSettingsWasBackgrounded = false;
        final opened = await permissions.openAppSettings();
        if (!opened) {
          _awaitingNotificationSettingsReturn = false;
        }
        return;
      case 'coin.share_drama':
      case 'coin.watch.5m':
      case 'coin.watch.10m':
      case 'coin.watch.15m':
        context.go(RoutePaths.home);
        return;
    }
  }

  bool _hasNotificationPermission(permissions.PermissionStatus status) {
    return status.isGranted || status.isProvisional;
  }

  Future<void> _refreshNotificationPermissionTask() async {
    if (!mounted || !widget.isActive) return;
    await ref
        .read(startupNotificationPermissionReporterProvider)
        .syncForAccount(ref.read(userInfoStoreProvider).showId);
    if (!mounted || !widget.isActive) return;
    await ref.read(rewardCoinsControllerProvider.notifier).loadTasks();
  }

  Future<void> _claimTask(BuildContext context, String taskKey) async {
    try {
      final result = await ref
          .read(rewardCoinsControllerProvider.notifier)
          .claimTask(taskKey: taskKey);
      if (!context.mounted) return;
      if (result?.isSuccess != true) {
        showAppCenterToast(context.l10n.networkError);
        return;
      }
      showRewardCoinsClaimSuccessToast(context, result!.rewardAmount);
    } catch (_) {
      if (context.mounted) showAppCenterToast(context.l10n.networkError);
    }
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('rewards_coins_balance'),
      height: 102.w,
      child: Stack(
        children: [
          Positioned(
            left: 10.w,
            top: 33.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$balance',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 28.sp,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.w),
                Text(
                  context.l10n.rewardsCoinBalanceCurrent,
                  style: TextStyle(
                    color: Color(0xFF756A57),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 1.w,
            bottom: -30.w,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/rewards/coins_icon.png',
                  width: 142.w,
                  height: 142.w,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  bottom: 26.w,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: 142.w,
                    height: 29.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.9],
                        colors: [
                          Color(0xFF121318).withValues(alpha: 0),
                          Color(0xFF121318),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsSectionLoading extends StatelessWidget {
  const _RewardsSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96.w,
      child: Center(child: AppPegTopLoader(size: 20, noBackground: true)),
    );
  }
}

class _RewardsSectionLoadFailed extends StatelessWidget {
  const _RewardsSectionLoadFailed({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RewardsSectionStatus(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.networkError,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.w),
          AppRetryButton(onPressed: onRetry, label: context.l10n.retry),
        ],
      ),
    );
  }
}

class _RewardsSectionNoData extends StatelessWidget {
  const _RewardsSectionNoData({super.key});

  @override
  Widget build(BuildContext context) {
    return _RewardsSectionStatus(
      child: Text(
        context.l10n.noData,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14.sp,
        ),
      ),
    );
  }
}

class _RewardsSectionStatus extends StatelessWidget {
  const _RewardsSectionStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: child,
    );
  }
}

class _CheckInPanel extends StatelessWidget {
  const _CheckInPanel({
    required this.status,
    required this.isClaiming,
    required this.onCheckIn,
  });

  final RewardCoinsCheckInStatus status;
  final bool isClaiming;
  final ValueChanged<int> onCheckIn;

  @override
  Widget build(BuildContext context) {
    final checkInStatus = status;
    final days = checkInStatus.days;
    final canCheckIn =
        !checkInStatus.checkedToday &&
        !isClaiming &&
        status.days.any((day) => day.current && day.claimable);

    return Container(
      key: const Key('rewards_coins_check_in_panel'),
      padding: EdgeInsets.fromLTRB(12.w, 20.w, 12.w, 12.w),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8.w),
        image: const DecorationImage(
          image: AssetImage('assets/images/rewards/coins_bac.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFF9E9), Color(0xFFFFBD90)],
                  ).createShader(bounds),
                  child: Text(
                    context.l10n.rewardsSigninDaysCount(
                      checkInStatus.checkedDays,
                    ),
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('rewards_coins_rules'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showRewardRulesSheet(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.w),
                  ),
                  child: Text(
                    context.l10n.rewardsRuleEntry,
                    style: TextStyle(color: Color(0xFFAAA49D), fontSize: 11.sp),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.w),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildDayWidgets(days, checkInStatus.currentDay),
          ),
          SizedBox(height: 17.w),
          GestureDetector(
            key: const Key('rewards_coins_sign_in'),
            behavior: HitTestBehavior.opaque,
            onTap: canCheckIn
                ? () => onCheckIn(checkInStatus.currentDay)
                : null,
            child: Container(
              width: double.infinity,
              height: 44.w,
              decoration: BoxDecoration(
                color: canCheckIn ? null : _disabledButton,
                borderRadius: BorderRadius.circular(5.w),
                border: canCheckIn ? _goldButtonBorder : null,
                gradient: canCheckIn
                    ? const LinearGradient(
                        colors: [Color(0xFFD48851), Color(0xFFFFF3C7)],
                      )
                    : null,
              ),
              child: CustomPaint(
                key: const Key('rewards_coins_button_top_highlight'),
                foregroundPainter: canCheckIn
                    ? const _MemberPointsButtonTopHighlightPainter()
                    : null,
                child: Center(
                  child: Text(
                    canCheckIn
                        ? context.l10n.rewardsSigninButtonSignIn
                        : context.l10n.rewardsSigninButtonSignedIn,
                    style: TextStyle(
                      color: canCheckIn
                          ? _goldButtonText
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayWidgets(
    List<RewardCoinsCheckInDay> days,
    int currentDay,
  ) {
    return [
      for (var index = 0; index < days.length; index++) ...[
        if (index > 0) SizedBox(width: 4.w),
        Expanded(
          child: _CheckInDay(
            day: days[index].day,
            checked: days[index].checked,
            active: days[index].current || days[index].day == currentDay,
            rewardCoin: days[index].rewardCoin,
          ),
        ),
      ],
    ];
  }
}

class _CheckInDay extends StatelessWidget {
  const _CheckInDay({
    required this.day,
    required this.rewardCoin,
    this.checked = false,
    this.active = false,
  });

  final int day;
  final String rewardCoin;
  final bool checked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 67.w,
              width: 44.w,
              decoration: BoxDecoration(
                color: checked
                    ? const Color(0xFF373737)
                    : const Color(0xFFAF6E37),
                borderRadius: BorderRadius.circular(4.w),
                gradient: checked
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF91562B), Color(0xFFD9AA69)],
                      ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (checked)
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF929397),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        "assets/images/rewards/check_black.png",
                      ),
                    )
                  else
                    Image.asset(
                      'assets/images/rewards/coins.png',
                      width: 24.w,
                      height: 24.w,
                    ),
                  SizedBox(height: 6.w),
                  Text(
                    '+$rewardCoin',
                    style: TextStyle(
                      color: checked ? const Color(0xFF8C8D91) : Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!checked)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CheckInDayBorderPainter()),
                ),
              ),
          ],
        ),
        SizedBox(height: 7.w),
        if (checked)
          SizedBox(
            height: 13.w,
            width: 12.w,
            child: Image.asset("assets/images/rewards/check.png"),
          )
        else
          Text(
            context.l10n.rewardsSigninDayIndex(day),
            maxLines: 1,
            style: TextStyle(
              color: active ? Colors.white : _muted,
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _CheckInDayBorderPainter extends CustomPainter {
  const _CheckInDayBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      const Radius.circular(4),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFFFFF).withValues(alpha: 0.4),
          Color(0x1AFFFFFF),
          Color(0xFFFFFFFF).withValues(alpha: 0.4),
        ],
        stops: [0, 0.5, 1],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckInDayBorderPainter oldDelegate) => false;
}

class _RewardTaskCard extends StatelessWidget {
  const _RewardTaskCard({required this.task, required this.onTap, super.key});

  final RewardTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (task.taskKey) {
      'coin.bind_account' => l10n.rewardsTaskLogin,
      'coin.enable_push' => l10n.rewardsTaskEnablePush,
      'coin.share_drama' => l10n.rewardsTaskShare,
      'coin.watch.5m' => l10n.rewardsTaskWatch5,
      'coin.watch.10m' => l10n.rewardsTaskWatch10,
      'coin.watch.15m' => l10n.rewardsTaskWatch15,
      _ => task.displayName,
    };
    final imagePath = switch (task.taskKey) {
      'coin.bind_account' => 'assets/images/rewards/coins_login_account.png',
      'coin.enable_push' => 'assets/images/rewards/coins_notification.png',
      'coin.share_drama' => 'assets/images/rewards/coins_invite.png',
      _ => 'assets/images/rewards/coins_watch.png',
    };
    final label = task.claimed
        ? l10n.claimed
        : task.completed
        ? l10n.claim
        : l10n.goComplete;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Row(
        children: [
          Image.asset(imagePath, width: 32.w, height: 32.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 2.w),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: task.rewardText,
                        style: TextStyle(color: Color(0xFFE54900)),
                      ),
                      TextSpan(
                        text: ' ${context.l10n.unitCoin}',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF).withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            decoration: BoxDecoration(
              color: task.claimed ? const Color(0xFF696A6E) : null,
              gradient: task.claimed
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFD4864E), Color(0xFFFFF0BE)],
                    ),
              borderRadius: BorderRadius.circular(4.w),
              border: task.claimed ? null : _goldButtonBorder,
            ),
            child: CustomPaint(
              foregroundPainter: task.claimed
                  ? null
                  : const _MemberPointsButtonTopHighlightPainter(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: task.claimed ? null : onTap,
                  borderRadius: BorderRadius.circular(4.w),
                  child: Center(
                    child: Container(
                      width: 78.w,
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 6.w,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: task.claimed
                              ? Colors.white.withValues(alpha: 0.6)
                              : _goldButtonText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPointsButtonTopHighlightPainter extends CustomPainter {
  const _MemberPointsButtonTopHighlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.1),
        ],
        stops: [0, 0.5, 1],
      ).createShader(Offset.zero & size);

    canvas.drawLine(const Offset(4, 0.1), Offset(size.width - 4, 0.1), paint);
  }

  @override
  bool shouldRepaint(_MemberPointsButtonTopHighlightPainter oldDelegate) =>
      false;
}
