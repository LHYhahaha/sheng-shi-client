import 'package:flutter/foundation.dart';

/// Per-platform Adjust credentials and event tokens.
class AdjustPlatformConfiguration {
  const AdjustPlatformConfiguration._({
    required this.appToken,
    required this.eventTokens,
  });

  static const _android = AdjustPlatformConfiguration._(
    appToken: 'i3xfcgiqzsao',
    eventTokens: AdjustEventTokenSet(
      appFirstOpen: 'xklyoy',
      dramaPlayStart: 'x7p5qa',
      homeFirstView: '37fm6a',
      checkoutStart: 'm8l7ax',
    ),
  );

  static const _ios = AdjustPlatformConfiguration._(
    appToken: 'r7kxnc1vswe8',
    eventTokens: AdjustEventTokenSet(
      appFirstOpen: 'l0kgl3',
      dramaPlayStart: '3gn2et',
      homeFirstView: '9qksln',
      checkoutStart: 'uqyu5x',
    ),
  );

  static AdjustPlatformConfiguration forPlatform(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.android => _android,
        TargetPlatform.iOS => _ios,
        _ => throw UnsupportedError('Adjust is unsupported on $platform'),
      };

  final String appToken;
  final AdjustEventTokenSet eventTokens;
}

class AdjustEventTokenSet {
  const AdjustEventTokenSet({
    required this.appFirstOpen,
    required this.dramaPlayStart,
    required this.homeFirstView,
    required this.checkoutStart,
  });

  final String appFirstOpen;
  final String dramaPlayStart;
  final String homeFirstView;
  final String checkoutStart;
}

abstract final class AdjustEventTokens {
  /// Android token aliases retained for existing callers and tests.
  static const appFirstOpen = 'xklyoy';
  static const dramaPlayStart = 'x7p5qa';
  static const homeFirstView = '37fm6a';
  static const checkoutStart = 'm8l7ax';

  static AdjustEventTokenSet forPlatform(TargetPlatform platform) =>
      AdjustPlatformConfiguration.forPlatform(platform).eventTokens;
}
