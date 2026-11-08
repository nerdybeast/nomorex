import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase Edge Function that serves every Genkit flow
/// (`supabase/functions/ai`). A flow named `fooBar` is at `ai/fooBar`.
const kAiFunctionName = 'ai';

/// A failed Genkit flow call, normalized from whatever layer failed: the flow
/// itself, the Supabase gateway in front of it, or the network.
class GenkitFlowException implements Exception {
  const GenkitFlowException(this.status, this.message, {this.httpStatus});

  /// A Genkit status name (`UNAUTHENTICATED`, `UNAVAILABLE`,
  /// `INVALID_ARGUMENT`, …), or `NETWORK` / `UNKNOWN` for failures that never
  /// produced a Genkit error.
  final String status;

  /// Safe to show the user: the function only puts user-facing text here and
  /// logs provider details server-side.
  final String message;

  /// HTTP status, `0` when no response arrived.
  final int? httpStatus;

  /// The caller's session is missing or invalid; the AI service itself may be
  /// fine. The function maps provider auth failures (a bad API key) to
  /// `UNAVAILABLE`, so this always means the user's session.
  bool get isUnauthenticated => status == 'UNAUTHENTICATED';

  @override
  String toString() => 'GenkitFlowException($status: $message)';
}

/// Calls the Genkit flow [flow] with [input] and returns its `result`.
///
/// Goes through `functions.invoke`, which attaches the user's session JWT
/// (and the publishable key) automatically: the function authenticates the
/// caller from that JWT and queries the database as them, under RLS.
///
/// Throws [GenkitFlowException] on any failure.
Future<Object?> callGenkitFlow(
  FunctionsClient functions,
  String flow, [
  Map<String, Object?> input = const {},
]) async {
  try {
    // Genkit's HTTP protocol wraps flow input as {"data": …}.
    final res = await functions.invoke('$kAiFunctionName/$flow', body: {'data': input});
    return unwrapGenkitResult(res.data);
  } on FunctionsFetchException {
    throw const GenkitFlowException(
      'NETWORK',
      "Couldn't reach the AI service. Check your connection and try again.",
      httpStatus: 0,
    );
  } on FunctionException catch (e) {
    throw genkitErrorFrom(e.status, e.details);
  }
}

/// Unwraps a successful Genkit response body, `{"result": …}`.
Object? unwrapGenkitResult(Object? body) {
  if (body is Map && body.containsKey('result')) return body['result'];
  throw const GenkitFlowException('UNKNOWN', 'Unexpected response from the AI service.');
}

/// Maps a non-2xx response to a [GenkitFlowException].
///
/// A flow error is `{"status", "message"}` (a streamed failure nests the same
/// under `"error"`). Anything else came from the gateway before the flow ran
/// (e.g. the platform JWT check, or a worker that failed to boot) and isn't
/// Genkit-shaped, so it's classified by HTTP status alone.
GenkitFlowException genkitErrorFrom(int httpStatus, Object? body) {
  final err = body is Map && body['error'] is Map ? body['error'] : body;
  if (err is Map && err['status'] is String) {
    final message = err['message'];
    return GenkitFlowException(
      err['status'] as String,
      message is String && message.isNotEmpty ? message : 'The AI request failed.',
      httpStatus: httpStatus,
    );
  }
  if (httpStatus == 401) {
    return GenkitFlowException('UNAUTHENTICATED', 'Sign in to use AI features.', httpStatus: httpStatus);
  }
  return GenkitFlowException('UNKNOWN', 'The AI request failed (HTTP $httpStatus).', httpStatus: httpStatus);
}
