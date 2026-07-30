import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../../../../app/router/route_paths.dart';
import '../../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../../core/auth/user_info_store.dart';
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

class _RewardsCoinsPageState extends ConsumerState<RewardsCoinsPage> {
  @override
  void initState() {
    super.initState();
    _refreshIfNeeded();
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
          10,
          8,
          10,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          _BalanceHeader(
            balance: entitlement.coinBalance + entitlement.bonusBalance,
          ),
          if (rewardCoinsState.isCheckInLoading)
            const _RewardsSectionLoading(
              key: Key('rewards_coins_check_in_loading'),
            )
          else if (rewardCoinsState.checkInError != null)
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
                onCheckIn: () => _claimCheckIn(context),
              )
          else
            const _RewardsSectionNoData(
              key: Key('rewards_coins_check_in_empty'),
            ),
          const SizedBox(height: 20),
          Text(
            context.l10n.rewardsTabRewardTaskTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final task in supportedTasks) ...[
            const SizedBox(height: 8),
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

  Future<void> _claimCheckIn(BuildContext context) async {
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
        if (!_hasNotificationPermission(currentStatus)) {
          if (currentStatus.isPermanentlyDenied) {
            await permissions.openAppSettings();
          } else {
            final requestedStatus = await permissions.Permission.notification
                .request();
            if (!_hasNotificationPermission(requestedStatus)) {
              await permissions.openAppSettings();
            }
          }
        }
        await ref
            .read(startupNotificationPermissionReporterProvider)
            .syncForAccount(ref.read(userInfoStoreProvider).showId);
        if (mounted) {
          await ref.read(rewardCoinsControllerProvider.notifier).loadTasks();
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
      showRewardCoinsClaimSuccessToast(result!.rewardAmount);
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
      height: 102,
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 33,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$balance',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  context.l10n.rewardsCoinBalanceCurrent,
                  style: TextStyle(
                    color: Color(0xFF756A57),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 1,
            bottom: -30,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/rewards/coins_icon.png',
                  width: 142,
                  height: 142,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  bottom: 26,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: 142,
                    height: 29,
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
    return const SizedBox(
      height: 96,
      child: Center(child: CircularProgressIndicator()),
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
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
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
          fontSize: 14,
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
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
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
  final VoidCallback onCheckIn;

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
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
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
                      checkInStatus.currentDay,
                    ),
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    context.l10n.rewardsRuleEntry,
                    style: TextStyle(color: Color(0xFFAAA49D), fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildDayWidgets(days, checkInStatus.currentDay),
          ),
          const SizedBox(height: 17),
          GestureDetector(
            key: const Key('rewards_coins_sign_in'),
            behavior: HitTestBehavior.opaque,
            onTap: canCheckIn ? onCheckIn : null,
            child: Container(
              width: double.infinity,
              height: 44,
              margin: EdgeInsetsGeometry.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: canCheckIn ? null : _disabledButton,
                borderRadius: BorderRadius.circular(5),
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
                      fontSize: 16,
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
        if (index > 0) const SizedBox(width: 4),
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
              height: 67,
              width: 44,
              decoration: BoxDecoration(
                color: checked
                    ? const Color(0xFF373737)
                    : const Color(0xFFAF6E37),
                borderRadius: BorderRadius.circular(4),
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
                      width: 24,
                      height: 24,
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
                      width: 24,
                      height: 24,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '+$rewardCoin',
                    style: TextStyle(
                      color: checked ? const Color(0xFF8C8D91) : Colors.white,
                      fontSize: 14,
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
        const SizedBox(height: 7),
        if (checked)
          SizedBox(
            height: 13,
            width: 12,
            child: Image.asset("assets/images/rewards/check.png"),
          )
        else
          Text(
            context.l10n.rewardsSigninDayIndex(day),
            maxLines: 1,
            style: TextStyle(
              color: active ? Colors.white : _muted,
              fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(imagePath, width: 32, height: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
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
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: task.claimed ? const Color(0xFF696A6E) : null,
              gradient: task.claimed
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFD4864E), Color(0xFFFFF0BE)],
                    ),
              borderRadius: BorderRadius.circular(4),
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
                  borderRadius: BorderRadius.circular(4),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: task.claimed
                              ? Colors.white.withValues(alpha: 0.6)
                              : _goldButtonText,
                          fontSize: 12,
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
