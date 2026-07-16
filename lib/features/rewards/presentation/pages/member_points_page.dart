import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/toast/app_center_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/member_points_controller.dart';
import '../../domain/member_point_daily_detail.dart';
import '../../domain/member_point_exchange_options.dart';
import '../widget/member_points_claim_success_dialog.dart';
import '../widget/member_points_exchange_confirm_dialog.dart';
import '../widget/reward_rules_sheet.dart';

const _purple = Color(0xFF8800FF);
const _titleColor = Color(0xFFECC2FF);
const _bodyColor = Color(0xFFF3EAF6);
const _mutedColor = Color(0xFF8D7197);

BoxDecoration _dailyRewardsContentDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(7),
  border: GradientBoxBorder(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0XFFDA8AFF).withValues(alpha: 0.3),
        const Color(0XFF585858).withValues(alpha: 0.3),
      ],
    ),
  ),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.35],
    colors: [
      const Color(0xFF4D0071).withValues(alpha: 0.3),
      const Color(0xFF130719).withValues(alpha: 0.7),
    ],
  ),
);

/// Member Points 独立页面。
///
/// [isMember] 只用于独立预览与测试；生产环境默认读取全局 entitlement 会员状态。
class MemberPointsPage extends ConsumerStatefulWidget {
  const MemberPointsPage({
    this.isMember,
    this.isActive = true,
    this.useParentBackground = false,
    super.key,
  });

  final bool? isMember;
  final bool isActive;
  final bool useParentBackground;

  @override
  ConsumerState<MemberPointsPage> createState() => _MemberPointsPageState();
}

class _MemberPointsPageState extends ConsumerState<MemberPointsPage> {
  @override
  void initState() {
    super.initState();
    _refreshIfNeeded();
  }

  @override
  void didUpdateWidget(MemberPointsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refreshIfNeeded();
    }
  }

  void _refreshIfNeeded() {
    if (!widget.isActive || widget.isMember != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      ref.read(memberPointsControllerProvider.notifier).loadDailyDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementControllerProvider);
    final memberPoints = widget.isMember == null
        ? ref.watch(memberPointsControllerProvider)
        : const MemberPointsState();
    final dailyDetail = memberPoints.data;
    final exchangeOptions = memberPoints.exchangeOptions;
    final l10n = AppLocalizations.maybeOf(context);
    final isMember = widget.isMember ?? entitlement.isMember;
    // final isMember = false;

    return DecoratedBox(
      key: const Key('member_points_page'),
      decoration: BoxDecoration(
        gradient: widget.useParentBackground
            ? null
            : const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF390E4E), Color(0xFF0E0D0F)],
                stops: [0, 0.33],
              ),
      ),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _DailyRewardsPanel(
              isMember: isMember,
              dailyDetail: dailyDetail,
            ),
          ),
          if (isMember) ...[
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: _MemberTasksPanel(
                isMember: isMember,
                tasks: dailyDetail?.tasks,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _RedeemPointsPanel(
              isMember: isMember,
              exchangeOptions: exchangeOptions,
            ),
          ),
          const SizedBox(height: 16),
          if (isMember)
            Container(
              padding: EdgeInsets.fromLTRB(10, 24, 10, 0),
              decoration: BoxDecoration(
                color: Color(0XFF0E0016),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: _RecommendationsPanel(
                title: l10n.memberCenterSectionVipDramas,
              ),
            )
          else
            const _VipSeriesPanel(),
        ],
      ),
    );
  }
}

class _DailyRewardsPanel extends StatelessWidget {
  const _DailyRewardsPanel({required this.isMember, this.dailyDetail});

  final bool isMember;
  final MemberPointDailyDetail? dailyDetail;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: TextButton(
            key: const Key('daily_rewards_rules_button'),
            onPressed: () => showRewardRulesSheet(
              context,
              copy: RewardRulesCopy.memberPoints,
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(58, 30),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              foregroundColor: const Color(0xFFB8A7BE),
              backgroundColor: const Color(0xFF33213A),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            child: Text(
              AppLocalizations.maybeOf(context).memberPointsRule,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight(400)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: ClipRRect(
            key: const Key('daily_rewards_card'),
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0XFF1B1024),
                borderRadius: BorderRadius.circular(8),
                border: GradientBoxBorder(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // 两种状态高度不同，分别换算 stop，保持约 72px 的渐变距离。
                    stops: [0, isMember ? 0.32 : 0.2],
                    colors: [
                      const Color(0XFFDA8AFF).withValues(alpha: 0.25),
                      const Color(0XFFDA8AFF).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              child: Column(
                children: [
                  _PanelHeader(
                    title:
                        '${AppLocalizations.maybeOf(context).memberPointsDailyRewardTitle} >',
                    trailingPoints: '${dailyDetail?.totalPointBalance ?? 0}',
                    onTap: () => context.push(RoutePaths.memberPointDetails),
                  ),
                  isMember
                      ? _MemberDailyRewards(dailyDetail: dailyDetail)
                      : const _LockedDailyRewards(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedDailyRewards extends StatelessWidget {
  const _LockedDailyRewards();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);

    return Container(
      key: const Key('member_points_locked_daily'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 9, 0, 0),
      padding: const EdgeInsets.fromLTRB(17, 24, 17, 16),
      decoration: _dailyRewardsContentDecoration(),
      child: Column(
        children: [
          Image.asset(
            'assets/images/rewards/points_lock_icon.png',
            width: 24,
            height: 24,
          ),
          const SizedBox(height: 7),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(0XFFCE99FF), Color(0XFFEBD5FF), Color(0XFFCE99FF)],
            ).createShader(bounds),
            child: Text(
              l10n.memberPointsLockedDailyReward,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.memberPointsPaidMemberOnly,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight(400),
            ),
          ),
          const SizedBox(height: 33),
          Row(
            children: [
              Expanded(
                child: _RewardFeatureTile(
                  imagePath: 'assets/images/rewards/points_daily.png',
                  label: l10n.memberPointsDailyPoints,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RewardFeatureTile(
                  imagePath: 'assets/images/rewards/points_free.png',
                  label: l10n.memberPointsFreeMembership,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MemberPointsActionButton(
                  key: const Key('member_points_join_now'),
                  label: l10n.membershipBuyNow,
                  fontSize: 16,
                  boxPadding: EdgeInsetsGeometry.symmetric(vertical: 10),
                  fontWeight: FontWeight.w600,
                  onTap: () => context.push(RoutePaths.membership),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardFeatureTile extends StatelessWidget {
  const _RewardFeatureTile({required this.imagePath, required this.label});

  final String imagePath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        image: DecorationImage(
          alignment: Alignment(0.0, -0.7),
          image: AssetImage("assets/images/rewards/v_purple.png"),
        ),
        border: GradientBoxBorder(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0XFFDA8AFF).withValues(alpha: 0.3),
              const Color(0XFF585858).withValues(alpha: 0.3),
            ],
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0XFF380053), const Color(0XFF130719)],
        ),
      ),
      child: Column(
        children: [
          Expanded(child: Image.asset(imagePath, fit: BoxFit.contain)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MemberDailyRewards extends StatelessWidget {
  const _MemberDailyRewards({this.dailyDetail});

  final MemberPointDailyDetail? dailyDetail;

  @override
  Widget build(BuildContext context) {
    final progress = _resolvedDayProgress(dailyDetail?.dayProgress);
    final currentIndex = _currentProgressIndex(progress);
    final l10n = AppLocalizations.maybeOf(context);

    return Container(
      key: const Key('member_points_active_daily'),
      margin: const EdgeInsets.fromLTRB(0, 9, 0, 0),
      padding: const EdgeInsets.fromLTRB(17, 24, 17, 16),
      decoration: _dailyRewardsContentDecoration(),
      child: Column(
        children: [
          Text(
            l10n.memberPointsMemberDayCount(dailyDetail?.memberDay ?? 7),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _titleColor,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _DailyPointsRow(progress: progress, currentIndex: currentIndex),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 22,
            child: CustomPaint(
              key: const Key('member_daily_rewards_progress'),
              painter: _DailyRewardsProgressPainter(
                itemCount: progress.length,
                currentIndex: currentIndex,
              ),
            ),
          ),
          const SizedBox(height: 7),
          _DailyLabelsRow(progress: progress, currentIndex: currentIndex),
        ],
      ),
    );
  }
}

class _DailyPointsRow extends StatelessWidget {
  const _DailyPointsRow({required this.progress, required this.currentIndex});

  final List<MemberPointDayProgress> progress;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < progress.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: _DailyPoint(
              day: progress[index].memberDay,
              points: progress[index].claimedPoint,
              status: _dailyProgressStatus(
                item: progress[index],
                currentIndex: currentIndex,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DailyLabelsRow extends StatelessWidget {
  const _DailyLabelsRow({required this.progress, required this.currentIndex});

  final List<MemberPointDayProgress> progress;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < progress.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: _DailyLabel(
              day: progress[index].memberDay,
              status: _dailyProgressStatus(
                item: progress[index],
                currentIndex: currentIndex,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

const _defaultDayProgress = [
  MemberPointDayProgress(
    claimedPoint: 10,
    current: false,
    index: 1,
    memberDay: 1,
    totalPoint: 10,
  ),
  MemberPointDayProgress(
    claimedPoint: 0,
    current: true,
    index: 2,
    memberDay: 2,
    totalPoint: 10,
  ),
  MemberPointDayProgress(
    claimedPoint: 0,
    current: false,
    index: 3,
    memberDay: 3,
    totalPoint: 10,
  ),
  MemberPointDayProgress(
    claimedPoint: 0,
    current: false,
    index: 4,
    memberDay: 4,
    totalPoint: 10,
  ),
  MemberPointDayProgress(
    claimedPoint: 0,
    current: false,
    index: 5,
    memberDay: 5,
    totalPoint: 10,
  ),
];

List<MemberPointDayProgress> _resolvedDayProgress(
  List<MemberPointDayProgress>? progress,
) {
  if (progress == null || progress.isEmpty) return _defaultDayProgress;
  return _sortedDayProgress(progress);
}

int _currentProgressIndex(List<MemberPointDayProgress> progress) {
  return progress.where((item) => item.current).firstOrNull?.index ??
      progress.first.index;
}

List<MemberPointDayProgress> _sortedDayProgress(
  List<MemberPointDayProgress> progress,
) {
  return [...progress]..sort((a, b) => a.index.compareTo(b.index));
}

_DailyProgressStatus _dailyProgressStatus({
  required MemberPointDayProgress item,
  required int currentIndex,
}) {
  if (item.current) return _DailyProgressStatus.current;
  if (item.index < currentIndex) return _DailyProgressStatus.past;
  return _DailyProgressStatus.future;
}

enum _DailyProgressStatus { past, current, future }

class _DailyPoint extends StatelessWidget {
  const _DailyPoint({
    required this.day,
    required this.status,
    this.points = 10,
  });

  final int day;
  final int points;
  final _DailyProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final isPast = status == _DailyProgressStatus.past;
    final isCurrent = status == _DailyProgressStatus.current;
    final opacity = switch (status) {
      _DailyProgressStatus.past => 0.32,
      _DailyProgressStatus.current => 1.0,
      _DailyProgressStatus.future => 0.68,
    };

    return Opacity(
      opacity: opacity,
      child: Container(
        key: Key('member_daily_reward_day_$day'),
        height: 78,
        decoration: BoxDecoration(
          gradient: isCurrent
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7600AC), Color(0xFF1F0829)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF380053), Color(0xFF130719)],
                ),
          borderRadius: BorderRadius.circular(8),
          border: GradientBoxBorder(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0XFFDA8AFF).withValues(alpha: 0.3),
                const Color(0XFF585858).withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPast)
              const Icon(Icons.check_rounded, color: _titleColor, size: 26)
            else
              Image.asset(
                'assets/images/rewards/points_icon.png',
                width: 28,
                height: 28,
              ),
            const SizedBox(height: 10),
            Text(
              _pointsText,
              style: TextStyle(
                color: Color(0XFF9D64DD),
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _pointsText {
    if (status == _DailyProgressStatus.past || points > 0) {
      return '+$points';
    }
    return '??';
  }
}

class _DailyLabel extends StatelessWidget {
  const _DailyLabel({required this.day, required this.status});

  final int day;
  final _DailyProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final opacity = switch (status) {
      _DailyProgressStatus.past => 0.2,
      _DailyProgressStatus.current => 1.0,
      _DailyProgressStatus.future => 0.58,
    };
    return Text(
      AppLocalizations.maybeOf(context).rewardsSigninDayIndex(day),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DailyRewardsProgressPainter extends CustomPainter {
  const _DailyRewardsProgressPainter({
    required this.itemCount,
    required this.currentIndex,
  });

  final int itemCount;
  final int currentIndex;

  static const _activeColor = Color(0xFF8E32FF);
  static const _inactiveColor = Color(0xFF302635);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final count = itemCount <= 0 ? 1 : itemCount;
    final currentPosition = (currentIndex - 1).clamp(0, count - 1).toInt();
    final centerY = size.height / 2;
    final step = size.width / count;
    final centers = List.generate(count, (index) => step * (index + 0.5));
    final linePaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      linePaint..color = _inactiveColor,
    );
    canvas.drawLine(
      Offset(0, centerY),
      Offset(centers[currentPosition], centerY),
      linePaint..color = _activeColor,
    );

    for (var index = 0; index < centers.length; index++) {
      final center = Offset(centers[index], centerY);
      if (index < currentPosition) {
        _drawRoundedDiamond(
          canvas,
          center,
          radius: 8,
          cornerRadius: 2.4,
          fillColor: _activeColor,
        );
      } else if (index == currentPosition) {
        _drawRoundedDiamond(
          canvas,
          center,
          radius: 9.5,
          cornerRadius: 2.5,
          fillColor: const Color(0xFF24002F),
          strokeColor: _activeColor,
          strokeWidth: 2,
        );

        final glowBounds = Rect.fromCircle(center: center, radius: 7);
        canvas.drawCircle(
          center,
          7,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0x99FFFFFF), Color(0x668F00FF), Color(0x008F00FF)],
              stops: [0, 0.46, 1],
            ).createShader(glowBounds),
        );
        _drawRoundedDiamond(
          canvas,
          center,
          radius: 5,
          cornerRadius: 1.5,
          fillShader: const RadialGradient(
            colors: [Color(0xFFE0C6FF), Color(0xFF8E32FF)],
            stops: [0.1, 0.8],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 5)),
        );
      } else {
        _drawRoundedDiamond(
          canvas,
          center,
          radius: 7,
          cornerRadius: 2,
          fillColor: const Color(0xFF170E1C),
          strokeColor: _inactiveColor,
          strokeWidth: 2,
        );
      }
    }
  }

  void _drawRoundedDiamond(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double cornerRadius,
    Color? fillColor,
    Shader? fillShader,
    Color? strokeColor,
    double strokeWidth = 1,
  }) {
    // 正方形旋转 45° 后得到菱形；使用 RRect 可让四个角拥有一致圆角。
    final halfSide = radius * 0.70710678118;
    final rect = Rect.fromLTRB(-halfSide, -halfSide, halfSide, halfSide);
    final roundedRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(cornerRadius),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.78539816339);
    canvas.drawRRect(
      roundedRect,
      Paint()
        ..color = fillColor ?? Colors.white
        ..shader = fillShader,
    );
    if (strokeColor != null) {
      canvas.drawRRect(
        roundedRect,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DailyRewardsProgressPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount ||
        oldDelegate.currentIndex != currentIndex;
  }
}

class _MemberTasksPanel extends ConsumerWidget {
  const _MemberTasksPanel({required this.isMember, this.tasks});

  final bool isMember;
  final List<MemberPointTask>? tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.maybeOf(context);
    final items = _memberTaskItems(tasks, l10n);

    return _OutlinedPanel(
      beginAlign: Alignment.topLeft,
      endAlign: Alignment.bottomRight,
      boxGradientColor: isMember
          ? [Color(0XFF28003B), Color(0XFF0E0513)]
          : null,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            _ActionRow(
              keySuffix: items[index].keySuffix,
              title: items[index].title,
              note: items[index].note,
              points: items[index].points,
              action: items[index].task.claimed ? l10n.claimed : l10n.claim,
              disabled: items[index].task.claimed,
              onTap: () => _handleTaskTap(context, ref, items[index]),
            ),
          ],
        ],
      ),
    );
  }

  List<_MemberTaskItem> _memberTaskItems(
    List<MemberPointTask>? source,
    AppLocalizations l10n,
  ) {
    final sourceTasks = source ?? _previewTasks;
    if (sourceTasks.isEmpty) return const [];

    final items = <_MemberTaskItem>[];
    final dailyDraw = _firstTaskForKeys(sourceTasks, const [
      'point.draw.first',
      'point.draw.daily',
    ]);
    if (dailyDraw != null) {
      items.add(
        _MemberTaskItem(
          keySuffix: 'daily_lottery_draw',
          title: l10n.memberPointsDailyLottery,
          points: _memberTaskPointsText(dailyDraw),
          task: dailyDraw,
          actionType: _MemberTaskActionType.dailyDraw,
        ),
      );
    }

    final watch = _firstTaskForKeys(sourceTasks, const ['point.watch.30m']);
    if (watch != null) {
      items.add(
        _MemberTaskItem(
          keySuffix: 'play_reward',
          title: l10n.memberPointsPlayReward,
          note: l10n.memberPointsWatchOver30Min,
          points: _memberTaskPointsText(watch),
          task: watch,
          actionType: _MemberTaskActionType.watch30m,
        ),
      );
    }

    final push = _firstTaskForKeys(sourceTasks, const ['point.enable_push']);
    if (push != null) {
      items.add(
        _MemberTaskItem(
          keySuffix: 'enable_push',
          title: l10n.memberPointsDetailTypePush,
          points: _memberTaskPointsText(push),
          task: push,
          actionType: _MemberTaskActionType.enablePush,
        ),
      );
    }

    return items;
  }

  MemberPointTask? _firstTaskForKeys(
    List<MemberPointTask> tasks,
    List<String> keys,
  ) {
    for (final key in keys) {
      final task = tasks.where((task) => task.taskKey == key).firstOrNull;
      if (task != null) return task;
    }
    return null;
  }

  String _memberTaskPointsText(MemberPointTask task) {
    if (task.claimed) return '+${task.claimedRewardAmount}';
    if (task.rewardMin != task.rewardMax) return '+??';
    return '+${task.rewardMin}';
  }

  Future<void> _handleTaskTap(
    BuildContext context,
    WidgetRef ref,
    _MemberTaskItem item,
  ) async {
    if (item.task.claimed) return;

    switch (item.actionType) {
      case _MemberTaskActionType.dailyDraw:
        await _claimTask(context, ref, item.task.taskKey);
      case _MemberTaskActionType.watch30m:
        showAppCenterToast(
          AppLocalizations.maybeOf(context).memberPointsWatchOver30Min,
        );
      case _MemberTaskActionType.enablePush:
        final granted = await _requestNotificationPermission();
        if (!context.mounted || !granted) return;
        await _claimTask(context, ref, item.task.taskKey);
    }
  }

  Future<void> _claimTask(
    BuildContext context,
    WidgetRef ref,
    String taskKey,
  ) async {
    try {
      final result = await ref
          .read(memberPointsControllerProvider.notifier)
          .claimReward(taskKey: taskKey);
      if (!context.mounted || result?.isSuccess != true) return;
      await showMemberPointsClaimSuccessDialog(
        context,
        rewardAmount: result!.rewardAmount,
      );
    } catch (_) {
      if (!context.mounted) return;
      showAppCenterToast(AppLocalizations.maybeOf(context).networkError);
    }
  }
}

Future<bool> _requestNotificationPermission() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  } catch (_) {
    return false;
  }
}

enum _MemberTaskActionType { dailyDraw, watch30m, enablePush }

class _MemberTaskItem {
  const _MemberTaskItem({
    required this.keySuffix,
    required this.title,
    required this.points,
    required this.task,
    required this.actionType,
    this.note,
  });

  final String keySuffix;
  final String title;
  final String? note;
  final String points;
  final MemberPointTask task;
  final _MemberTaskActionType actionType;
}

const _previewTasks = [
  MemberPointTask(
    canClaim: false,
    claimed: false,
    claimedRewardAmount: 0,
    completed: false,
    conditionText: '',
    displayName: 'Daily lottery draw',
    progressValue: 0,
    rewardMax: 0,
    rewardMin: 0,
    targetValue: 0,
    taskKey: 'point.draw.daily',
  ),
  MemberPointTask(
    canClaim: false,
    claimed: false,
    claimedRewardAmount: 0,
    completed: false,
    conditionText: '',
    displayName: 'Play reward',
    progressValue: 0,
    rewardMax: 50,
    rewardMin: 50,
    targetValue: 30,
    taskKey: 'point.watch.30m',
  ),
  MemberPointTask(
    canClaim: false,
    claimed: false,
    claimedRewardAmount: 0,
    completed: false,
    conditionText: '',
    displayName: 'Turn push notification',
    progressValue: 0,
    rewardMax: 10,
    rewardMin: 10,
    targetValue: 1,
    taskKey: 'point.enable_push',
  ),
];

class _RedeemPointsPanel extends ConsumerWidget {
  const _RedeemPointsPanel({required this.isMember, this.exchangeOptions});

  final bool isMember;
  final MemberPointExchangeOptions? exchangeOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = _exchangeTiers(exchangeOptions);
    final canRedeemAsMember = isMember && (exchangeOptions?.isMember ?? true);
    final l10n = AppLocalizations.maybeOf(context);

    return _OutlinedPanel(
      boxColor: Color(0XFF130719),
      beginAlign: Alignment.topLeft,
      endAlign: Alignment.bottomRight,
      borderColor: [
        Color(0XFFDA8AFF).withValues(alpha: 0.3),
        Color(0XFF585858).withValues(alpha: 0.3),
      ],
      boxGradientColor: isMember
          ? [Color(0XFF28003B), Color(0XFF0E0513)]
          : null,
      child: Column(
        children: [
          isMember
              ? Container()
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0XFF4D0071), Color(0XFF130719)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _PanelHeader(
                        title: l10n.memberCenterRedeemPoints,
                        showRules: true,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 14, 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.memberPointsPaidMemberOnly,
                            style: TextStyle(
                              color: _mutedColor,
                              fontSize: 10,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          for (var index = 0; index < tiers.length; index++) ...[
            if (index > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            _ActionRow(
              keySuffix: 'redeem_${tiers[index].tierId}',
              title: _redeemTitle(tiers[index].memberDays, l10n),
              points: '${tiers[index].pointCost}',
              action: l10n.memberCenterButtonExchange,
              disabled: !canRedeemAsMember || !tiers[index].canExchange,
              onTap: () => _confirmExchange(context, ref, tiers[index]),
            ),
          ],
        ],
      ),
    );
  }

  List<MemberPointExchangeTier> _exchangeTiers(
    MemberPointExchangeOptions? options,
  ) {
    final source = options?.list ?? _previewExchangeTiers;
    return [...source]..sort((a, b) => a.priority.compareTo(b.priority));
  }

  String _redeemTitle(int memberDays, AppLocalizations l10n) {
    return l10n.memberCenterExchangeDaysMember(memberDays);
  }

  Future<void> _confirmExchange(
    BuildContext context,
    WidgetRef ref,
    MemberPointExchangeTier tier,
  ) async {
    final confirmed = await showMemberPointsExchangeConfirmDialog(
      context,
      memberDays: tier.memberDays,
      pointCost: tier.pointCost,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final result = await ref
          .read(memberPointsControllerProvider.notifier)
          .exchange(tierId: tier.tierId);
      if (!context.mounted || result == null) return;
      final l10n = AppLocalizations.maybeOf(context);
      showAppCenterToast(
        result.isSuccess ? l10n.memberCenterExchangeSuccess : l10n.networkError,
      );
    } catch (_) {
      if (!context.mounted) return;
      showAppCenterToast(AppLocalizations.maybeOf(context).networkError);
    }
  }
}

const _previewExchangeTiers = [
  MemberPointExchangeTier(
    canExchange: false,
    displayName: 'Redeem 1-Day Membership',
    exchangeStatus: 'insufficient_points',
    memberDays: 1,
    pointCost: 500,
    priority: 1,
    status: 1,
    tierId: 1,
  ),
  MemberPointExchangeTier(
    canExchange: true,
    displayName: 'Redeem 5-Day Membership',
    exchangeStatus: 'available',
    memberDays: 5,
    pointCost: 1000,
    priority: 2,
    status: 1,
    tierId: 2,
  ),
];

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    this.trailingPoints,
    this.showRules = false,
    this.onTap,
  });

  final String title;
  final String? trailingPoints;
  final bool showRules;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: onTap == null
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: showRules ? 0.8 : 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showRules)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showRewardRulesSheet(
                  context,
                  copy: RewardRulesCopy.memberPoints,
                ),
                child: const _RulesPill(),
              )
            else if (trailingPoints != null) ...[
              Image.asset(
                'assets/images/rewards/points_icon.png',
                width: 26,
                height: 26,
              ),
              const SizedBox(width: 3),
              Text(
                trailingPoints!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RulesPill extends StatelessWidget {
  const _RulesPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        AppLocalizations.maybeOf(context).rewardsRuleEntry,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight(510),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.points,
    required this.action,
    this.keySuffix,
    this.note,
    this.disabled = false,
    this.onTap,
  });

  final String title;
  final String? keySuffix;
  final String? note;
  final String points;
  final String action;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note == null)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                else
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        TextSpan(text: '$title '),
                        TextSpan(
                          text: note,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/rewards/points_icon.png',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      points,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MemberPointsActionButton(
            key: Key(
              'member_points_action_${keySuffix ?? title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
            ),
            label: action,
            disabled: disabled,
            onTap: onTap ?? () {},
          ),
        ],
      ),
    );
  }
}

class _MemberPointsActionButton extends StatelessWidget {
  const _MemberPointsActionButton({
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
    super.key,
    this.boxPadding,
  });

  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry? boxPadding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF615668) : _purple,
          borderRadius: BorderRadius.circular(4),
          border: disabled
              ? null
              : const GradientBoxBorder(
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
                ),
        ),
        child: CustomPaint(
          key: const Key('member_points_button_top_highlight'),
          foregroundPainter: disabled
              ? null
              : const _MemberPointsButtonTopHighlightPainter(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onTap,
              borderRadius: BorderRadius.circular(4),
              splashColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.04),
              child: Padding(
                padding:
                    boxPadding ??
                    EdgeInsetsGeometry.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: disabled
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma border-image-source 的第二层顶部中央高光。
///
/// 原始径向渐变宽度为 25.51%，中心位于 50% 0%。边框只有 1px 高，
/// 因此在顶部边线上绘制同宽度的横向渐隐高光即可还原其可见结果。
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
          Colors.transparent,
          Colors.white.withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: [0, 0.5, 1],
      ).createShader(Offset.zero & size);

    canvas.drawLine(const Offset(4, 0.5), Offset(size.width - 4, 0.5), paint);
  }

  @override
  bool shouldRepaint(_MemberPointsButtonTopHighlightPainter oldDelegate) =>
      false;
}

class _VipBenefitsPanel extends StatelessWidget {
  const _VipBenefitsPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);
    final benefits = [
      (
        'assets/images/rewards/points_series.png',
        l10n.benefitSeriesTitle,
        l10n.benefitSeriesHighlight,
      ),
      ('assets/images/rewards/points_download.png', l10n.benefitDownload, null),
      (
        'assets/images/rewards/points_dramas.png',
        l10n.benefitMembersOnly,
        null,
      ),
      ('assets/images/rewards/points_hd.png', l10n.benefitHd, null),
    ];

    return ClipRRect(
      key: const Key('vip_benefits_panel'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: ColoredBox(
        color: const Color(0xFF0E0016),
        child: CustomPaint(
          key: const Key('vip_benefits_top_border'),
          foregroundPainter: _VipBenefitsTopBorderPainter(
            color: Color(0XFFDA8AFF).withValues(alpha: 0.4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Column(
              children: [
                _SectionTitle(title: l10n.membershipBenefits),
                const SizedBox(height: 24),
                for (var index = 0; index < benefits.length; index++) ...[
                  Row(
                    children: [
                      Image.asset(benefits[index].$1, width: 30, height: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _VipBenefitTitle(
                              text: benefits[index].$2,
                              highlight: index == 0 ? '8000+' : null,
                            ),
                            if (benefits[index].$3 != null)
                              Text(
                                benefits[index].$3!,
                                style: TextStyle(
                                  color: _titleColor.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (index < benefits.length - 1) const SizedBox(height: 15),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VipBenefitTitle extends StatelessWidget {
  const _VipBenefitTitle({required this.text, this.highlight});

  final String text;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: _titleColor.withValues(alpha: 0.6),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final highlightText = highlight;
    if (highlightText == null || highlightText.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final parts = text.split(highlightText);
    if (parts.length == 1) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          for (var index = 0; index < parts.length; index++) ...[
            if (parts[index].isNotEmpty) TextSpan(text: parts[index]),
            if (index < parts.length - 1)
              TextSpan(
                text: highlightText,
                style: const TextStyle(color: _titleColor),
              ),
          ],
        ],
      ),
    );
  }
}

class _VipSeriesPanel extends StatelessWidget {
  const _VipSeriesPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);

    return Column(
      children: [
        const _VipBenefitsPanel(),
        const Divider(height: 1, thickness: 1, color: Color(0x4D5A1B72)),
        ColoredBox(
          color: const Color(0xFF0E0016),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
            child: _RecommendationsPanel(
              title: l10n.memberCenterSectionVipDramas,
            ),
          ),
        ),
      ],
    );
  }
}

class _VipBenefitsTopBorderPainter extends CustomPainter {
  const _VipBenefitsTopBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const borderHeight = 33.0;
    const curveWidth = 54.0;

    final path = Path()
      ..moveTo(0.5, borderHeight)
      ..quadraticBezierTo(0.5, 0.5, curveWidth, 0.5)
      ..lineTo(size.width - curveWidth, 0.5)
      ..quadraticBezierTo(
        size.width - 0.5,
        0.5,
        size.width - 0.5,
        borderHeight,
      );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0XFF585858).withValues(alpha: 0.3),
          Color(0XFFDA8AFF).withValues(alpha: 0.4),
          Color(0XFF585858).withValues(alpha: 0.3),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VipBenefitsTopBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RecommendationsPanel extends StatelessWidget {
  const _RecommendationsPanel({required this.title});

  final String title;

  static const _cardWidth = 116.0;
  static const _coverAspectRatio = 0.68;
  static const _listHeight = _cardWidth / _coverAspectRatio + 6 + 24;

  static const covers = [
    ('assets/images/membership/1.png', 'Fallin Love With\nEx\'s Uncle'),
    ('assets/images/membership/2.png', 'Wolf Queen Rises'),
    ('assets/images/membership/3.png', 'Fake Dating My\nRich Nemesis'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _listHeight,
          child: ListView.separated(
            key: const Key('member_points_recommendations_list'),
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: covers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return SizedBox(
                width: _cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: _coverAspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.asset(covers[index].$1, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      covers[index].$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 10,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _titleColor.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _titleColor, fontSize: 14),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _titleColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlinedPanel extends StatelessWidget {
  const _OutlinedPanel({
    required this.child,
    this.beginAlign,
    this.endAlign,
    this.boxColor,
    this.borderColor,
    this.boxGradientColor,
  });

  final Widget child;
  final AlignmentGeometry? beginAlign;
  final AlignmentGeometry? endAlign;
  final Color? boxColor;
  final List<Color>? borderColor;
  final List<Color>? boxGradientColor;

  @override
  Widget build(BuildContext context) {
    final backgroundGradientColors = boxGradientColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        // DecoratedBox 不会像带 border 的 Container 一样把 child 向内缩进。
        // 因此外框先绘制，内部区域随后在相同坐标绘制自己的边框，两种颜色
        // 得以保留，同时左右和底部不会出现并排的双线。
        decoration: BoxDecoration(
          color: boxColor ?? const Color(0XFF1B1024),
          borderRadius: BorderRadius.circular(7),
          border: GradientBoxBorder(
            gradient: LinearGradient(
              begin: beginAlign ?? Alignment.topCenter,
              end: endAlign ?? Alignment.bottomCenter,
              colors: borderColor ?? [Color(0XFF4F2464), Color(0XFF242027)],
            ),
          ),
          gradient:
              backgroundGradientColors != null &&
                  backgroundGradientColors.length >= 2
              ? LinearGradient(colors: backgroundGradientColors)
              : null,
        ),
        child: child,
      ),
    );
  }
}
