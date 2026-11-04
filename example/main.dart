// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_savvycal/otel_savvycal.dart';

/// Traces SavvyCal calls with OpenTelemetry.
///
/// `otel_savvycal` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each SavvyCal call in
/// [tracedSavvycal]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'savvycal-example');

  // Wraps a SavvyCal API call in a CLIENT span.
  final savvycalId = await tracedSavvycal<String>(
    operation: 'links.create',
    userId: 'user_8f3a2c',
    invoke: () async {
      // Make the SavvyCal call here, then report what it returned.
      const id = 'savvycal_8f3a2c';
      return const SavvycalCallResult(
          value: id,
          result: SavvycalResult(
              itemCount: 3,
              linkKind: 'personal',
              status: 'scheduled',
              rankedAvailability: true,
              pollResponses: 1,
              tier: 'personal',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedSavvycal links.create returned $savvycalId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSavvycalInstrumentationAsync.
  await runWithoutSavvycalInstrumentationAsync(
    () => tracedSavvycal<String>(
      operation: 'links.create',
      userId: 'user_8f3a2c',
      invoke: () async {
        const id = 'savvycal_8f3a2c';
        return const SavvycalCallResult(
            value: id,
            result: SavvycalResult(
                itemCount: 3,
                linkKind: 'personal',
                status: 'scheduled',
                rankedAvailability: true,
                pollResponses: 1,
                tier: 'personal',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
