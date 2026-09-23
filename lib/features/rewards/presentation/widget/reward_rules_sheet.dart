import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/modal/app_modal_root_sheet.dart';
import '../../../../l10n/app_localizations.dart';

enum RewardRulesCopy { rewardCoins, memberPoints }

Future<void> showRewardRulesSheet(
  BuildContext context, {
  RewardRulesCopy copy = RewardRulesCopy.rewardCoins,
}) {
  return showAppModalRootBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (context) => RewardRulesSheet(copy: copy),
  );
}

class RewardRulesSheet extends StatelessWidget {
  const RewardRulesSheet({this.copy = RewardRulesCopy.rewardCoins, super.key});

  final RewardRulesCopy copy;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final l10n = AppLocalizations.maybeOf(context);
    final title = switch (copy) {
      RewardRulesCopy.rewardCoins => l10n.rewardsRuleTitle,
      RewardRulesCopy.memberPoints => l10n.memberPointsRuleTitle,
    };
    final content = switch (copy) {
      RewardRulesCopy.rewardCoins => l10n.rewardsRuleContent,
      RewardRulesCopy.memberPoints => l10n.memberPointsRuleContent,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26.w)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 16.w, bottomPadding + 20.w),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 23.w),
                  Center(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        height: 1.25,
                        fontWeight: FontWeight(510),
                      ),
                    ),
                  ),
                  SizedBox(height: 28.w),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Text(
                        content,
                        key: const Key('reward_rules_content'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          height: 1.42,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 15.w,
                right: 0,
                child: _RewardRulesCloseButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardRulesCloseButton extends StatelessWidget {
  const _RewardRulesCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close rules',
      child: InkWell(
        key: const Key('reward_rules_close'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SvgPicture.asset(
          "assets/images/player/close.svg",
          width: 40.w,
          height: 40.w,
        ),
      ),
    );
  }
}
