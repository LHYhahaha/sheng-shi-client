import 'package:drama_client/core/adjust/adjust_event_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports app_first_open with the required Adjust token', () async {
    final client = _RecordingEventClient();
    final reporter = AdjustEventReporter(
      eventClient: client,
      homeFirstViewStore: _FirstViewStore(),
    );

    reporter.reportAppFirstOpen();
    await Future<void>.delayed(Duration.zero);

    expect(client.events, [
      const _RecordedEvent(AdjustEventTokens.appFirstOpen, {}),
    ]);
  });

  test('reports checkout_start with the required product parameters', () async {
    final client = _RecordingEventClient();
    final reporter = AdjustEventReporter(
      eventClient: client,
      homeFirstViewStore: _FirstViewStore(),
    );

    reporter.reportCheckoutStart(
      productType: 'coin',
      productId: '1001',
      price: 4.99,
      currency: 'USD',
    );
    await Future<void>.delayed(Duration.zero);

    expect(client.events, [
      const _RecordedEvent(AdjustEventTokens.checkoutStart, {
        'product_type': 'coin',
        'product_id': '1001',
        'price': '4.99',
        'currency': 'USD',
      }),
    ]);
  });

  test('reports home_first_view once per device store', () async {
    final client = _RecordingEventClient();
    final reporter = AdjustEventReporter(
      eventClient: client,
      homeFirstViewStore: _FirstViewStore(),
    );

    await reporter.reportHomeFirstView();
    await reporter.reportHomeFirstView();

    expect(client.events, [
      const _RecordedEvent(AdjustEventTokens.homeFirstView, {}),
    ]);
  });

  test('requests pending Adjust event recovery at startup', () async {
    final client = _RecordingEventClient();
    final reporter = AdjustEventReporter(
      eventClient: client,
      homeFirstViewStore: _FirstViewStore(),
    );

    await reporter.recoverPendingEvents();

    expect(client.recoveryRequested, isTrue);
  });
}

class _RecordingEventClient implements AdjustEventClient {
  final events = <_RecordedEvent>[];
  var recoveryRequested = false;

  @override
  Future<void> recoverPendingEvents() async {
    recoveryRequested = true;
  }

  @override
  void track(String eventToken, {Map<String, String> parameters = const {}}) {
    events.add(_RecordedEvent(eventToken, parameters));
  }
}

class _FirstViewStore implements AdjustHomeFirstViewStore {
  var _reported = false;

  @override
  Future<bool> markReportedIfNeeded() async {
    if (_reported) return false;
    _reported = true;
    return true;
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.eventToken, this.parameters);

  final String eventToken;
  final Map<String, String> parameters;

  @override
  bool operator ==(Object other) =>
      other is _RecordedEvent &&
      other.eventToken == eventToken &&
      _mapsEqual(other.parameters, parameters);

  @override
  int get hashCode =>
      Object.hash(eventToken, Object.hashAll(parameters.entries));
}

bool _mapsEqual(Map<String, String> first, Map<String, String> second) =>
    first.length == second.length &&
    first.entries.every((entry) => second[entry.key] == entry.value);
