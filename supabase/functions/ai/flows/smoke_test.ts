import { type ModelArgument, z } from 'genkit';
// Not `genkit/middleware`: that path has types but isn't in the package's
// `exports`, so it fails to load at runtime.
import { retry } from 'genkit/model/middleware';
import { type Ai, callModel } from '../genkit.ts';
import { requireUserContext } from '../auth.ts';

export const SmokeTestOutput = z.object({
  uid: z.string(),
  exerciseCount: z.number().int(),
  message: z.string(),
});

/**
 * `smokeTest`: proves the whole path works end to end, with no product
 * behavior of its own.
 *
 * - The exercise count comes through the caller's RLS-scoped client, so a
 *   correct number proves the JWT reached Postgres as that user.
 * - The message comes from Claude, so a non-empty reply proves the API key and
 *   the model call work.
 *
 * Input is an empty object. Don't rely on Zod `.default()` for flow input:
 * Genkit's HTTP handler doesn't apply schema defaults.
 */
export function defineSmokeTest(ai: Ai, model: ModelArgument) {
  return ai.defineFlow(
    {
      name: 'smokeTest',
      inputSchema: z.object({}).passthrough(),
      outputSchema: SmokeTestOutput,
    },
    async (_input, { context }) => {
      const { auth, supabase } = requireUserContext(context);

      const { count, error } = await supabase
        .from('exercises')
        .select('id', { count: 'exact', head: true });
      if (error) throw new Error(`exercise count failed: ${error.message}`);
      const exerciseCount = count ?? 0;

      const { text } = await callModel(() =>
        ai.generate({
          model,
          prompt: `In one short, upbeat sentence (under 20 words), tell a lifter their ` +
            `NoMoreX AI connection works and that they can see ${exerciseCount} exercises.`,
          config: { maxOutputTokens: 80 },
          // Capped so retries can't outlast the edge function's wall-clock limit.
          use: [retry({ maxRetries: 2, maxDelayMs: 4000 })],
        })
      );

      return { uid: auth.uid, exerciseCount, message: text.trim() };
    },
  );
}
