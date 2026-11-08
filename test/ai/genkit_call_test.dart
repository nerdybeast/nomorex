import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/models/smoke_test_result.dart';
import 'package:nomorex/features/ai/utils/genkit_call.dart';

void main() {
  group('unwrapGenkitResult', () {
    test('returns the result field of a success body', () {
      expect(unwrapGenkitResult({'result': {'a': 1}}), {'a': 1});
    });

    test('a null result is still a valid result', () {
      expect(unwrapGenkitResult({'result': null}), isNull);
    });

    test('a body without result is an UNKNOWN error', () {
      expect(
        () => unwrapGenkitResult({'unexpected': true}),
        throwsA(isA<GenkitFlowException>().having((e) => e.status, 'status', 'UNKNOWN')),
      );
      expect(() => unwrapGenkitResult('not json'), throwsA(isA<GenkitFlowException>()));
    });
  });

  group('genkitErrorFrom', () {
    test('reads a flow error body (the shape the function returns)', () {
      final e = genkitErrorFrom(503, {
        'status': 'UNAVAILABLE',
        'message': 'The AI service is unavailable right now. Try again in a moment.',
      });
      expect(e.status, 'UNAVAILABLE');
      expect(e.message, startsWith('The AI service is unavailable'));
      expect(e.httpStatus, 503);
      expect(e.isUnauthenticated, isFalse);
    });

    test('reads a streamed error frame nested under "error"', () {
      final e = genkitErrorFrom(400, {
        'error': {'status': 'INVALID_ARGUMENT', 'message': 'bad input'},
      });
      expect(e.status, 'INVALID_ARGUMENT');
      expect(e.message, 'bad input');
    });

    test('a flow UNAUTHENTICATED error is flagged as a session problem', () {
      final e = genkitErrorFrom(401, {'status': 'UNAUTHENTICATED', 'message': 'Sign in to use AI features.'});
      expect(e.isUnauthenticated, isTrue);
    });

    test('a non-Genkit gateway 401 (platform JWT check) maps to UNAUTHENTICATED', () {
      final e = genkitErrorFrom(401, {'msg': 'Invalid JWT'});
      expect(e.status, 'UNAUTHENTICATED');
      expect(e.isUnauthenticated, isTrue);
    });

    test('a non-Genkit gateway failure (worker boot error) is UNKNOWN with the HTTP status', () {
      final e = genkitErrorFrom(503, {'code': 'BOOT_ERROR', 'message': 'Worker failed to boot'});
      expect(e.status, 'UNKNOWN');
      expect(e.message, contains('503'));
    });

    test('an empty flow message falls back to a generic one', () {
      final e = genkitErrorFrom(500, {'status': 'INTERNAL', 'message': ''});
      expect(e.status, 'INTERNAL');
      expect(e.message, 'The AI request failed.');
    });
  });

  test('SmokeTestResult.fromJson reads the flow output', () {
    final r = SmokeTestResult.fromJson({'uid': 'u1', 'exerciseCount': 42, 'message': 'Connected!'});
    expect(r.uid, 'u1');
    expect(r.exerciseCount, 42);
    expect(r.message, 'Connected!');
  });
}
