import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adjust_event_reporter.dart';

final adjustEventReporterProvider = Provider<AdjustEventReporter>((ref) {
  return AdjustEventReporter();
});
