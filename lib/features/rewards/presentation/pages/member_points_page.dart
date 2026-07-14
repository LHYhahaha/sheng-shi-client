import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

import '../../../../app/router/route_paths.dart';
import '../../../entitlement/application/entitlement_controller.dart';

const _panelBorder = Color(0xFF5A1B72);
const _purple = Color(0xFF8800FF);
const _titleColor = Color(0xFFECC2FF);
const _bodyColor = Color(0xFFF3EAF6);
const _mutedColor = Color(0xFF8D7197);

/// Member Points 独立页面。
///
/// [isMember] 只用于独立预览与测试；生产环境默认读取全局 entitlement 会员状态。
class MemberPointsPage extends ConsumerStatefulWidget {
  const MemberPointsPage({
    this.isMember,
    this.useParentBackground = false,
    super.key,
  });

  final bool? isMember;
  final bool useParentBackground;

  @override
  ConsumerState<MemberPointsPage> createState() => _MemberPointsPageState();
}

class _MemberPointsPageState extends ConsumerState<MemberPointsPage> {
  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementControllerProvider);
    // final isMember = widget.isMember ?? entitlement.isMember;
    final isMember = true;

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
            child: _DailyRewardsPanel(isMember: isMember),
          ),
          if (isMember) ...[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: _MemberTasksPanel(),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _RedeemPointsPanel(isMember: isMember),
          ),
          const SizedBox(height: 16),
          if (isMember)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: _RecommendationsPanel(title: 'Content recommendation'),
            )
          else
            const _VipSeriesPanel(),
        ],
      ),
    );
  }
}

class _DailyRewardsPanel extends StatelessWidget {
  const _DailyRewardsPanel({required this.isMember});

  final bool isMember;

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
            onPressed: () {},
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
            child: const Text(
              'Rules',
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
              // DecoratedBox 不会像带 border 的 Container 一样把 child 向内缩进。
              // 因此外框先绘制，内部区域随后在相同坐标绘制自己的边框，两种颜色
              // 得以保留，同时左右和底部不会出现并排的双线。
              decoration: BoxDecoration(
                color: const Color(0XFF1B1024),
                borderRadius: BorderRadius.circular(8),
                border: GradientBoxBorder(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3],
                    colors: [
                      const Color(0XFFDA8AFF).withValues(alpha: 0.3),
                      const Color(0XFFDA8AFF).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),

              child: Column(
                children: [
                  const _PanelHeader(
                    title: 'Daily Rewards >',
                    trailingPoints: '0',
                  ),
                  isMember
                      ? const _MemberDailyRewards()
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
    return Container(
      key: const Key('member_points_locked_daily'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 9, 0, 0),
      padding: const EdgeInsets.fromLTRB(17, 24, 17, 16),
      decoration: BoxDecoration(
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
          stops: [0, 0.35],
          colors: [
            Color(0xFF4D0071).withValues(alpha: 0.3),
            Color(0xFF130719).withValues(alpha: 0.7),
          ],
        ),
      ),
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
            child: const Text(
              'Subscribe to unlock daily\nrewards',
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
            'Points are for paid members only',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight(400),
            ),
          ),
          const SizedBox(height: 33),
          const Row(
            children: [
              Expanded(
                child: _RewardFeatureTile(
                  imagePath: 'assets/images/rewards/points_daily.png',
                  label: 'Daily Points',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _RewardFeatureTile(
                  imagePath: 'assets/images/rewards/points_free.png',
                  label: 'Free Membership',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _MemberPointsActionButton(
              key: const Key('member_points_join_now'),
              label: 'Join Now',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              onTap: () => context.push(RoutePaths.membership),
            ),
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
  const _MemberDailyRewards();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('member_points_active_daily'),
      margin: const EdgeInsets.fromLTRB(0, 9, 0, 0),
      padding: const EdgeInsets.fromLTRB(17, 24, 17, 16),
      decoration: BoxDecoration(
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.72],
          colors: [Color(0xFF390E4E), Color(0xFF130719)],
        ),
      ),
      child: const Column(
        children: [
          Text(
            "Today is the 7th day as a member",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _titleColor,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _DailyPoint(day: 1, claimed: true)),
              SizedBox(width: 9),
              Expanded(child: _DailyPoint(day: 2, selected: true)),
              SizedBox(width: 9),
              Expanded(child: _DailyPoint(day: 3)),
              SizedBox(width: 9),
              Expanded(child: _DailyPoint(day: 4)),
              SizedBox(width: 9),
              Expanded(child: _DailyPoint(day: 5)),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(
            key: Key('member_daily_rewards_progress'),
            width: double.infinity,
            height: 22,
            child: CustomPaint(painter: _DailyRewardsProgressPainter()),
          ),
          SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _DailyLabel(day: 1)),
              SizedBox(width: 9),
              Expanded(child: _DailyLabel(day: 2, selected: true)),
              SizedBox(width: 9),
              Expanded(child: _DailyLabel(day: 3)),
              SizedBox(width: 9),
              Expanded(child: _DailyLabel(day: 4)),
              SizedBox(width: 9),
              Expanded(child: _DailyLabel(day: 5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyPoint extends StatelessWidget {
  const _DailyPoint({
    required this.day,
    this.claimed = false,
    this.selected = false,
  });

  final int day;
  final bool claimed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final opacity = claimed ? 0.32 : (selected ? 1.0 : 1.0);

    return Opacity(
      opacity: opacity,
      child: Container(
        key: Key('member_daily_reward_day_$day'),
        height: 78,
        decoration: BoxDecoration(
          gradient: selected
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
            if (claimed)
              const Icon(Icons.check_rounded, color: _titleColor, size: 26)
            else
              Image.asset(
                'assets/images/rewards/points_icon.png',
                width: 28,
                height: 28,
              ),
            const SizedBox(height: 10),
            const Text(
              '+10',
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
}

class _DailyLabel extends StatelessWidget {
  const _DailyLabel({required this.day, this.selected = false});

  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      'DAY $day',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: selected ? _titleColor : _mutedColor,
        fontSize: 10,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _DailyRewardsProgressPainter extends CustomPainter {
  const _DailyRewardsProgressPainter();

  static const _activeColor = Color(0xFF8E32FF);
  static const _inactiveColor = Color(0xFF302635);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final centerY = size.height / 2;
    final step = size.width / 5;
    final centers = List.generate(5, (index) => step * (index + 0.5));
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
      Offset(centers[1], centerY),
      linePaint..color = _activeColor,
    );

    for (var index = 0; index < centers.length; index++) {
      final center = Offset(centers[index], centerY);
      if (index == 0) {
        _drawRoundedDiamond(
          canvas,
          center,
          radius: 8,
          cornerRadius: 2.4,
          fillColor: _activeColor,
        );
      } else if (index == 1) {
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
            colors: [
              Color(0xFFE0C6FF),
              Color(0xFF8E32FF),
            ],
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
  bool shouldRepaint(_DailyRewardsProgressPainter oldDelegate) => false;
}

class _MemberTasksPanel extends StatelessWidget {
  const _MemberTasksPanel();

  @override
  Widget build(BuildContext context) {
    return const _OutlinedPanel(
      child: Column(
        children: [
          _ActionRow(
            title: 'Daily lottery draw',
            points: '+??',
            action: 'Claim',
            disabled: true,
          ),
          Divider(height: 1, color: Color(0xFF31113A)),
          _ActionRow(
            title: 'Play reward',
            note: '(More than 30 minutes)',
            points: '+50',
            action: 'Claim',
          ),
        ],
      ),
    );
  }
}

class _RedeemPointsPanel extends StatelessWidget {
  const _RedeemPointsPanel({required this.isMember});

  final bool isMember;

  @override
  Widget build(BuildContext context) {
    return _OutlinedPanel(
      boxColor: Color(0XFF130719),
      beginAlign: Alignment.topLeft,
      endAlign: Alignment.bottomRight,
      borderColor: [
        Color(0XFFDA8AFF).withValues(alpha: 0.3),
        Color(0XFF585858).withValues(alpha: 0.3),
      ],
      child: Column(
        children: [
          isMember
              ? Container()
              : Container(
                  padding: EdgeInsets.only(top: 1),
                  margin: const EdgeInsets.only(left: 1, top: 1, right: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0XFF4D0071), Color(0XFF130719)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _PanelHeader(title: 'Redeem Points', showRules: true),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 14, 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'This redemption extends your membership period only.\nAuto-renewal stays the same.',
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
          _ActionRow(
            title: '1-Day Membership Extension',
            points: '500',
            action: 'Redeem',
            disabled: true,
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          _ActionRow(
            title: '5-Day Membership Extension',
            points: '1000',
            action: 'Redeem',
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    this.trailingPoints,
    this.showRules = false,
  });

  final String title;
  final String? trailingPoints;
  final bool showRules;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            const _RulesPill()
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
        'Rules',
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
    this.note,
    this.disabled = false,
  });

  final String title;
  final String? note;
  final String points;
  final String action;
  final bool disabled;

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
                Text(
                  note == null ? title : '$title $note',
                  style: TextStyle(color: Colors.white, fontSize: 14),
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
          SizedBox(
            width: 88,
            height: 30,
            child: _MemberPointsActionButton(
              key: Key(
                'member_points_action_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
              ),
              label: action,
              disabled: disabled,
              onTap: () {},
            ),
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
    this.fontSize = 10,
    this.fontWeight = FontWeight.w500,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final double fontSize;
  final FontWeight fontWeight;

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
              child: Center(
                child: Text(
                  label,
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

  static const benefits = [
    (
      'assets/images/rewards/points_series.png',
      'Unlimited access to 8,000+ series',
      '55+ fresh dramas every week',
    ),
    ('assets/images/rewards/points_download.png', 'Download', null),
    ('assets/images/rewards/points_dramas.png', 'Members-only dramas', null),
    ('assets/images/rewards/points_hd.png', '1080p quality', null),
  ];

  @override
  Widget build(BuildContext context) {
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
                const _SectionTitle(title: 'VIP Benefits'),
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
                            Text(
                              benefits[index].$2,
                              style: TextStyle(
                                color: _titleColor.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
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

class _VipSeriesPanel extends StatelessWidget {
  const _VipSeriesPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _VipBenefitsPanel(),
        Divider(height: 1, thickness: 1, color: Color(0x4D5A1B72)),
        ColoredBox(
          color: Color(0xFF0E0016),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 24, 10, 0),
            child: _RecommendationsPanel(title: 'Exclusive Series'),
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

    const radius = 50.0;
    final path = Path()
      ..moveTo(0.5, radius)
      ..quadraticBezierTo(0.5, 0.5, radius, 0.5)
      ..lineTo(size.width - radius, 0.5)
      ..quadraticBezierTo(size.width - 0.5, 0.5, size.width - 0.5, radius);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.1),
          color,
          color.withValues(alpha: 0.1),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < covers.length; index++) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 0.68,
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
              ),
              if (index < covers.length - 1) const SizedBox(width: 8),
            ],
          ],
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
  });

  final Widget child;
  final AlignmentGeometry? beginAlign;
  final AlignmentGeometry? endAlign;
  final Color? boxColor;
  final List<Color>? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: DecoratedBox(
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
              colors:
                  borderColor ??
                  [
                    const Color(0XFFDA8AFF).withValues(alpha: 0.3),
                    const Color(0XFFDA8AFF).withValues(alpha: 0),
                  ],
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
