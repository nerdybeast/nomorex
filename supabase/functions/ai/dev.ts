// Local dev server for capturing Genkit traces. Not deployed.
//
// It serves the same handler as the edge function on a plain port, so
// `genkit start` can wrap it and record every flow, model call and error:
//
//   genkit start -- deno run -A --env-file=supabase/functions/.env \
//     supabase/functions/ai/dev.ts
//
// then call it with a real session (curl, or point the app at it):
//
//   curl -X POST http://localhost:8787/ai/smokeTest \
//     -H "Authorization: Bearer <user JWT>" -H 'Content-Type: application/json' -d '{"data":{}}'
//
// Flows need the auth context provider, which only runs on the HTTP path.
// Running a flow from the Dev UI's "Run" button gets no user and fails with
// UNAUTHENTICATED. Drive flows over HTTP and inspect them in the Traces tab.
//
// `.env` needs SUPABASE_URL / SUPABASE_ANON_KEY for the local stack (the edge
// runtime injects these when deployed, plain `deno run` doesn't), plus
// ANTHROPIC_API_KEY.
import { createHandler } from './server.ts';

const port = Number(Deno.env.get('AI_DEV_PORT') ?? 8787);
Deno.serve({ port }, createHandler());
