import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides fallback copy for the ad unlock flow', () {
    const localizations = AppLocalizations(Locale('en'));

    expect(localizations.playerUnlockWatchAd, 'Watch Ads to unlock for free');
    expect(localizations.playerUnlockReplay, 'Replay');
    expect(
      localizations.playerAdLimitRegular,
      'Regular drama ad limit reached.',
    );
    expect(localizations.playerAdLimitVip, 'VIP drama ad limit reached.');
    expect(localizations.adUnlockModalTitle, 'Watch this episode free?');
    expect(localizations.adUnlockActionWatch, 'Watch Ad to unlock');
    expect(
      localizations.adUnlockTodayProgress(watched: 2, total: 5),
      'Watched today (2/5)',
    );
    expect(localizations.adUnlockCloseCountdown(seconds: 12), 'Close in 12s');
    expect(
      localizations.adUnlockWatchCountdown(seconds: 12),
      'Watch 12s more to unlock',
    );
    expect(localizations.adUnlockStatusWatching, 'Watching');
  });
}
