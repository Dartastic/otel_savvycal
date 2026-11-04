// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_savvycal_suppression.dart';

const _tracerName = 'dartastic_otel_libs_savvycal';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SavvycalResult {
  /// Creates a result.
  const SavvycalResult({
    this.itemCount,
    this.linkKind,
    this.status,
    this.rankedAvailability,
    this.pollResponses,
    this.tier,
    this.requestId,
    this.statusCode,
  });

  /// `data.length` for list endpoints.
  final int? itemCount;

  /// `personal` / `team` / `collective` / `round_robin` / `poll`.
  final String? linkKind;

  /// `scheduled` / `canceled` / `pending_confirmation`.
  final String? status;

  /// Whether the link uses ranked availability (the SavvyCal feature
  /// users pay for vs basic Calendly-style picking).
  final bool? rankedAvailability;

  /// Number of poll responses (for poll links).
  final int? pollResponses;

  /// `personal` / `team` / `creator` — affects API rate limits.
  final String? tier;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SavvycalCallResult<T> {
  /// Creates a call result.
  const SavvycalCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SavvycalResult? result;
}

/// Wraps a SavvyCal API call in a CLIENT span. [operation] is one of
/// `links.list`, `links.get`, `links.create`, `links.update`,
/// `scheduled_events.list`, `scheduled_events.cancel`,
/// `polls.responses.list`, `users.me`, `webhooks.create`,
/// `webhooks.delete`.
Future<T> tracedSavvycal<T>({
  required String operation,
  required Future<SavvycalCallResult<T>> Function() invoke,
  String? userId,
}) async {
  if (savvycalInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'savvycal',
    'rpc.method': operation,
    'savvycal.operation': operation,
  };
  if (userId != null) m['savvycal.user.id'] = userId;

  final span = _tracer().startSpan(
    'savvycal $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'savvycal.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.linkKind != null) {
        extras.add(OTelAPI.attributeString(
          'savvycal.link.kind',
          r.result!.linkKind!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTelAPI.attributeString(
          'savvycal.status',
          r.result!.status!,
        ));
      }
      if (r.result!.rankedAvailability != null) {
        extras.add(OTelAPI.attributeBool(
          'savvycal.ranked_availability',
          r.result!.rankedAvailability!,
        ));
      }
      if (r.result!.pollResponses != null) {
        extras.add(OTelAPI.attributeInt(
          'savvycal.poll.responses_count',
          r.result!.pollResponses!,
        ));
      }
      if (r.result!.tier != null) {
        extras.add(OTelAPI.attributeString(
          'savvycal.tier',
          r.result!.tier!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'savvycal.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'SavvyCal HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
