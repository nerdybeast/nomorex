// Supabase Edge Function `ai-import-cleanup`: the daily AI import cleanup
// (#87). Called only by .github/workflows/ai-import-cleanup.yml, with the
// AI_IMPORT_CLEANUP_SECRET function secret as its bearer token.
//
// It holds the service-role key because a scheduled job has no user session
// and must act on every user's imports. That's why it's a separate function
// with no AI code: the `ai` function, which handles untrusted files, never
// gets a privileged key.
import { createClient } from '@supabase/supabase-js';
import { createHandler, supabaseDeps } from './cleanup.ts';

Deno.serve(
  createHandler(Deno.env.get('AI_IMPORT_CLEANUP_SECRET'), () =>
    supabaseDeps(
      createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
        auth: { persistSession: false, autoRefreshToken: false },
      }),
    )),
);
