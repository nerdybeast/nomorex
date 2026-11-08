// Supabase Edge Function `ai`: serves Genkit flows over HTTP at
// POST /functions/v1/ai/<flowName>. Flows: flows/mod.ts. Auth: auth.ts.
import { createHandler } from './server.ts';

Deno.serve(createHandler());
