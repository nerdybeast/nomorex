import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/providers/ai_import_jobs_provider.dart';

import 'ai_import_job_fakes.dart';

void main() {
  late FakeJobServer server;
  late FakeSubscriber subscriber;
  late ProviderContainer container;

  ProviderContainer start({List<dynamic>? jobs}) {
    server.jobs['u1'] = [...?jobs?.cast()];
    container = ProviderContainer(overrides: jobOverrides(server, subscriber));
    container.listen(aiImportJobWatchProvider, (_, _) {});
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    server = FakeJobServer();
    subscriber = FakeSubscriber();
  });

  tearDown(() => container.dispose());

  test('reads the signed-in user\'s jobs', () async {
    start(jobs: [testJob('a', 'ready')]);
    final jobs = await container.read(aiImportJobsProvider.future);
    expect(jobs.map((j) => j.id), ['a']);
    expect(server.fetchedFor, ['u1']);
  });

  test('signing out empties the list without a read', () async {
    start(jobs: [testJob('a', 'ready')]);
    await container.read(aiImportJobsProvider.future);

    container.read(testUserProvider.notifier).set(null);
    expect(await container.read(aiImportJobsProvider.future), isEmpty);
    expect(server.fetches, 1);
  });

  test('does not subscribe when nothing is processing', () async {
    start(jobs: [testJob('a', 'ready'), testJob('b', 'failed')]);
    await container.read(aiImportJobsProvider.future);
    await settle();
    expect(subscriber.subscribes, 0);
  });

  test('subscribes while a job is processing, and re-reads on each change', () async {
    start(jobs: [testJob('a', 'processing')]);
    await container.read(aiImportJobsProvider.future);
    await settle();
    expect(subscriber.subscribed, isTrue);
    expect(subscriber.userId, 'u1');

    final before = server.fetches;
    subscriber.onChange!(); // e.g. the channel connected
    await container.read(aiImportJobsProvider.future);
    expect(server.fetches, before + 1);
    expect(subscriber.subscribes, 1, reason: 'a re-read with the same job keeps the same channel');
  });

  test('unsubscribes once the job finishes', () async {
    start(jobs: [testJob('a', 'processing')]);
    await container.read(aiImportJobsProvider.future);
    await settle();

    server.jobs['u1'] = [testJob('a', 'ready')];
    subscriber.onChange!();
    await container.read(aiImportJobsProvider.future);
    await settle();

    expect(subscriber.subscribed, isFalse);
    expect(container.read(aiImportJobsProvider).value!.single.status, 'ready');
  });

  test('unsubscribes on sign-out', () async {
    start(jobs: [testJob('a', 'processing')]);
    await container.read(aiImportJobsProvider.future);
    await settle();
    expect(subscriber.subscribed, isTrue);

    container.read(testUserProvider.notifier).set(null);
    await settle();
    expect(subscriber.subscribed, isFalse);
  });

  test('a job already past its time limit isn\'t waited on', () async {
    start(jobs: [testJob('a', 'processing', age: const Duration(minutes: 5))]);
    await container.read(aiImportJobsProvider.future);
    await settle();
    expect(subscriber.subscribes, 0);
  });

  test('discard removes the job and re-reads', () async {
    start(jobs: [testJob('a', 'failed'), testJob('b', 'ready')]);
    await container.read(aiImportJobsProvider.future);

    await container.read(aiImportJobsProvider.notifier).discard('a');
    expect(server.discarded, ['a']);
    expect(container.read(aiImportJobsProvider).value!.map((j) => j.id), ['b']);
  });
}
