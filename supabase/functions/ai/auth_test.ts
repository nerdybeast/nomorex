import { assertEquals, assertRejects, assertStrictEquals } from 'jsr:@std/assert@1';
import { UserFacingError } from 'genkit';
import type { RequestData } from 'genkit/context';
import type { SupabaseClient } from '@supabase/supabase-js';
import { supabaseAuth } from './auth.ts';

type Claims = { sub?: string; role?: string } | null;

/** A fake client whose getClaims returns the given claims (or error). */
function fakeClient(claims: Claims, error: Error | null = null) {
  const calls: string[] = [];
  const client = {
    auth: {
      getClaims: (jwt: string) => {
        calls.push(jwt);
        return Promise.resolve({ data: claims ? { claims } : null, error });
      },
    },
  } as unknown as SupabaseClient;
  return { client, calls };
}

function request(headers: Record<string, string>): RequestData {
  return { method: 'POST', headers, input: {} };
}

/** Runs the provider for `req` and asserts it rejects with UNAUTHENTICATED. */
async function assertUnauthenticated(provider: ReturnType<typeof supabaseAuth>, req: RequestData) {
  // A ContextProvider may return a value or a promise; normalize to a promise.
  const err = await assertRejects(async () => await provider(req), UserFacingError);
  assertEquals(err.status, 'UNAUTHENTICATED');
}

Deno.test('rejects a request with no Authorization header', async () => {
  const { client } = fakeClient({ sub: 'u1', role: 'authenticated' });
  await assertUnauthenticated(supabaseAuth(() => client), request({}));
});

Deno.test('rejects a non-Bearer Authorization header', async () => {
  const { client, calls } = fakeClient({ sub: 'u1', role: 'authenticated' });
  await assertUnauthenticated(supabaseAuth(() => client), request({ authorization: 'Basic abc' }));
  assertEquals(calls.length, 0, 'should not try to verify a malformed header');
});

Deno.test('rejects a token that fails verification', async () => {
  const { client } = fakeClient(null, new Error('invalid JWT'));
  await assertUnauthenticated(supabaseAuth(() => client), request({ authorization: 'Bearer bad' }));
});

Deno.test('rejects a valid JWT that is not a signed-in user (anon key as bearer)', async () => {
  const { client } = fakeClient({ role: 'anon' });
  await assertUnauthenticated(supabaseAuth(() => client), request({ authorization: 'Bearer anon.jwt' }));
});

Deno.test('passes a signed-in user through with their uid and RLS-scoped client', async () => {
  const { client, calls } = fakeClient({ sub: 'user-123', role: 'authenticated' });
  let builtWith = '';
  const provider = supabaseAuth((authorization) => {
    builtWith = authorization;
    return client;
  });

  const ctx = await provider(request({ authorization: 'Bearer good.jwt' }));

  assertEquals(ctx.auth.uid, 'user-123');
  assertStrictEquals(ctx.supabase, client);
  assertEquals(builtWith, 'Bearer good.jwt', 'client must carry the caller JWT so RLS applies');
  assertEquals(calls, ['good.jwt']);
});
