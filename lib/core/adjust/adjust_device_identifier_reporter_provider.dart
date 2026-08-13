import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client_provider.dart';
import 'adjust_device_identifier_reporter.dart';

final adjustDeviceIdentifierReporterProvider =
    Provider<AdjustDeviceIdentifierReporter>((ref) {
      return AdjustDeviceIdentifierReporter(
        apiClient: ref.watch(apiClientProvider),
      );
    });
