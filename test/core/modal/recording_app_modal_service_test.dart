import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
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
  });
}
