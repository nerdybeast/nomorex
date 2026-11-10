import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nomorex/features/ai/models/ai_import_job.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_gate_provider.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/providers/ai_import_jobs_provider.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User testUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-15T00:00:00Z',
);

AiImportJob testJob(
  String id,
  String status, {
  Duration age = const Duration(seconds: 10),
  String? failureCode,
  String? type = 'workout',
}) => AiImportJob(
  id: id,
  importId: 'import-$id',
  status: status,
  startedAt: DateTime.now().subtract(age),
  detectedType: type,
  failureCode: failureCode ?? (status == 'failed' ? 'no_workout_found' : null),
);

/// The signed-in user, changeable from a test.
class TestUser extends Notifier<User?> {
  TestUser(this.initial);
  final User? initial;

  @override
  User? build() => initial;

  void set(User? user) => state = user;
}

/// A server that holds each user's jobs and counts reads and discards.
class FakeJobServer {
  final Map<String, List<AiImportJob>> jobs = {};
  final List<String> fetchedFor = [];
  final List<String> discarded = [];

  int get fetches => fetchedFor.length;
}

class FakeJobsNotifier extends AiImportJobsNotifier {
  FakeJobsNotifier(this.server);
  final FakeJobServer server;

  @override
  Future<List<AiImportJob>> fetchJobs(String userId) async {
    server.fetchedFor.add(userId);
    return List.of(server.jobs[userId] ?? const []);
  }

  @override
  Future<void> discardJob(String jobId) async {
    server.discarded.add(jobId);
    for (final list in server.jobs.values) {
      list.removeWhere((j) => j.id == jobId);
    }
  }
}

/// Records Realtime subscriptions instead of opening a socket.
class FakeSubscriber {
  int subscribes = 0;
  int unsubscribes = 0;
  String? userId;
  void Function()? onChange;

  bool get subscribed => subscribes > unsubscribes;

  AiImportJobSubscriber get fn => (uid, cb) {
    subscribes++;
    userId = uid;
    onChange = cb;
    return () {
      unsubscribes++;
      onChange = null;
    };
  };
}

const testLimits = AiImportLimits(
  maxImages: 8,
  maxPdfPages: 10,
  maxImageBytes: 7000000,
  maxPdfBytes: 20000000,
  maxJobSeconds: 180,
);

final testUserProvider = NotifierProvider<TestUser, User?>(() => TestUser(testUser('u1')));

/// Overrides for a signed-in user (switchable through [testUserProvider])
/// with no network.
List<Override> jobOverrides(
  FakeJobServer server,
  FakeSubscriber subscriber, {
  User? user,
  AiImportLimits limits = testLimits,
}) => [
  testUserProvider.overrideWith(() => TestUser(user ?? testUser('u1'))),
  currentAuthUserProvider.overrideWith((ref) => ref.watch(testUserProvider)),
  aiImportJobsProvider.overrideWith(() => FakeJobsNotifier(server)),
  aiImportJobSubscriberProvider.overrideWithValue(subscriber.fn),
  aiImportLimitsProvider.overrideWith((ref) async => limits),
];

/// The import screen's up-front check, answering [check] until the notice is
/// accepted (which records it and then allows the import).
class FakeGate extends AiImportGateNotifier {
  FakeGate(this.check, {this.consentError});

  AiImportCheck check;
  final Object? consentError;
  int consents = 0;

  /// Answers without looking up the user, so screens tested signed out work.
  @override
  Future<AiImportCheck> build() => fetchCheck();

  @override
  Future<AiImportCheck> fetchCheck() async => check;

  @override
  Future<void> recordConsent(String userId) async {
    if (consentError case final e?) throw e;
    consents++;
    check = const AiImportCheck(allowed: true);
  }
}
