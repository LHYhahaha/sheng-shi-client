import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../application/member_point_details_controller.dart';
import '../../domain/member_point_details.dart';

const _detailsBackground = Color(0xFF08000F);
const _detailsMutedText = Color(0xFF8F8798);

class MemberPointDetailsPage extends ConsumerStatefulWidget {
  const MemberPointDetailsPage({super.key});

  @override
  ConsumerState<MemberPointDetailsPage> createState() =>
      _MemberPointDetailsPageState();
}

class _MemberPointDetailsPageState
    extends ConsumerState<MemberPointDetailsPage> {
  late final ScrollController _scrollController;
  bool _didTriggerLoadMoreNearEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    Future.microtask(
      () =>
          ref.read(memberPointDetailsControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 240) {
      _didTriggerLoadMoreNearEnd = false;
      return;
    }
    if (_didTriggerLoadMoreNearEnd) {
      return;
    }

    final state = ref.read(memberPointDetailsControllerProvider);
    if (!state.hasMore || state.isLoading || state.isLoadingMore) {
      return;
    }

    _didTriggerLoadMoreNearEnd = true;
    ref.read(memberPointDetailsControllerProvider.notifier).loadMore();
  }

  void _handleLoadingStateChanged(bool? previous, bool next) {
    if (next) {
      return;
    }
    _didTriggerLoadMoreNearEnd = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberPointDetailsControllerProvider);
    ref.listen(
      memberPointDetailsControllerProvider.select((state) => state.isLoading),
      _handleLoadingStateChanged,
    );
    ref.listen(
      memberPointDetailsControllerProvider.select(
        (state) => state.isLoadingMore,
      ),
      _handleLoadingStateChanged,
    );

    return Scaffold(
      backgroundColor: _detailsBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _MemberPointDetailsTopBar(),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(MemberPointDetailsState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFB000FF),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      final l10n = AppLocalizations.maybeOf(context);
      return Center(
        child: AppEmptyState(message: l10n.memberPointsDetailEmpty),
      );
    }

    return ListView.separated(
      key: const Key('member_point_details_list'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 23, 16, 24),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB000FF),
                ),
              ),
            ),
          );
        }
        return _MemberPointDetailItem(record: state.items[index]);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 22),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
    );
  }
}

class _MemberPointDetailsTopBar extends StatelessWidget {
  const _MemberPointDetailsTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);

    return SizedBox(
      height: 50,
      width: MediaQuery.sizeOf(context).width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              key: const Key('member_point_details_back'),
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Text(
            l10n.memberPointsDetailTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPointDetailItem extends StatelessWidget {
  const _MemberPointDetailItem({required this.record});

  final MemberPointDetailRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/rewards/points_icon.png',
          width: 26,
          height: 26,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatAmount(record),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight(510),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatTime(record.createdAt),
                style: const TextStyle(
                  color: _detailsMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _recordLabel(context, record),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatAmount(MemberPointDetailRecord record) {
    final absAmount = record.amount.abs();
    return record.isIncome ? '+$absAmount' : '-$absAmount';
  }

  String _recordLabel(BuildContext context, MemberPointDetailRecord record) {
    final l10n = AppLocalizations.maybeOf(context);
    final remark = record.remark.trim();
    final label = _localizedRecordKey(l10n, remark);
    if (label != null) {
      return label;
    }
    if (remark.isNotEmpty) {
      return remark;
    }

    return switch (record.bizType) {
      1 => l10n.memberPointsDetailTypeDaily,
      2 => l10n.memberPointsDetailTypePush,
      3 => l10n.memberPointsDetailTypeWatch,
      _ => '',
    };
  }

  String? _localizedRecordKey(AppLocalizations l10n, String key) {
    if (key.isEmpty) {
      return null;
    }

    final checkInDay = RegExp(r'^checkin\.day\.(\d+)$').firstMatch(key);
    if (checkInDay != null) {
      return l10n.rewardsSigninDayIndex(int.parse(checkInDay.group(1)!));
    }

    final exchangeDays = RegExp(
      r'^(?:point|member_points?)\.(?:exchange|redeem)\.(?:member\.)?(\d+)d$',
    ).firstMatch(key);
    if (exchangeDays != null) {
      return l10n.memberPointsDetailTypeExchange(
        int.parse(exchangeDays.group(1)!),
      );
    }

    return switch (key) {
      'coin.bind_account' => l10n.rewardsTaskLogin,
      'coin.enable_push' => l10n.rewardsTaskEnablePush,
      'coin.share_drama' => l10n.rewardsTaskShare,
      'coin.watch.5m' => l10n.rewardsTaskWatch5,
      'coin.watch.10m' => l10n.rewardsTaskWatch10,
      'coin.watch.15m' => l10n.rewardsTaskWatch15,
      'point.draw.first' ||
      'point.draw.daily' => l10n.memberPointsDetailTypeDaily,
      'point.watch.30m' => l10n.memberPointsDetailTypeWatch,
      'point.enable_push' => l10n.memberPointsDetailTypePush,
      'member_points.detail.type.daily' => l10n.memberPointsDetailTypeDaily,
      'member_points.detail.type.push' => l10n.memberPointsDetailTypePush,
      'member_points.detail.type.watch' => l10n.memberPointsDetailTypeWatch,
      _ => null,
    };
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
