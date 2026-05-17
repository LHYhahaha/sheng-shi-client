import 'dart:io';

import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core/auth must not import features', () {
    final authDir = Directory('lib/core/auth');
    expect(authDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in authDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('features/') ||
          source.contains("package:drama_client/features")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('core/modal must not import features', () {
    final modalDir = Directory('lib/core/modal');
    expect(modalDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in modalDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('features/') ||
          source.contains("package:drama_client/features")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('features layer must not import bot_toast directly', () {
    final featuresDir = Directory('lib/features');
    expect(featuresDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains("package:bot_toast/") ||
          source.contains("import 'package:bot_toast")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('ConfirmResult is typed and not a bare bool', () {
    const result = ConfirmResult.confirmed;
    expect(result, isA<ConfirmResult>());
    expect(result.isConfirmed, isTrue);
    expect(result, isNot(isA<bool>()));
  });

  test('player unlock sheets use AppModal not local showModalBottomSheet', () {
    final source = File(
      'lib/features/player/presentation/pages/player_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('PlayerCoinUnlockSheet')));
    expect(source, isNot(contains('PlayerRechargeUnlockSheet')));
    expect(source, contains('playerUnlockModalCoordinatorProvider'));
    expect(source, contains('PlayerDetailSheet'));
    expect(source, contains('showModalBottomSheet'));
  });

  test('store purchase confirmation uses AppModal coordinator', () {
    final source = File(
      'lib/features/store/presentation/pages/store_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('StoreConfirmationSheet')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, contains('storeModalCoordinatorProvider'));
  });

  test('membership purchase confirmation uses AppModal coordinator', () {
    final source = File(
      'lib/features/membership/presentation/pages/membership_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('MembershipConfirmationSheet')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, contains('membershipModalCoordinatorProvider'));
  });

  test('profile login uses auth modal coordinator not auth route push', () {
    final source = File(
      'lib/features/profile/presentation/pages/profile_page.dart',
    ).readAsStringSync();
    expect(source, contains('authModalCoordinatorProvider'));
    expect(source, isNot(contains('RoutePaths.auth')));
  });

  test('auth login modal does not import bot_toast', () {
    final dir = Directory('lib/features/auth/presentation/modal');
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      expect(source, isNot(contains('bot_toast')));
      expect(source, isNot(contains('AuthTokenStore')));
    }
  });

  test('feature pages do not patch root navigator for business modals', () {
    final featuresDir = Directory('lib/features');
    final offenders = <String>[];
    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('rootNavigator: true') ||
          source.contains('rootNavigator:true')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('business modal presenters register only via bootstrap', () {
    final bootstrap = File(
      'lib/bootstrap/app_modal_registry_bootstrap.dart',
    ).readAsStringSync();
    expect(bootstrap, contains('AuthAppModalPresenter'));
    expect(bootstrap, contains('PlayerAppModalPresenter'));
    expect(bootstrap, contains('StoreAppModalPresenter'));
    expect(bootstrap, contains('MembershipAppModalPresenter'));
  });

  /// 允许局部 [showModalBottomSheet] / [showDialog] 的页面（O5 白名单）。
  test('showModalBottomSheet whitelist for page-local sheets only', () {
    const allowed = {
      'lib/features/player/presentation/pages/player_page.dart':
          'Player detail / share / speed sheets',
      'lib/features/auth/presentation/pages/account_page.dart':
          'Account delete confirmation dialog',
    };

    final featuresDir = Directory('lib/features');
    final offenders = <String>[];
    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (!entity.path.contains('/presentation/pages/')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (!source.contains('showModalBottomSheet') &&
          !source.contains('showDialog')) {
        continue;
      }
      final relative = entity.path.replaceAll('\\', '/');
      if (!allowed.containsKey(relative)) {
        offenders.add(relative);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Add to whitelist: ${offenders.join(', ')}',
    );
  });

  test('wallet page has no blocking purchase confirmation sheet', () {
    final source = File(
      'lib/features/wallet/presentation/pages/wallet_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, isNot(contains('showDialog')));
  });
}
