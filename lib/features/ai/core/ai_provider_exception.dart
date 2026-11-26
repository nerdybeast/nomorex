import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

import 'ai_provider.dart';

/// Why a model call failed, in terms a lifter can act on.
enum AiErrorCode {
  /// The key was refused: wrong, revoked, or missing a permission.
  invalidKey,

  /// The account is out of credit or over its plan's limit.
  billing,

  /// Too many requests in a short time.
  rateLimited,

  /// The provider is down or overloaded.
  unavailable,

  /// The device couldn't reach the provider.
  network,

  /// The input, or the answer it needed, is more than the model takes.
  tooLong,

  /// The model declined, usually from a safety filter.
  refused,

  /// The run was stopped before it finished, usually by the lifter.
  cancelled,

  /// Anything else.
  unknown,
}

/// A failed model call. [message] is safe to show; the provider's own error
/// stays in [cause] for logging and never reaches the screen.
class AiProviderException implements Exception {
  AiProviderException(this.code, {this.provider, this.cause});

  final AiErrorCode code;

  /// Null for the on-device model.
  final CloudAiProvider? provider;
  final Object? cause;

  String get message => aiErrorMessage(code, provider);

  @override
  String toString() => 'AiProviderException(${code.name}, ${provider?.id ?? 'on_device'})';
}

/// The message shown for [code], naming the provider where that helps.
String aiErrorMessage(AiErrorCode code, CloudAiProvider? provider) {
  final name = provider?.label;
  return switch (code) {
    AiErrorCode.invalidKey =>
      name == null
          ? "The on-device model couldn't be used."
          : '$name didn\'t accept your API key. Check it in AI assistant settings.',
    AiErrorCode.billing =>
      name == null
          ? "The on-device model couldn't be used."
          : 'Your $name account is out of credit or over its usage limit. Check your plan on $name\'s site.',
    AiErrorCode.rateLimited => '${name ?? 'The model'} is getting too many requests. Wait a minute, then try again.',
    AiErrorCode.unavailable => "${name ?? 'The on-device model'} isn't available right now. Try again in a moment.",
    AiErrorCode.network => "Couldn't reach ${name ?? 'the model'}. Check your connection and try again.",
    AiErrorCode.tooLong => 'That was too much for ${name ?? 'the on-device model'} to read in one go.',
    AiErrorCode.refused => '${name ?? 'The model'} declined to answer that.',
    AiErrorCode.cancelled => 'Stopped.',
    AiErrorCode.unknown => "Something went wrong with ${name ?? 'the on-device model'}. Try again in a moment.",
  };
}

/// Maps whatever a model call threw, or a failed result's cause, onto an
/// [AiProviderException].
AiProviderException aiExceptionFrom(Object error, {CloudAiProvider? provider}) {
  if (error is AiProviderException) return error;
  return AiProviderException(_codeFor(error), provider: provider, cause: error);
}

/// Checks a finished generation. Genkit doesn't throw when a model fails: it
/// returns [FinishReason.failed] with the error as the result's cause.
void throwIfFailed(GenerateResult result, {CloudAiProvider? provider}) {
  final reason = result.finishReason;
  if (reason == FinishReason.aborted) {
    throw AiProviderException(AiErrorCode.cancelled, provider: provider, cause: result.cause ?? result.finishMessage);
  }
  if (reason == FinishReason.failed) {
    throw aiExceptionFrom(
      result.cause ??
          GenkitException(
            result.finishMessage ?? 'generation failed',
            status: StatusCode.fromWireName(result.error?.status ?? ''),
          ),
      provider: provider,
    );
  }
  if (reason == FinishReason.blocked) {
    throw AiProviderException(AiErrorCode.refused, provider: provider, cause: result.finishMessage);
  }
  if (reason == FinishReason.length) {
    throw AiProviderException(AiErrorCode.tooLong, provider: provider, cause: result.finishMessage);
  }
}

AiErrorCode _codeFor(Object error) {
  // Network failures arrive wrapped, so check every cause in the chain.
  for (Object? e = error; e != null; e = e is GenkitException ? e.cause : null) {
    if (e is http.ClientException) return AiErrorCode.network;
    if (e is TimeoutException) return AiErrorCode.unavailable;
  }
  if (error is! GenkitException) return AiErrorCode.unknown;

  final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
  bool mentions(List<String> words) => words.any(text.contains);
  // Anthropic reports an empty balance as a 400; OpenAI and Gemini as a 429.
  const billingWords = ['credit balance', 'billing', 'insufficient_quota', 'quota'];
  const tooLongWords = ['too long', 'context length', 'context window', 'maximum context', 'too many tokens'];

  return switch (error.status) {
    StatusCode.unauthenticated || StatusCode.permissionDenied => AiErrorCode.invalidKey,
    // Gemini's free tier words its per-minute limit as a quota too.
    StatusCode.resourceExhausted =>
      mentions(billingWords) && !mentions(['per minute', 'perminute', 'per_minute'])
          ? AiErrorCode.billing
          : AiErrorCode.rateLimited,
    StatusCode.invalidArgument || StatusCode.failedPrecondition || StatusCode.outOfRange =>
      mentions(billingWords)
          ? AiErrorCode.billing
          : mentions(tooLongWords)
          ? AiErrorCode.tooLong
          : AiErrorCode.unknown,
    StatusCode.unavailable || StatusCode.deadlineExceeded || StatusCode.internal => AiErrorCode.unavailable,
    _ =>
      mentions(['overloaded', '529', 'high demand'])
          ? AiErrorCode.unavailable
          : mentions(billingWords)
          ? AiErrorCode.billing
          : AiErrorCode.unknown,
  };
}
