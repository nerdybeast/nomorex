import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_provider_exception.dart';

AiErrorCode codeOf(Object error) => aiExceptionFrom(error, provider: CloudAiProvider.anthropic).code;

GenkitException ex(StatusCode status, [String message = 'API error']) => GenkitException(message, status: status);

void main() {
  group('aiExceptionFrom', () {
    test('a refused key', () {
      expect(codeOf(ex(StatusCode.unauthenticated)), AiErrorCode.invalidKey);
      expect(codeOf(ex(StatusCode.permissionDenied)), AiErrorCode.invalidKey);
    });

    test('billing, however each provider words it', () {
      // Anthropic: a 400.
      expect(
        codeOf(ex(StatusCode.invalidArgument, 'Your credit balance is too low to access the Anthropic API.')),
        AiErrorCode.billing,
      );
      // OpenAI: a 429.
      expect(codeOf(ex(StatusCode.resourceExhausted, 'insufficient_quota: You exceeded your current quota')),
          AiErrorCode.billing);
    });

    test('rate limits, including Gemini free-tier per-minute quotas', () {
      expect(codeOf(ex(StatusCode.resourceExhausted, 'Rate limit reached')), AiErrorCode.rateLimited);
      expect(
        codeOf(ex(StatusCode.resourceExhausted,
            'Quota exceeded for metric: generate_content_free_tier_requests, limit: 10 per minute')),
        AiErrorCode.rateLimited,
      );
    });

    test('provider outages', () {
      expect(codeOf(ex(StatusCode.unavailable, 'This model is currently experiencing high demand')),
          AiErrorCode.unavailable);
      expect(codeOf(ex(StatusCode.internal)), AiErrorCode.unavailable);
      expect(codeOf(ex(StatusCode.deadlineExceeded)), AiErrorCode.unavailable);
      expect(codeOf(ex(StatusCode.unknown, 'Overloaded (529)')), AiErrorCode.unavailable);
      expect(codeOf(TimeoutException('slow')), AiErrorCode.unavailable);
    });

    test('network failures, even wrapped', () {
      expect(codeOf(http.ClientException('Failed host lookup')), AiErrorCode.network);
      expect(
        codeOf(GenkitException('Anthropic API error', cause: http.ClientException('Connection reset'))),
        AiErrorCode.network,
      );
    });

    test('input too long', () {
      expect(codeOf(ex(StatusCode.invalidArgument, 'prompt is too long: 250000 tokens > 200000 maximum')),
          AiErrorCode.tooLong);
      expect(codeOf(ex(StatusCode.invalidArgument, "This model's maximum context length is 128000 tokens")),
          AiErrorCode.tooLong);
    });

    test('anything else is unknown, and an existing exception passes through', () {
      expect(codeOf(ex(StatusCode.invalidArgument, 'bad request')), AiErrorCode.unknown);
      expect(codeOf(StateError('?')), AiErrorCode.unknown);
      final original = AiProviderException(AiErrorCode.refused);
      expect(aiExceptionFrom(original), same(original));
    });
  });

  group('messages', () {
    test('never show the provider error and name the provider', () {
      final e = aiExceptionFrom(
        ex(StatusCode.unauthenticated, 'invalid x-api-key sk-ant-api03-secret'),
        provider: CloudAiProvider.anthropic,
      );
      expect(e.message, contains('Claude'));
      expect(e.message, isNot(contains('sk-ant')));
      expect(e.message, isNot(contains('x-api-key')));
    });

    test('every code has a message, on device and in the cloud', () {
      for (final code in AiErrorCode.values) {
        for (final provider in [null, ...CloudAiProvider.values]) {
          expect(aiErrorMessage(code, provider), isNotEmpty);
        }
      }
    });
  });
}
