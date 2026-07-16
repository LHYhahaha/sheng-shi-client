import 'package:flutter/material.dart';
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
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 16, bottomPadding+20),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 23),
                  Center(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight(510),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Text(
                        content,
                        key: const Key('reward_rules_content'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.42,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 15,
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
          width: 40,
          height: 40,
        ),
      ),
    );
  }
}
