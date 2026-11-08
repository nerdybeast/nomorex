import { withActionOptions } from '@genkit-ai/fetch';
import { type Ai, modelFor } from '../genkit.ts';
import { supabaseAuth } from '../auth.ts';
import { defineSmokeTest } from './smoke_test.ts';

/**
 * Every flow this function serves, each wrapped with the Supabase auth context
 * provider. To add a flow: write `flows/<name>.ts` exporting a
 * `define<Name>(ai, model)` function, then add it here. It is served at
 * `POST /functions/v1/ai/<flowName>`.
 *
 * Nothing is served without `supabaseAuth`. A flow that skips it would run
 * with no user and no RLS-scoped client.
 */
export function defineFlows(ai: Ai) {
  const auth = supabaseAuth();
  return [
    withActionOptions(defineSmokeTest(ai, modelFor('fast')), { contextProvider: auth }),
  ];
}
