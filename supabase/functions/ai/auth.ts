import { type ActionContext, UserFacingError } from 'genkit';
import type { ContextProvider, RequestData } from 'genkit/context';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Context every flow in this function receives. Flows must read and write data
 * **only** through `supabase`: it carries the caller's JWT, so every query
 * runs under that user's RLS, exactly like a query from the app itself.
 *
 * Never create a service-role / secret-key client in this function. It would
 * bypass RLS and turn any prompt-injection bug into a cross-user data leak.
 */
export interface UserContext extends ActionContext {
  auth: { uid: string };
  supabase: SupabaseClient;
}

/** Builds the user-scoped client from the raw Authorization header (injectable for tests). */
export type ClientFactory = (authorization: string) => SupabaseClient;

function defaultClientFactory(authorization: string): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !anonKey) {
    throw new Error('SUPABASE_URL / SUPABASE_ANON_KEY are not set in the edge runtime');
  }
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

const BEARER = /^Bearer\s+(\S+)$/i;

/**
 * Narrows a flow's `context` to `UserContext`, failing with UNAUTHENTICATED if
 * the auth provider didn't run. That happens if a flow is added to
 * flows/mod.ts without `supabaseAuth`, or is run from the Genkit Dev UI, which
 * bypasses HTTP context providers. Call this first in every flow.
 */
export function requireUserContext(context: ActionContext | undefined): UserContext {
  const ctx = context as Partial<UserContext> | undefined;
  if (!ctx?.auth?.uid || !ctx.supabase) {
    throw new UserFacingError(
      'UNAUTHENTICATED',
      'No signed-in user. Flows must be called over HTTP with a session JWT.',
    );
  }
  return ctx as UserContext;
}

/**
 * Genkit context provider that authenticates the caller from their Supabase
 * session JWT and hands flows a client scoped to that user.
 *
 * The platform's `verify_jwt` check already rejects requests without a valid
 * JWT before they reach this code; this verifies again so the function never
 * depends on gateway config alone (e.g. `supabase functions serve
 * --no-verify-jwt` locally).
 */
export function supabaseAuth(
  createUserClient: ClientFactory = defaultClientFactory,
): ContextProvider<UserContext> {
  return async (request: RequestData): Promise<UserContext> => {
    // Genkit lowercases header names before calling the provider.
    const authorization = request.headers['authorization'];
    const token = authorization?.match(BEARER)?.[1];
    if (!authorization || !token) {
      throw new UserFacingError('UNAUTHENTICATED', 'Sign in to use AI features.');
    }

    const supabase = createUserClient(authorization);
    const { data, error } = await supabase.auth.getClaims(token);
    const uid = data?.claims?.sub;
    // `role` guards against the anon key being sent as a bearer token: it's a
    // valid JWT, but it isn't a signed-in user.
    if (error || !uid || data?.claims?.role !== 'authenticated') {
      throw new UserFacingError('UNAUTHENTICATED', 'Your session is invalid or expired. Sign in again.');
    }

    return { auth: { uid }, supabase };
  };
}
