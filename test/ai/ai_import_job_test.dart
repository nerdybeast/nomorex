import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/models/ai_import_job.dart';
import 'package:nomorex/features/ai/utils/import_alert_tracker.dart';

import 'ai_import_job_fakes.dart';

void main() {
  final now = DateTime.now();

  group('AiImportJob', () {
    test('reads a job row', () {
      final job = AiImportJob.fromJson({
        'id': 'j1',
        'import_id': 'i1',
        'status': 'ready',
        'started_at': '2026-11-10T02:38:15.241414+00:00',
        'finished_at': '2026-11-10T02:38:29.62327+00:00',
        'requested_type': null,
        'detected_type': 'program',
        'failure_code': null,
      });
      expect(job.status, 'ready');
      expect(job.type, 'program');
      expect(job.startedAt, DateTime.utc(2026, 11, 10, 2, 38, 15, 241, 414));
      expect(job.finishedAt, isNotNull);
    });

    test('the requested type wins over the detected one', () {
      final job = AiImportJob(
        id: 'j',
        importId: 'i',
        status: 'ready',
        startedAt: now,
        requestedType: 'program',
        detectedType: 'workout',
      );
      expect(job.type, 'program');
    });

    test('a processing job past the time limit shows as failed', () {
      final fresh = testJob('a', 'processing', age: const Duration(seconds: 179));
      final dead = testJob('b', 'processing', age: const Duration(seconds: 181));

      expect(fresh.state(now, 180), AiImportJobState.processing);
      expect(dead.state(now, 180), AiImportJobState.failed);
      expect(dead.failureMessage(now, 180), contains('stopped before it finished'));
      expect(dead.canDiscard, isFalse, reason: 'still processing on the server until the sweep');
    });

    test('finished-with jobs are not shown', () {
      for (final status in ['accepted', 'discarded', 'replaced']) {
        expect(testJob('x', status).state(now, 180), isNull, reason: status);
      }
    });

    test('every failure code has a message', () {
      for (final code in [
        'no_workout_found',
        'invalid_file',
        'unreadable_file',
        'timeout',
        'model_error',
        'invalid_output',
        'internal_error',
        'abandoned',
      ]) {
        final message = testJob('x', 'failed', failureCode: code).failureMessage(now, 180);
        expect(message, isNotEmpty, reason: code);
        expect(message, isNot(contains(code)), reason: 'no raw codes shown');
      }
    });
  });

  group('ImportAlertTracker', () {
    late ImportAlertTracker tracker;
    setUp(() => tracker = ImportAlertTracker());

    List<String> update(List<dynamic> jobs) =>
        tracker.update(jobs.cast(), DateTime.now(), 180).map((j) => j.id).toList();

    test('jobs already finished at launch don\'t alert', () {
      expect(update([testJob('a', 'ready'), testJob('b', 'failed')]), isEmpty);
    });

    test('a job alerts once when it finishes, however often it\'s re-read', () {
      expect(update([testJob('a', 'processing')]), isEmpty);
      expect(update([testJob('a', 'ready')]), ['a']);
      expect(update([testJob('a', 'ready')]), isEmpty);
      expect(update([testJob('a', 'ready')]), isEmpty);
    });

    test('a failure alerts too', () {
      update([testJob('a', 'processing')]);
      expect(update([testJob('a', 'failed')]), ['a']);
    });

    test('a job that dies past its time limit alerts as failed', () {
      update([testJob('a', 'processing', age: const Duration(seconds: 100))]);
      expect(update([testJob('a', 'processing', age: const Duration(seconds: 200))]), ['a']);
    });

    test('a job first seen already finished after launch alerts', () {
      update(<dynamic>[]);
      expect(update([testJob('a', 'ready')]), ['a']);
    });

    test('reset starts a new baseline', () {
      update([testJob('a', 'processing')]);
      tracker.reset();
      expect(update([testJob('a', 'ready')]), isEmpty);
    });
  });
}
