import 'dart:async';

import 'package:drama_client/app/app.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/presentation/pages/account_page.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:drama_client/features/my_list/domain/my_list_repository.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/profile/presentation/pages/language_page.dart';
import 'package:drama_client/features/store/presentation/pages/store_page.dart';
import 'package:drama_client/features/wallet/domain/wallet_record.dart';
import 'package:drama_client/features/wallet/domain/wallet_repository.dart';
import 'package:drama_client/features/wallet/data/wallet_repository_provider.dart';
import 'package:drama_client/features/wallet/presentation/pages/wallet_history_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows the app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Found You,Hea'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('switches between bottom navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    expect(find.text('Collection list'), findsOneWidget);
    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Log in >'), findsOneWidget);
    expect(find.text('Wallet >'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('opens wallet from profile coins card', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();

    expect(find.text('My Wallet'), findsWidgets);
    expect(find.text('4000'), findsWidgets);
    expect(find.text('Top Up'), findsOneWidget);
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Consumption history'), findsOneWidget);
    expect(find.text('Record Coins'), findsOneWidget);
  });

  testWidgets('opens wallet transaction history from wallet page', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transaction history'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Membership (Weekly)'), findsOneWidget);
    expect(find.text('3000 Coins + 300bonus'), findsOneWidget);
  });

  testWidgets('wallet keeps auto unlock toggle after opening history', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.text('Transaction history'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('consumption history shows segmented poster rows', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consumption history'));
    await tester.pumpAndSettle();

    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('EP. 11'), findsWidgets);
    expect(find.text('Raja Iblis Hidup Kembali'), findsWidgets);
    expect(find.text('-30'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);

    await tester.tap(find.text('Expired'));
    await tester.pumpAndSettle();
    expect(find.text('EP. 10'), findsOneWidget);
    expect(find.text('Pulang Malam Mengejutkan'), findsOneWidget);
  });

  testWidgets('record coins shows check in buttons and disabled state', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet >'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Coins'));
    await tester.pumpAndSettle();

    expect(find.text('10 Reward Coins'), findsWidgets);
    expect(find.text('20 Reward Coins'), findsOneWidget);
    expect(find.text('Check in'), findsWidgets);
  });

  testWidgets('opens auth from profile and logs in with mock provider', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in >'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Device'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Facebook'), findsOneWidget);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Google User'), findsOneWidget);
    expect(find.text('Log in >'), findsNothing);
  });

  testWidgets('opens account from logged-in profile header', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in >'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google User'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('account page logs out and confirms delete account', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in >'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Device'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Device User'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(
      find.text('This is a mock delete account confirmation for MVP testing.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in >'), findsOneWidget);
  });

  testWidgets('opens membership from profile and confirms mock purchase', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 186));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);
    expect(find.text('Weekly VIP'), findsOneWidget);
    expect(find.text('VIP Benefits'), findsOneWidget);

    await tester.tap(find.text('Monthly VIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm membership'), findsOneWidget);
    expect(
      find.text('This is a mock membership confirmation for MVP testing.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Processing mock purchase...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Mock purchase completed.'), findsOneWidget);
  });

  testWidgets('returns from membership to profile with top back button', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 186));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('returns from home VIP membership entry back to home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_vip_entry')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Join Membership'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
  });

  testWidgets('opens for you player feed and swipes to next item', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAppWithFakePlayback());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('For you'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('My Secret Deal With The Playboy'), findsOneWidget);
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Found You, Heart Thief'), findsOneWidget);
  });

  testWidgets(
    'for you taps video to pause and resume with bottom tab visible',
    (tester) async {
      final sessions = <_FakePlaybackSession>[];
      await tester.pumpWidget(_buildAppWithFakePlayback(sessions: sessions));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('For you'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final forYouSession = sessions.first;

      await tester.tap(
        find.byKey(const ValueKey('player_video_tap_layer')).first,
      );
      await tester.pumpAndSettle();

      expect(forYouSession.pauseCount, 1);
      expect(
        find.byKey(const ValueKey('player_center_play_button')),
        findsOneWidget,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My list'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('player_center_play_button')));
      await tester.pumpAndSettle();

      expect(forYouSession.playCount, 1);
      expect(
        find.byKey(const ValueKey('player_center_play_button')),
        findsNothing,
      );
    },
  );

  testWidgets('for you Watch Now is not covered and does not pause playing', (
    tester,
  ) async {
    final sessions = <_FakePlaybackSession>[];
    await tester.pumpWidget(_buildAppWithFakePlayback(sessions: sessions));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('For you'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final forYouSession = sessions.first;

    await tester.tap(find.text('Watch Now'));
    await tester.pumpAndSettle();

    expect(forYouSession.pauseCount, 0);
    expect(find.text('Watch Now'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('player_video_tap_layer')).first,
    );
    await tester.pumpAndSettle();

    expect(forYouSession.pauseCount, 1);
    expect(
      find.byKey(const ValueKey('player_center_play_button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Watch Now'));
    await tester.pumpAndSettle();

    expect(forYouSession.playCount, 1);
    expect(
      find.byKey(const ValueKey('player_center_play_button')),
      findsNothing,
    );
  });

  for (final destination in ['Home', 'My list', 'Profile']) {
    testWidgets('pauses for you playback when switching to $destination', (
      tester,
    ) async {
      final sessions = <_FakePlaybackSession>[];
      await tester.pumpWidget(_buildAppWithFakePlayback(sessions: sessions));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('For you'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(sessions, isNotEmpty);
      final forYouSession = sessions.first;
      expect(find.text('Found You, Heart Thief'), findsOneWidget);

      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      expect(forYouSession.pauseCount, greaterThan(0));
      expect(forYouSession.isDisposed, isFalse);

      await tester.tap(find.text('For you'));
      await tester.pumpAndSettle();

      expect(find.text('Found You, Heart Thief'), findsOneWidget);
    });
  }

  testWidgets('pauses player playback on app lifecycle inactive and paused', (
    tester,
  ) async {
    final sessions = <_FakePlaybackSession>[];
    await tester.pumpWidget(_buildAppWithFakePlayback(sessions: sessions));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('For you'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final forYouSession = sessions.first;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(forYouSession.pauseCount, greaterThanOrEqualTo(2));
  });

  testWidgets('opens home drama as single drama feed and swipes episodes', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAppWithFakePlayback());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(110, 260));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('EP.01'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);
  });

  testWidgets('disposes single drama playback when returning from player', (
    tester,
  ) async {
    final sessions = <_FakePlaybackSession>[];
    await tester.pumpWidget(_buildAppWithFakePlayback(sessions: sessions));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(110, 260));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(sessions, isNotEmpty);
    final singleDramaSession = sessions.first;

    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();

    expect(singleDramaSession.pauseCount, greaterThan(0));
    expect(singleDramaSession.isDisposed, isTrue);
  });

  testWidgets('for you feed does not inherit single drama player state', (
    tester,
  ) async {
    await tester.pumpWidget(_buildAppWithFakePlayback());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('For you'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Found You, Heart Thief'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(110, 260));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('EP.02'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();

    expect(find.text('Found You, Heart Thief'), findsOneWidget);
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.text('EP.02'), findsNothing);
  });

  testWidgets('opens language settings from profile', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('changes app locale from language settings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
  });

  testWidgets('account back falls back to profile without navigation stack', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.account,
      routes: [
        GoRoute(
          path: RoutePaths.account,
          builder: (context, state) => const AccountPage(),
        ),
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) =>
              const Scaffold(body: Text('Profile fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _SignedInAuthRepository(AuthProviderType.google),
          ),
        ],
        child: _TestRouterApp(router: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Profile fallback'), findsOneWidget);
  });

  testWidgets('language back falls back to profile without navigation stack', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.language,
      routes: [
        GoRoute(
          path: RoutePaths.language,
          builder: (context, state) => const LanguagePage(),
        ),
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) =>
              const Scaffold(body: Text('Profile fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: _TestRouterApp(router: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Profile fallback'), findsOneWidget);
  });

  testWidgets(
    'wallet history back falls back to wallet without navigation stack',
    (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.transactionHistory,
        routes: [
          GoRoute(
            path: RoutePaths.transactionHistory,
            builder: (context, state) =>
                const WalletHistoryPage(type: WalletRecordType.transaction),
          ),
          GoRoute(
            path: RoutePaths.wallet,
            builder: (context, state) =>
                const Scaffold(body: Text('Wallet fallback')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: _TestRouterApp(router: router)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Transaction history'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Wallet fallback'), findsOneWidget);
    },
  );

  testWidgets('transaction history shows empty state', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.transactionHistory,
      routes: [
        GoRoute(
          path: RoutePaths.transactionHistory,
          builder: (context, state) =>
              const WalletHistoryPage(type: WalletRecordType.transaction),
        ),
        GoRoute(
          path: RoutePaths.wallet,
          builder: (context, state) =>
              const Scaffold(body: Text('Wallet fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            const _EmptyWalletRepository(),
          ),
        ],
        child: _TestRouterApp(router: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('There are no records yet.'), findsOneWidget);
  });

  testWidgets('consumption history keeps segmented control when empty', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.consumptionHistory,
      routes: [
        GoRoute(
          path: RoutePaths.consumptionHistory,
          builder: (context, state) =>
              const WalletHistoryPage(type: WalletRecordType.consumption),
        ),
        GoRoute(
          path: RoutePaths.wallet,
          builder: (context, state) =>
              const Scaffold(body: Text('Wallet fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            const _EmptyWalletRepository(),
          ),
        ],
        child: _TestRouterApp(router: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Consumption history'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('There are no records yet.'), findsOneWidget);

    await tester.tap(find.text('Expired'));
    await tester.pumpAndSettle();

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('There are no records yet.'), findsOneWidget);
  });

  testWidgets('record coins shows empty state', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.recordCoins,
      routes: [
        GoRoute(
          path: RoutePaths.recordCoins,
          builder: (context, state) =>
              const WalletHistoryPage(type: WalletRecordType.coins),
        ),
        GoRoute(
          path: RoutePaths.wallet,
          builder: (context, state) =>
              const Scaffold(body: Text('Wallet fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            const _EmptyWalletRepository(),
          ),
        ],
        child: _TestRouterApp(router: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Record Coins'), findsOneWidget);
    expect(find.text('There are no records yet.'), findsOneWidget);
  });

  testWidgets('enters collection edit mode from the header menu', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete (0)'), findsOneWidget);

    await tester.tap(find.text('Raja Iblis Hidup Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Delete (1)'), findsOneWidget);
  });

  testWidgets('my list empty CTA returns home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myListRepositoryProvider.overrideWithValue(
            const _EmptyMyListRepository(),
          ),
        ],
        child: const DramaClientApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();

    expect(find.text('There is no content for now~'), findsOneWidget);
    expect(find.text('Watch popular dramas'), findsOneWidget);

    await tester.tap(find.text('Watch popular dramas'));
    await tester.pumpAndSettle();

    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
  });

  testWidgets('reveals play list delete action before deleting', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play list'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);

    await tester.drag(
      find.text('Raja Iblis Hidup Kembali'),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);
    expect(find.text('Delete'), findsWidgets);

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Raja Iblis Hidup Kembali'), findsNothing);
  });

  testWidgets('closes play list delete action when tapping elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play list'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Raja Iblis Hidup Kembali'),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsWidgets);

    await tester.tapAt(const Offset(24, 250));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Raja Iblis Hidup Kembali'), findsOneWidget);
  });

  testWidgets('store page shows packages and confirmation sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StorePage(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('Weekly VIP'), findsWidgets);

    await tester.tap(find.text(r'$ 29.99').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm purchase'), findsOneWidget);
    expect(
      find.text('This is a mock confirmation for MVP testing.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mock purchase cancelled.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Processing mock purchase...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Mock purchase completed.'), findsOneWidget);
  });
}

class _TestRouterApp extends StatelessWidget {
  const _TestRouterApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}

Widget _buildAppWithFakePlayback({List<_FakePlaybackSession>? sessions}) {
  return ProviderScope(
    overrides: [
      playerPlaybackSessionFactoryProvider.overrideWithValue(() {
        final session = _FakePlaybackSession();
        sessions?.add(session);
        return session;
      }),
    ],
    child: const DramaClientApp(),
  );
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final seekedPositions = <Duration>[];
  int pauseCount = 0;
  int playCount = 0;
  bool isDisposed = false;

  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<int?> get widthStream => _widthController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<void> open(String source, {bool play = true}) async {
    _bufferingController.add(false);
    _playingController.add(play);
    _durationController.add(const Duration(seconds: 100));
    _widthController.add(1280);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCount += 1;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seekedPositions.add(position);
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) {
      return;
    }
    isDisposed = true;
    await _bufferingController.close();
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _widthController.close();
    await _errorController.close();
  }
}

class _SignedInAuthRepository implements AuthRepository {
  _SignedInAuthRepository(this.provider);

  final AuthProviderType provider;

  @override
  Future<AuthSession> fetchSession() async {
    return AuthSession(
      user: AuthUser(
        id: '15589299',
        nickname: switch (provider) {
          AuthProviderType.device => 'Device User',
          AuthProviderType.google => 'Google User',
          AuthProviderType.facebook => 'Facebook User',
        },
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
    );
  }

  @override
  Future<AuthSession> login(AuthProviderType provider) => fetchSession();

  @override
  Future<AuthSession> logout() async => const AuthSession.guest();

  @override
  Future<AuthSession> deleteAccount() async => const AuthSession.guest();
}

class _EmptyMyListRepository implements MyListRepository {
  const _EmptyMyListRepository();

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    return const [];
  }
}

class _EmptyWalletRepository implements WalletRepository {
  const _EmptyWalletRepository();

  @override
  Future<WalletData> fetchWallet() async {
    return const WalletData(
      coins: 0,
      bonus: 0,
      autoUnlockNextEpisode: false,
      transactionRecords: [],
      consumptionRecords: [],
      coinRecords: [],
    );
  }
}
