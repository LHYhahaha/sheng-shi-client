import 'package:drama_client/core/toast/app_center_toast.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void showRewardCoinsClaimSuccessToast(BuildContext context, int rewardAmount) =>
    showAppCenterToast(
      '+${context.l10n.rewardsClaimSuccessCoins(rewardAmount)}',
    );
