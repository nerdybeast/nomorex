import type { SupabaseClient } from '@supabase/supabase-js';

const BUCKET = 'ai-imports';
/** Storage list and remove both work in pages. */
const PAGE = 100;
/** A shorter secret is treated as unset, so a placeholder can't open the function. */
const MIN_SECRET_LENGTH = 32;

/** One upload folder, `{userId}/{importId}`, whose files should be deleted. */
export interface Folder {
  user_id: string;
  import_id: string;
}

/** What the cleanup needs from Supabase, injectable so tests need no network. */
export interface CleanupDeps {
  /** Runs `ai_import_sweep()` and returns the folders to empty. */
  sweep(): Promise<Folder[]>;
  /** Up to [limit] file names directly inside [prefix]. */
  list(prefix: string, limit: number): Promise<string[]>;
  remove(paths: string[]): Promise<void>;
}

export interface CleanupReport {
  folders: number;
  files: number;
  /** Folders that couldn't be emptied. The next run returns them again. */
  failed: number;
}

export function supabaseDeps(client: SupabaseClient): CleanupDeps {
  const storage = client.storage.from(BUCKET);
  return {
    async sweep() {
      const { data, error } = await client.rpc('ai_import_sweep');
      if (error) throw new Error(`sweep failed: ${error.message}`);
      return (data ?? []) as Folder[];
    },
    async list(prefix, limit) {
      const { data, error } = await storage.list(prefix, { limit });
      if (error) throw new Error(`listing ${prefix} failed: ${error.message}`);
      // A null id is a nested folder, which the upload policy never allows.
      return (data ?? []).filter((o) => o.id !== null).map((o) => o.name);
    },
    async remove(paths) {
      const { error } = await storage.remove(paths);
      if (error) throw new Error(`removing files failed: ${error.message}`);
    },
  };
}

/**
 * Runs the database sweep, then deletes each returned folder's files through
 * the Storage API. Deleting `storage.objects` rows in SQL would leave the
 * stored files behind. A folder that fails is logged and skipped; the sweep
 * returns it again next time, which is the retry.
 */
export async function runCleanup(deps: CleanupDeps): Promise<CleanupReport> {
  const folders = await deps.sweep();
  const report: CleanupReport = { folders: folders.length, files: 0, failed: 0 };
  for (const { user_id, import_id } of folders) {
    const prefix = `${user_id}/${import_id}`;
    try {
      // Listed again after each page is removed, until the folder is empty.
      for (;;) {
        const names = await deps.list(prefix, PAGE);
        if (names.length === 0) break;
        await deps.remove(names.map((n) => `${prefix}/${n}`));
        report.files += names.length;
        if (names.length < PAGE) break;
      }
    } catch (e) {
      report.failed += 1;
      console.error(`[ai-import-cleanup] ${prefix}:`, e instanceof Error ? e.message : e);
    }
  }
  return report;
}

async function sha256(text: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
}

/** Compares in constant time, so response timing reveals nothing about the secret. */
async function sameSecret(given: string, expected: string): Promise<boolean> {
  const [a, b] = await Promise.all([sha256(given), sha256(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

/**
 * The HTTP handler. Only a POST carrying `Authorization: Bearer <secret>` runs
 * the cleanup. JWT verification is off for this function, so this check is
 * the only gate.
 */
export function createHandler(secret: string | undefined, deps: () => CleanupDeps) {
  return async (req: Request): Promise<Response> => {
    if (!secret || secret.length < MIN_SECRET_LENGTH) {
      console.error('[ai-import-cleanup] AI_IMPORT_CLEANUP_SECRET is not set');
      return json(503, { error: 'not configured' });
    }
    const header = req.headers.get('authorization') ?? '';
    const given = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : '';
    if (!(await sameSecret(given, secret))) return json(401, { error: 'unauthorized' });
    if (req.method !== 'POST') return json(405, { error: 'method not allowed' });

    try {
      const report = await runCleanup(deps());
      console.log('[ai-import-cleanup]', JSON.stringify(report));
      // A partial failure fails the scheduled run, so it shows up in Actions.
      return json(report.failed > 0 ? 500 : 200, report);
    } catch (e) {
      console.error('[ai-import-cleanup] failed:', e instanceof Error ? e.message : e);
      return json(500, { error: 'cleanup failed' });
    }
  };
}
