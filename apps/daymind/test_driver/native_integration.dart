import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// The SDK's supported drive adapter reports every assertion from the original
/// integration_test target and exits nonzero if any test fails.
Future<void> main() => integrationDriver(
  timeout: Duration(
    minutes:
        Platform.environment['DAYMIND_RESOURCE_SOAK'] == 'true' ||
            const bool.fromEnvironment('RUN_RESOURCE_SOAK')
        ? 12
        : 5,
  ),
  responseDataCallback: null,
);
