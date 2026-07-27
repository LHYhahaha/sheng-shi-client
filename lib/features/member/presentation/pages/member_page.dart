import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../core/auth/user_info_store.dart';
import '../../../../core/toast/app_center_toast.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/entitlement/application/entitlement_controller.dart';
import '../../../../features/membership/application/membership_controller.dart';
import '../../../../features/membership/presentation/pages/membership_page.dart';
import '../../../../features/profile/application/profile_controller.dart';
import '../../../../features/profile/presentation/widgets/profile_header.dart';
import '../../../../features/rewards/application/member_points_controller.dart';
import '../../../../features/rewards/domain/member_point_daily_detail.dart';
import '../../../../features/rewards/domain/member_point_exchange_options.dart';
import '../../../../features/rewards/presentation/pages/member_points_page.dart';
import '../../../../features/rewards/presentation/widget/member_points_exchange_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/media/media_resource.dart';
import '../../../../shared/widgets/app_retry_button.dart';

const _memberBackground = Color(0xFF090010);
const _memberCard = Color(0xFF24192E);
const _memberText = Color(0xFFFFFFFF);
const _memberMuted = Color(0xFF9E94A7);
const _memberButton = Color(0xFFFF006C);
const _memberButtonDisabled = Color(0xFF615668);

/// 底部导航的 Member tab 页面：非会员展示开通页，会员展示会员积分页。
class MemberTabPage extends ConsumerStatefulWidget {
  const MemberTabPage({super.key});

  @override
  ConsumerState<MemberTabPage> createState() => _MemberTabPageState();
}

class _MemberTabPageState extends ConsumerState<MemberTabPage> {
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshForActiveMemberTab(includeMemberPoints: false);
    });
  }

  Future<void> _refreshForActiveMemberTab({
    bool includeMemberPoints = true,
  }) async {
    final now = DateTime.now();
    final lastRefreshAt = _lastRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastRefreshAt = now;

    await ref.read(entitlementControllerProvider.notifier).refreshFromServer();
    if (ref.read(entitlementControllerProvider).isMember) {
      if (!includeMemberPoints) {
        return;
      }
      await ref.read(memberPointsControllerProvider.notifier).loadDailyDetail();
      return;
    }

    await ref.read(membershipControllerProvider.notifier).refreshSilently();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appShellCurrentTabIndexProvider, (previous, current) {
      if (current == AppShellDestinations.memberIndex && previous != current) {
        _refreshForActiveMemberTab();
      }
    });
    ref.listen(memberTabRefreshRequestProvider, (previous, current) {
      if (previous != current) {
        _refreshForActiveMemberTab();
      }
    });

    final isMember = ref.watch(entitlementControllerProvider).isMember;

    if (!isMember) {
      return const MembershipPage(
        showBackButton: false,
        handleBackNavigation: false,
      );
    }

    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF390E4E), Color(0xFF0E0D0F)],
          stops: [0, 0.33],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: MemberPointsPage(isActive: true, useParentBackground: true),
      ),
    );
  }
}

class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(entitlementControllerProvider.notifier)
          .refreshFromServer();
      if (!mounted || !ref.read(entitlementControllerProvider).isMember) {
        return;
      }
      ref.read(memberPointsControllerProvider.notifier).loadDailyDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userInfo = ref.watch(userInfoStoreProvider);
    final entitlement = ref.watch(entitlementControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final points = ref.watch(memberPointsControllerProvider);
    final hasMemberInfoError =
        points.error != null &&
        points.data == null &&
        points.exchangeOptions == null;
    final authUser = auth.user;
    final pointBalance =
        points.exchangeOptions?.balance ?? entitlement.totalPointBalance;
    final tiers = _sortedExchangeTiers(
      points.exchangeOptions?.list ?? const <MemberPointExchangeTier>[],
    );
    final dailyRewardPoints = _dailyRewardAvailablePoints(points.data);
    final hasLinkedAccount = !auth.session.isGuest;
    final avatarResource =
        authUser?.avatarResource ??
        (userInfo.avatar != null && userInfo.avatar!.isNotEmpty
            ? MediaResource.network(userInfo.avatar!)
            : profileState.avatarResource);
    final headerState = profileState.copyWith(
      isLoggedIn: hasLinkedAccount,
      userId: authUser?.id ?? userInfo.showId,
      showId: authUser?.showId ?? userInfo.showId,
      nickname: authUser?.nickname ?? userInfo.nickname,
      avatarAssetPath:
          authUser?.avatarAssetPath ?? profileState.avatarAssetPath,
      avatarResource: avatarResource,
    );

    return Scaffold(
      backgroundColor: _memberBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            10,
            12,
            10,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            const _MemberNavBar(),
            const SizedBox(height: 32),
            ProfileHeader(
              state: headerState,
              onLoginTap: () {
                if (auth.session.isGuest) {
                  context.push(RoutePaths.auth);
                }
              },
              onAccountTap: () => context.push(RoutePaths.account),
              onGuestTap: () {
                if (auth.session.isGuest) {
                  context.push(RoutePaths.auth);
                }
              },
            ),
            const SizedBox(height: 42),
            if (hasMemberInfoError)
              _MemberInfoLoadFailed(
                onRetry: () => ref
                    .read(memberPointsControllerProvider.notifier)
                    .loadDailyDetail(),
              )
            else ...[
              _SectionTitleRow(
                title: 'Points redemption',
                trailing: _PointsValue(value: pointBalance, showChevron: true),
                onTap: () => context.push(RoutePaths.memberPointDetails),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < tiers.length; index++) ...[
                _RedeemCard(tier: tiers[index]),
                if (index < tiers.length - 1) const SizedBox(height: 8),
              ],
              if (dailyRewardPoints > 0) ...[
                const SizedBox(height: 8),
                _DailyRewardCard(availablePoints: dailyRewardPoints),
              ],
            ],
            const SizedBox(height: 24),
            const _PrivilegesSection(),
          ],
        ),
      ),
    );
  }
}

class _MemberNavBar extends StatelessWidget {
  const _MemberNavBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('member_back_button'),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.home);
                }
              },
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              color: Colors.white,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            ),
          ),
          Text(
            'My Member',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _memberText,
              fontSize: 16,
              fontWeight: FontWeight(510),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({required this.title, this.trailing, this.onTap});

  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _memberText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: trailing,
          ),
      ],
    );
  }
}

class _PointsValue extends StatelessWidget {
  const _PointsValue({required this.value, this.showChevron = false});

  final int value;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/rewards/points_icon.png',
          width: 18,
          height: 18,
          filterQuality: FilterQuality.low,
        ),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _memberText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 7),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFB5B2B8),
            size: 26,
          ),
        ],
      ],
    );
  }
}

class _MemberInfoLoadFailed extends StatelessWidget {
  const _MemberInfoLoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: _memberCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            l10n.networkError,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _memberText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          AppRetryButton(onPressed: onRetry, label: l10n.retry),
        ],
      ),
    );
  }
}

class _RedeemCard extends ConsumerWidget {
  const _RedeemCard({required this.tier});

  final MemberPointExchangeTier tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.maybeOf(context);
    final isEnabled = tier.canExchange;
    final isExchanging = ref.watch(memberPointsControllerProvider).isExchanging;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _memberCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.memberCenterExchangeDaysMember(tier.memberDays),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _memberText,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 9),
                _CostLabel(cost: tier.pointCost),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 30,
            alignment: Alignment.center,
            child: TextButton(
              key: Key('member_redeem_${tier.tierId}'),
              onPressed: !isExchanging
                  ? () async {
                      if (!isEnabled) {
                        showAppCenterToast(
                          l10n.memberCenterModalExchangeInsufficientPoints,
                        );
                        return;
                      }
                      final confirmed =
                          await showMemberPointsExchangeConfirmDialog(
                            context,
                            memberDays: tier.memberDays,
                            pointCost: tier.pointCost,
                          );
                      if (!confirmed || !context.mounted) return;
                      ref
                          .read(memberPointsControllerProvider.notifier)
                          .exchange(tierId: tier.tierId);
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
                backgroundColor: isEnabled
                    ? _memberButton
                    : _memberButtonDisabled,
                disabledBackgroundColor: _memberButtonDisabled,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                l10n.memberCenterButtonExchange,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostLabel extends StatelessWidget {
  const _CostLabel({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/images/rewards/points_icon.png',
          width: 18,
          height: 18,
          filterQuality: FilterQuality.low,
        ),
        const SizedBox(width: 4),
        Text(
          '$cost',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _memberMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _DailyRewardCard extends StatelessWidget {
  const _DailyRewardCard({required this.availablePoints});

  final int availablePoints;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(RoutePaths.member),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _memberCard,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Daily Reward',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _memberText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            _PointsValue(value: availablePoints),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9E98A8),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivilegesSection extends StatelessWidget {
  const _PrivilegesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PrivilegeTitle(),
        const SizedBox(height: 12),
        _PrivilegeItem(
          icon: 'assets/images/membership/member_series.png',
          title: 'Unlimited access to 8,000+ series',
          highlightedText: '8,000+',
          subtitle: '55+ fresh dramas every week',
        ),
        const SizedBox(height: 20),
        const _PrivilegeItem(
          icon: 'assets/images/membership/member_download.png',
          title: 'Download',
        ),
        const SizedBox(height: 14),
        _PrivilegeItem(
          icon: 'assets/images/membership/member_points.png',
          title: 'Daily member points',
          showChevron: true,
          onTap: () => context.go(RoutePaths.member),
        ),
        const SizedBox(height: 20),
        _PrivilegeItem(
          icon: 'assets/images/membership/member_only.png',
          title: 'Members-only dramas',
        ),
        const SizedBox(height: 20),
        const _PrivilegeItem(
          icon: 'assets/images/membership/member_hd.png',
          title: '1080p quality',
        ),
      ],
    );
  }
}

class _PrivilegeTitle extends StatelessWidget {
  const _PrivilegeTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'My privilege',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: _memberText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
  }
}

class _PrivilegeItem extends StatelessWidget {
  const _PrivilegeItem({
    required this.icon,
    required this.title,
    this.highlightedText,
    this.subtitle,
    this.showChevron = false,
    this.onTap,
  });

  final String icon;
  final String title;
  final String? highlightedText;
  final String? subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Image.asset(
          icon,
          width: 30,
          height: 30,
          filterQuality: FilterQuality.low,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                _titleSpan(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showChevron)
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFB0AABD),
            size: 26,
          ),
      ],
    );

    if (onTap == null) return row;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  TextSpan _titleSpan(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.66),
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.15,
    );
    final highlighted = highlightedText;
    if (highlighted == null || highlighted.isEmpty) {
      return TextSpan(text: title, style: baseStyle);
    }

    final highlightStart = title.indexOf(highlighted);
    if (highlightStart < 0) {
      return TextSpan(text: title, style: baseStyle);
    }

    final highlightEnd = highlightStart + highlighted.length;
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: title.substring(0, highlightStart)),
        TextSpan(
          text: title.substring(highlightStart, highlightEnd),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(text: title.substring(highlightEnd)),
      ],
    );
  }
}

List<MemberPointExchangeTier> _sortedExchangeTiers(
  List<MemberPointExchangeTier> tiers,
) {
  return [...tiers]..sort((a, b) => a.priority.compareTo(b.priority));
}

int _dailyRewardAvailablePoints(MemberPointDailyDetail? dailyDetail) {
  if (dailyDetail == null) return 0;

  var total = 0;
  for (final task in dailyDetail.tasks) {
    if (!task.claimed) {
      total += task.rewardMin;
    }
  }
  return total;
}
