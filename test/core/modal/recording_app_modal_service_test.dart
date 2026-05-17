import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_channels.dart';
import 'package:drama_client/features/membership/presentation/modal/membership_modal_channels.dart';
import 'package:drama_client/features/store/presentation/modal/store_modal_channels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_app_modal_service.dart';

void main() {
  group('RecordingAppModalService', () {
    late RecordingAppModalService service;

    setUp(() {
      service = RecordingAppModalService();
    });

    ConfirmModalRequest request(String id) {
      return ConfirmModalRequest(
        requestId: id,
        source: AppModalSource.player,
        priority: AppModalPriority.high,
        title: 'Unlock',
        message: 'Spend coins?',
        confirmLabel: 'Confirm',
        cancelLabel: 'Cancel',
      );
    }

    test('records requests and returns default confirm result', () async {
      final result = await service.showConfirm(request('r1'));

      expect(result, isA<ConfirmResult>());
      expect(result.isConfirmed, isTrue);
      expect(service.requests, hasLength(1));
      expect(service.requests.single.requestId, 'r1');
      expect(service.requests.single.source, AppModalSource.player);
      expect(service.requests.single.priority, AppModalPriority.high);
    });

    test('returns preset result by request id', () async {
      service.presetResultsByRequestId['r2'] = ConfirmResult.cancelled;

      final result = await service.showConfirm(request('r2'));

      expect(result.isCancelled, isTrue);
    });

    test('records multiple generic show calls', () async {
      await service.show(request('a'));
      await service.show(request('b'));

      expect(service.requests, hasLength(2));
      expect(service.requests.map((r) => r.requestId), ['a', 'b']);
    });

    test('records store and membership feature modal requests', () async {
      await service.show(
        FeatureAppModalRequest(
          requestId: 'store_1',
          source: AppModalSource.store,
          channel: StoreModalChannels.purchaseConfirmation,
          type: AppModalType.storeConfirm,
        ),
      );
      await service.show(
        FeatureAppModalRequest(
          requestId: 'membership_1',
          source: AppModalSource.membership,
          channel: MembershipModalChannels.purchaseConfirmation,
          type: AppModalType.membershipPurchase,
        ),
      );

      expect(service.requests, hasLength(2));
      expect(service.requests[0], isA<FeatureAppModalRequest>());
      expect(service.requests[1], isA<FeatureAppModalRequest>());
      service.presetResultsByRequestId['store_1'] =
          const StorePurchaseModalResult.completed();
      service.presetResultsByRequestId['membership_1'] =
          const MembershipPurchaseModalResult.cancelled();

      final storeResult = await service.show(service.requests[0]);
      final membershipResult = await service.show(service.requests[1]);

      expect(storeResult, isA<StorePurchaseModalResult>());
      expect(
        (storeResult as StorePurchaseModalResult).kind,
        AppModalResultKind.completed,
      );
      expect(membershipResult, isA<MembershipPurchaseModalResult>());
      expect(
        (membershipResult as MembershipPurchaseModalResult).kind,
        AppModalResultKind.cancelled,
      );
    });

    test(
      'records auth login modal and returns preset LoginModalResult',
      () async {
        await service.show(
          FeatureAppModalRequest(
            requestId: 'auth_1',
            source: AppModalSource.auth,
            channel: AuthModalChannels.login,
            type: AppModalType.login,
          ),
        );

        service.presetResultsByRequestId['auth_1'] =
            const LoginModalResult.cancelled();
        final result = await service.show(service.requests.last);

        expect(result, isA<LoginModalResult>());
        expect((result as LoginModalResult).isCancelled, isTrue);
      },
    );
  });
}
