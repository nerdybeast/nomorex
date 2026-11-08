import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { genkit, UserFacingError } from 'genkit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { UserContext } from '../auth.ts';
import { defineSmokeTest, SmokeTestOutput } from './smoke_test.ts';

/** Genkit with no plugins plus a fake model, so tests never call Anthropic. */
function setup(reply: () => Promise<string>) {
  const ai = genkit({});
  const prompts: string[] = [];
  const model = ai.defineModel({ name: 'test/fake' }, async (req) => {
    prompts.push(req.messages.flatMap((m) => m.content.map((c) => c.text ?? '')).join(''));
    return { message: { role: 'model', content: [{ text: await reply() }] } };
  });
  return { flow: defineSmokeTest(ai, model), prompts };
}

/** Context as the auth provider would build it, with a fake exercises query. */
function context(count: number | null, error: { message: string } | null = null): UserContext {
  const supabase = {
    from: (table: string) => {
      assertEquals(table, 'exercises');
      return { select: () => Promise.resolve({ count, error }) };
    },
  } as unknown as SupabaseClient;
  return { auth: { uid: 'user-123' }, supabase };
}

Deno.test('returns the caller uid, their exercise count and the model reply', async () => {
  const { flow, prompts } = setup(() => Promise.resolve('  Connected! 42 exercises.  '));

  const out = await flow({}, { context: context(42) });

  assertEquals(SmokeTestOutput.parse(out), out);
  assertEquals(out, { uid: 'user-123', exerciseCount: 42, message: 'Connected! 42 exercises.' });
  assertEquals(prompts.length, 1);
  assertEquals(prompts[0].includes('42 exercises'), true, 'count from RLS query goes into the prompt');
});

Deno.test('without the auth context (e.g. run from the Dev UI) it fails UNAUTHENTICATED', async () => {
  const { flow, prompts } = setup(() => Promise.resolve('unused'));
  const err = await assertRejects(() => flow({}), UserFacingError);
  assertEquals(err.status, 'UNAUTHENTICATED');
  assertEquals(prompts.length, 0);
});

Deno.test('treats a null count as zero', async () => {
  const { flow } = setup(() => Promise.resolve('ok'));
  const out = await flow({}, { context: context(null) });
  assertEquals(out.exerciseCount, 0);
});

Deno.test('a model failure surfaces as a generic UNAVAILABLE, not the provider error', async () => {
  const { flow } = setup(() => Promise.reject(new Error('401 invalid x-api-key req_secret')));

  const err = await assertRejects(() => flow({}, { context: context(1) }), UserFacingError);

  assertEquals(err.status, 'UNAVAILABLE');
  assertEquals(err.message.includes('x-api-key'), false, 'must not leak upstream details');
});

Deno.test('a failed exercises query fails the flow before calling the model', async () => {
  const { flow, prompts } = setup(() => Promise.resolve('unused'));
  await assertRejects(
    () => flow({}, { context: context(null, { message: 'boom' }) }),
    Error,
    'exercise count failed',
  );
  assertEquals(prompts.length, 0);
});
