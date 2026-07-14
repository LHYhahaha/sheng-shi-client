import 'package:flutter/material.dart';

const _gold = Color(0xFFFFD58D);
const _muted = Color(0xFF77777B);
const _card = Color(0xFF1B1D22);

/// Rewards coins 页面。
///
/// 当前仅实现静态视觉；签到、领取以及规则入口会在接入奖励接口时补充交互。
class RewardsCoinsPage extends StatelessWidget {
  const RewardsCoinsPage({this.useParentBackground = false, super.key});

  final bool useParentBackground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('rewards_coins_page'),
      decoration: BoxDecoration(
        gradient: useParentBackground
            ? null
            : const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF4E370D), Color(0xFF121418)],
                stops: [0, 0.33],
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
        children: const [
          _BalanceHeader(),
          _CheckInPanel(),
          SizedBox(height: 22),
          Text(
            'Earn Rewards',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 11),
          _RewardTaskCard(
            key: Key('reward_task_login'),
            imagePath: 'assets/images/rewards/coins_login_account.png',
            title: 'Login with any account',
            claimed: true,
          ),
          SizedBox(height: 8),
          _RewardTaskCard(
            key: Key('reward_task_invite'),
            imagePath: 'assets/images/rewards/coins_invite.png',
            title: 'Invite friends',
          ),
          SizedBox(height: 8),
          _RewardTaskCard(
            key: Key('reward_task_watch_5'),
            imagePath: 'assets/images/rewards/coins_watch.png',
            title: 'Watch for 5 mins',
          ),
          SizedBox(height: 8),
          _RewardTaskCard(
            key: Key('reward_task_watch_10'),
            imagePath: 'assets/images/rewards/coins_watch.png',
            title: 'Watch for 10 mins',
          ),
          SizedBox(height: 8),
          _RewardTaskCard(
            key: Key('reward_task_watch_15'),
            imagePath: 'assets/images/rewards/coins_watch.png',
            title: 'Watch for 15 mins',
          ),
          SizedBox(height: 8),
          _RewardTaskCard(
            key: Key('reward_task_notification'),
            imagePath: 'assets/images/rewards/coins_notification.png',
            title: 'Turn push notification',
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('rewards_coins_balance'),
      height: 102,
      child: Stack(
        children: [
          const Positioned(
            left: 10,
            top: 33,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2230',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your Balance',
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
            bottom: -2,
            child: Image.asset(
              'assets/images/rewards/coins_icon.png',
              width: 142,
              height: 142,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInPanel extends StatelessWidget {
  const _CheckInPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rewards_coins_check_in_panel'),
      padding: const EdgeInsets.fromLTRB(11, 22, 11, 12),
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
              const Expanded(
                child: Text(
                  'Check-in for Rewards',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                key: const Key('rewards_coins_rules'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Rules',
                  style: TextStyle(color: Color(0xFFAAA49D), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CheckInDay(day: 1, checked: true)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 2, active: true)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 3)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 4)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 5)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 6)),
              SizedBox(width: 4),
              Expanded(child: _CheckInDay(day: 7)),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            key: const Key('rewards_coins_sign_in'),
            width: double.infinity,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [Color(0xFFD48851), Color(0xFFFFF3C7)],
              ),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Color(0xFF71340B),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInDay extends StatelessWidget {
  const _CheckInDay({
    required this.day,
    this.checked = false,
    this.active = false,
  });

  final int day;
  final bool checked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 67,
          decoration: BoxDecoration(
            color: checked ? const Color(0xFF333539) : const Color(0xFFAF6E37),
            borderRadius: BorderRadius.circular(4),
            gradient: checked
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF9A572B), Color(0xFFE0A052)],
                  ),
            border: checked
                ? null
                : Border.all(color: const Color(0xFFCF9561), width: 0.7),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (checked)
                Container(
                  width: 25,
                  height: 25,
                  decoration: const BoxDecoration(
                    color: Color(0xFF929397),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF45464A),
                    size: 18,
                  ),
                )
              else
                Image.asset(
                  'assets/images/rewards/coins.png',
                  width: 29,
                  height: 29,
                ),
              const SizedBox(height: 5),
              Text(
                '+10',
                style: TextStyle(
                  color: checked ? const Color(0xFF8C8D91) : Colors.white,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        if (checked)
          const Icon(Icons.check_rounded, color: Color(0xFF5E6065), size: 17)
        else
          Text(
            'DAY $day',
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

class _RewardTaskCard extends StatelessWidget {
  const _RewardTaskCard({
    required this.imagePath,
    required this.title,
    this.claimed = false,
    super.key,
  });

  final String imagePath;
  final String title;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(imagePath, width: 34, height: 34),
          const SizedBox(width: 10),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '+10',
                        style: TextStyle(color: Color(0xFFE45E18)),
                      ),
                      TextSpan(
                        text: ' Reward coins',
                        style: TextStyle(color: Color(0xFF696A6E)),
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
            width: 74,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: claimed ? const Color(0xFF696A6E) : null,
              gradient: claimed
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFD4864E), Color(0xFFFFF0BE)],
                    ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Claim',
              style: TextStyle(
                color: claimed
                    ? const Color(0xFFBEBFC2)
                    : const Color(0xFF74380E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
