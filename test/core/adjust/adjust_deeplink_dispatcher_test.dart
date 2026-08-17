import 'package:drama_client/core/adjust/adjust_deeplink_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwards an Adjust deferred deeplink as a parsed URI', () {
    Uri? received;
    final dispatcher = AdjustDeeplinkDispatcher((uri) => received = uri);

    final dispatched = dispatcher.dispatch(
      'novashort://player?drama_id=1506&landing_type=normal_share',
    );

    expect(dispatched, isTrue);
    expect(received?.scheme, 'novashort');
    expect(received?.host, 'player');
    expect(received?.queryParameters, {
      'drama_id': '1506',
      'landing_type': 'normal_share',
    });
  });

  test('ignores an empty Adjust deferred deeplink', () {
    var receiveCount = 0;
    final dispatcher = AdjustDeeplinkDispatcher((_) => receiveCount++);

    final dispatched = dispatcher.dispatch('   ');

    expect(dispatched, isFalse);
    expect(receiveCount, 0);
  });
}
