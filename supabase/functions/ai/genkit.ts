import { genkit, UserFacingError } from 'genkit';
import { anthropic } from '@genkit-ai/anthropic';

/**
 * Model IDs, chosen in one place. Flows pick a tier, not a raw ID, so moving a
 * tier to a newer model is a one-line change here.
 *
 * The Anthropic plugin resolves IDs it doesn't know about by name, so a newer
 * model works here even if the pinned plugin version predates it.
 */
export const MODELS = {
  /** Cheap and fast: smoke tests, short classification/summaries. */
  fast: 'claude-haiku-5-5',
  /** Default for real features. */
  standard: 'claude-sonnet-5-5',
} as const;

export type ModelTier = keyof typeof MODELS;

/** Reference to a model tier through the Anthropic plugin. */
export function modelFor(tier: ModelTier) {
  return anthropic.model(MODELS[tier]);
}

/**
 * The production Genkit instance. The Anthropic plugin reads
 * `ANTHROPIC_API_KEY` from the environment (a Supabase secret in production,
 * `supabase/functions/.env` locally) and throws at startup if it's missing.
 */
export function createAi() {
  return genkit({ plugins: [anthropic()] });
}

export type Ai = ReturnType<typeof genkit>;

/**
 * Runs a model call and turns any failure into a generic `UNAVAILABLE` (503).
 *
 * Without this, provider errors reach the client verbatim. A bad or missing
 * Anthropic key comes back as `UNAUTHENTICATED`/401, which the app can't tell
 * apart from an expired user session, and the message leaks upstream details
 * (request IDs, provider error bodies). Keep 401 meaning "the user's session"
 * only: wrap every `ai.generate` in a flow with this. The full error is logged
 * server-side (visible in the function's logs).
 */
export async function callModel<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    console.error('[ai] model call failed:', e);
    throw new UserFacingError(
      'UNAVAILABLE',
      'The AI service is unavailable right now. Try again in a moment.',
    );
  }
}
