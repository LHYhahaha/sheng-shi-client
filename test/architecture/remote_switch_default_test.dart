import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/drama/data/drama_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/membership/data/membership_repository_provider.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/player/data/player_content_repository_provider.dart';
import 'package:drama_client/features/profile/data/profile_repository_provider.dart';
import 'package:drama_client/features/store/data/store_repository_provider.dart';
import 'package:drama_client/features/wallet/data/wallet_repository_provider.dart';

void main() {
  test('all remote API switches default to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(useRemoteDramaApiProvider), isFalse);
    expect(container.read(useRemotePlayerApiProvider), isFalse);
    expect(container.read(useRemoteMyListApiProvider), isFalse);
    expect(container.read(useRemoteWalletApiProvider), isFalse);
    expect(container.read(useRemoteStoreApiProvider), isFalse);
    expect(container.read(useRemoteMembershipApiProvider), isFalse);
    expect(container.read(useRemoteEntitlementApiProvider), isFalse);
    expect(container.read(useRemoteAuthApiProvider), isFalse);
    expect(container.read(useRemoteProfileApiProvider), isFalse);
  });
}
