import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'ai_provider_exception.dart';
import 'ai_task.dart';

/// Runs one generation on the model [route] names, and returns only a
/// successful result. Every failure, thrown or returned, comes out as an
/// [AiProviderException], so a provider's raw error never reaches a screen.
///
/// Server errors and timeouts are retried. Rate limits and billing errors are
/// not: another try a few seconds later won't succeed, and the lifter should
/// hear about it straight away.
Future<GenerateResult<O>> generateWithRoute<O>(
  Genkit ai,
  AiRoute route, {
  String? system,
  String? prompt,
  List<Part>? promptParts,
  SchemanticType<O>? outputSchema,
  Map<String, dynamic>? config,
  CancellationToken? cancel,
  Duration timeout = const Duration(minutes: 3),
  Duration retryDelay = const Duration(seconds: 2),
}) async {
  final GenerateResult<O> result;
  try {
    result = await ai
        .generate<O, dynamic>(
          model: modelRef(route.modelName),
          system: system,
          prompt: prompt,
          promptParts: promptParts,
          outputSchema: outputSchema,
          config: config,
          cancel: cancel,
          use: [
            retry(
              maxRetries: 3,
              statuses: const [StatusCode.unavailable, StatusCode.deadlineExceeded, StatusCode.internal],
              initialDelay: retryDelay,
              maxDelay: const Duration(seconds: 20),
            ),
          ],
        )
        .timeout(timeout);
  } catch (e) {
    throw aiExceptionFrom(e, provider: route.cloud);
  }
  throwIfFailed(result, provider: route.cloud);
  return result;
}
