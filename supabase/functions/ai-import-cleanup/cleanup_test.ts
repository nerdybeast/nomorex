import { assertEquals } from 'jsr:@std/assert@1';
import { type CleanupDeps, createHandler, type Folder, runCleanup } from './cleanup.ts';

const SECRET = 'a-test-secret-that-is-long-enough-123';

/** An in-memory bucket. `failOn` makes removing that folder's files throw. */
function fakeStorage(files: Record<string, string[]>, sweepResult: Folder[], failOn = new Set<string>()) {
  const removed: string[] = [];
  let sweeps = 0;
  const deps: CleanupDeps = {
    sweep: () => {
      sweeps++;
      return Promise.resolve(sweepResult);
    },
    list: (prefix, limit) => Promise.resolve((files[prefix] ?? []).slice(0, limit)),
    remove: (paths) => {
      const prefix = paths[0].split('/').slice(0, 2).join('/');
      if (failOn.has(prefix)) return Promise.reject(new Error('storage unavailable'));
      removed.push(...paths);
      files[prefix] = (files[prefix] ?? []).filter((n) => !paths.includes(`${prefix}/${n}`));
      return Promise.resolve();
    },
  };
  return { deps, removed, files, sweeps: () => sweeps };
}

const post = (headers: Record<string, string> = { Authorization: `Bearer ${SECRET}` }, method = 'POST') =>
  new Request('http://localhost/ai-import-cleanup', { method, headers });

Deno.test('deletes the files of every folder the sweep returns, and only those', async () => {
  const s = fakeStorage(
    { 'u1/i1': ['page-1.jpg', 'page-2.jpg'], 'u2/i2': ['page-1.pdf'], 'u1/keep': ['page-1.jpg'] },
    [{ user_id: 'u1', import_id: 'i1' }, { user_id: 'u2', import_id: 'i2' }],
  );
  const report = await runCleanup(s.deps);
  assertEquals(report, { folders: 2, files: 3, failed: 0 });
  assertEquals(s.removed.sort(), ['u1/i1/page-1.jpg', 'u1/i1/page-2.jpg', 'u2/i2/page-1.pdf']);
  assertEquals(s.files['u1/keep'], ['page-1.jpg'], 'a folder the sweep kept is untouched');
});

Deno.test('empties a folder larger than one page', async () => {
  const many = Array.from({ length: 250 }, (_, i) => `f${i}.jpg`);
  const s = fakeStorage({ 'u1/i1': many }, [{ user_id: 'u1', import_id: 'i1' }]);
  const report = await runCleanup(s.deps);
  assertEquals(report.files, 250);
  assertEquals(s.files['u1/i1'], []);
});

Deno.test('a folder that fails is reported and the rest still go', async () => {
  const s = fakeStorage(
    { 'u1/bad': ['page-1.jpg'], 'u1/ok': ['page-1.jpg'] },
    [{ user_id: 'u1', import_id: 'bad' }, { user_id: 'u1', import_id: 'ok' }],
    new Set(['u1/bad']),
  );
  const report = await runCleanup(s.deps);
  assertEquals(report, { folders: 2, files: 1, failed: 1 });
  assertEquals(s.files['u1/bad'], ['page-1.jpg'], 'left for the next run to retry');
});

Deno.test('an already empty folder is fine', async () => {
  const s = fakeStorage({}, [{ user_id: 'u1', import_id: 'gone' }]);
  assertEquals(await runCleanup(s.deps), { folders: 1, files: 0, failed: 0 });
});

Deno.test('the scheduler with the secret runs the cleanup', async () => {
  const s = fakeStorage({ 'u1/i1': ['page-1.jpg'] }, [{ user_id: 'u1', import_id: 'i1' }]);
  const res = await createHandler(SECRET, () => s.deps)(post());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { folders: 1, files: 1, failed: 0 });
});

Deno.test('a partial failure fails the run, so it shows in Actions', async () => {
  const s = fakeStorage({ 'u1/i1': ['a.jpg'] }, [{ user_id: 'u1', import_id: 'i1' }], new Set(['u1/i1']));
  const res = await createHandler(SECRET, () => s.deps)(post());
  assertEquals(res.status, 500);
  assertEquals((await res.json()).failed, 1);
});

Deno.test('refuses callers without the secret, before touching anything', async () => {
  const s = fakeStorage({ 'u1/i1': ['page-1.jpg'] }, [{ user_id: 'u1', import_id: 'i1' }]);
  const handler = createHandler(SECRET, () => s.deps);
  for (
    const headers of <Record<string, string>[]> [
      {},
      { Authorization: 'Bearer wrong' },
      { Authorization: SECRET },
      { Authorization: `Bearer ${SECRET}x` },
      // A user's session token is not the secret.
      { Authorization: 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSJ9.sig' },
    ]
  ) {
    const res = await handler(post(headers));
    assertEquals(res.status, 401, JSON.stringify(headers));
    await res.body?.cancel();
  }
  assertEquals(s.sweeps(), 0);
  assertEquals(s.removed, []);
});

Deno.test('refuses everyone when the secret is unset or too short', async () => {
  for (const secret of [undefined, '', 'short']) {
    const s = fakeStorage({}, []);
    const res = await createHandler(secret, () => s.deps)(post({ Authorization: `Bearer ${secret}` }));
    assertEquals(res.status, 503);
    await res.body?.cancel();
    assertEquals(s.sweeps(), 0);
  }
});

Deno.test('only POST runs it', async () => {
  const s = fakeStorage({}, []);
  const res = await createHandler(SECRET, () => s.deps)(post({ Authorization: `Bearer ${SECRET}` }, 'GET'));
  assertEquals(res.status, 405);
  await res.body?.cancel();
  assertEquals(s.sweeps(), 0);
});
