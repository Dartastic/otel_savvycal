// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_savvycal/otel_savvycal.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_savvycal-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('links.create records kind + ranked_availability', () async {
    await tracedSavvycal<String>(
      operation: 'links.create',
      userId: 'u-1',
      invoke: () async => const SavvycalCallResult(
        value: 'ok',
        result: SavvycalResult(
          linkKind: 'team',
          rankedAvailability: true,
          tier: 'team',
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('savvycal links.create')!);
    expect(a['savvycal.link.kind'], 'team');
    expect(a['savvycal.ranked_availability'], true);
    expect(a['savvycal.tier'], 'team');
  });

  test('poll responses recorded', () async {
    await tracedSavvycal<String>(
      operation: 'polls.responses.list',
      invoke: () async => const SavvycalCallResult(
        value: 'ok',
        result: SavvycalResult(
          linkKind: 'poll',
          pollResponses: 23,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('savvycal polls.responses.list')!);
    expect(a['savvycal.poll.responses_count'], 23);
  });

  test('suppression skips spans', () async {
    await runWithoutSavvycalInstrumentationAsync(() async {
      await tracedSavvycal<String>(
        operation: 'links.list',
        invoke: () async => const SavvycalCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('savvycal '), isEmpty);
  });
}
