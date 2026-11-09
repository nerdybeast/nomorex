import { type ModelArgument, UserFacingError, z } from 'genkit';
import { retry } from 'genkit/model/middleware';
import type { SupabaseClient } from '@supabase/supabase-js';
import { type Ai, callModel } from '../genkit.ts';
import { requireUserContext } from '../auth.ts';
import { detectFileType, isEncryptedPdf, toBase64 } from '../ai_import/file_check.ts';
import { buildUserPrompt, type ImportType, SYSTEM_PROMPT } from '../ai_import/prompt.ts';
import { type CatalogExercise, normalizeResult, parseModelJson } from '../ai_import/normalize.ts';

const BUCKET = 'ai-imports';
/** Leaves room to record a clean failure before the 150s wall clock kills the worker. */
const DEADLINE_MS = 120_000;
/** Above about 21,000 the Anthropic SDK refuses non-streaming calls. */
const MAX_OUTPUT_TOKENS = 20_000;
/** Keeps the base64-encoded request, and the worker's 256 MB, within limits. */
const MAX_TOTAL_BYTES = 24_000_000;

const START_REFUSALS: Record<string, UserFacingError['status']> = {
  imports_disabled: 'FAILED_PRECONDITION',
  consent_required: 'FAILED_PRECONDITION',
  active_import: 'FAILED_PRECONDITION',
  import_closed: 'FAILED_PRECONDITION',
  daily_limit: 'RESOURCE_EXHAUSTED',
  monthly_limit: 'RESOURCE_EXHAUSTED',
  failure_limit: 'RESOURCE_EXHAUSTED',
  invalid_input: 'INVALID_ARGUMENT',
};

type FailureCode =
  | 'no_workout_found'
  | 'invalid_file'
  | 'unreadable_file'
  | 'timeout'
  | 'model_error'
  | 'invalid_output'
  | 'internal_error';

/** How the job outlives the request. Injectable so tests needn't wait or use EdgeRuntime. */
export interface JobRuntime {
  waitUntil(work: Promise<unknown>): void;
  /** Calls back shortly before the platform kills the worker. Returns an unsubscribe. */
  onWallClock(callback: () => void): () => void;
  deadlineMs: number;
}

function edgeRuntime(): JobRuntime {
  const edge = (globalThis as { EdgeRuntime?: { waitUntil(p: Promise<unknown>): void } }).EdgeRuntime;
  return {
    // Under dev.ts there is no EdgeRuntime, and the process stays alive anyway.
    waitUntil: (work) => edge?.waitUntil(work),
    onWallClock(callback) {
      const listener = (event: Event) => {
        if ((event as CustomEvent).detail?.reason === 'wall_clock') callback();
      };
      addEventListener('beforeunload', listener);
      return () => removeEventListener('beforeunload', listener);
    },
    deadlineMs: DEADLINE_MS,
  };
}

interface Limits {
  max_images: number;
  max_image_bytes: number;
  max_pdf_bytes: number;
}

class JobFailure extends Error {
  constructor(readonly code: FailureCode, detail: string) {
    super(detail);
  }
}

class DeadlineExceeded extends Error {}

type MediaPart = { media: { url: string; contentType: string } };

const naturalOrder = new Intl.Collator('en', { numeric: true });

/**
 * Reads and verifies every file. Nothing here parses or renders a file beyond
 * its leading bytes, and it all happens before any model call.
 */
async function loadVerifiedFiles(
  supabase: SupabaseClient,
  folder: string,
  limits: Limits,
): Promise<MediaPart[]> {
  const storage = supabase.storage.from(BUCKET);
  const { data: listed, error } = await storage.list(folder, { limit: 100 });
  if (error) throw new Error(`listing files failed: ${error.message}`);

  // Sorted so "page10" follows "page2": the order is the page order.
  const objects = (listed ?? [])
    .filter((o) => !o.name.startsWith('.') && o.id !== null)
    .sort((a, b) => naturalOrder.compare(a.name, b.name));
  if (objects.length === 0) throw new JobFailure('unreadable_file', 'no files in the import');
  if (objects.length > limits.max_images) throw new JobFailure('invalid_file', 'too many files');

  const remove = async (name: string) => {
    const { error: e } = await storage.remove([`${folder}/${name}`]);
    if (e) console.error('[ai_import] removing a rejected file failed:', e.message);
  };
  const reject = async (name: string, detail: string): Promise<never> => {
    await remove(name);
    throw new JobFailure('invalid_file', detail);
  };

  // Declared sizes come from Storage, so they spare a download but aren't relied on.
  const largestAllowed = Math.max(limits.max_image_bytes, limits.max_pdf_bytes);
  let declaredTotal = 0;
  for (const o of objects) {
    const size = Number(o.metadata?.size ?? 0);
    if (size > largestAllowed) await reject(o.name, 'file over the size limit');
    declaredTotal += size;
  }
  if (declaredTotal > MAX_TOTAL_BYTES) throw new JobFailure('invalid_file', 'files too large in total');

  const media: MediaPart[] = [];
  let pdfs = 0;
  let total = 0;
  for (const o of objects) {
    const { data: blob, error: e } = await storage.download(`${folder}/${o.name}`);
    if (e || !blob) throw new Error(`download failed: ${e?.message}`);
    const bytes = new Uint8Array(await blob.arrayBuffer());

    const type = detectFileType(bytes);
    if (type === null) await reject(o.name, 'contents are not an accepted file type');
    const limit = type === 'application/pdf' ? limits.max_pdf_bytes : limits.max_image_bytes;
    if (bytes.byteLength > limit) await reject(o.name, 'file over the size limit');
    total += bytes.byteLength;
    if (total > MAX_TOTAL_BYTES) throw new JobFailure('invalid_file', 'files too large in total');

    if (type === 'application/pdf') {
      pdfs += 1;
      if (isEncryptedPdf(bytes)) throw new JobFailure('unreadable_file', 'password-protected PDF');
    }
    media.push({ media: { url: `data:${type};base64,${toBase64(bytes)}`, contentType: type! } });
  }

  if (pdfs > 0 && objects.length > 1) throw new JobFailure('invalid_file', 'a PDF must be the only file');
  return media;
}

async function loadCatalog(supabase: SupabaseClient, uid: string): Promise<CatalogExercise[]> {
  // The same filter as the app. RLS alone also shows exercises from other
  // users' public workouts, which aren't part of this user's catalog.
  const { data, error } = await supabase
    .from('exercises')
    .select('id, name')
    .or(`is_predefined.eq.true,user_id.eq.${uid}`)
    .order('name');
  if (error) throw new Error(`reading the exercise catalog failed: ${error.message}`);
  return data ?? [];
}

interface JobInput {
  jobId: string;
  importId: string;
  requestedType?: ImportType;
  uid: string;
  supabase: SupabaseClient;
  ai: Ai;
  model: ModelArgument;
  runtime: JobRuntime;
}

async function runJob({ jobId, importId, requestedType, uid, supabase, ai, model, runtime }: JobInput) {
  let finished = false;
  const finish = async (params: Record<string, unknown>) => {
    if (finished) return;
    finished = true;
    const { error } = await supabase.rpc('ai_import_finish', { p_job_id: jobId, ...params });
    if (error) console.error('[ai_import] recording the outcome failed:', error.message);
  };
  const fail = (code: FailureCode) => finish({ p_failure_code: code });

  const stopListening = runtime.onWallClock(() => runtime.waitUntil(fail('timeout')));
  const controller = new AbortController();
  let onDeadline = () => {};
  const deadline = new Promise<never>((_, reject) => {
    onDeadline = () => reject(new DeadlineExceeded());
  });
  deadline.catch(() => {}); // Handled by the race below, or irrelevant if the job already ended.
  const timer = setTimeout(() => {
    controller.abort();
    onDeadline();
  }, runtime.deadlineMs);
  const beforeDeadline = <T>(work: Promise<T>) => Promise.race([work, deadline]);

  try {
    const { data: limits, error } = await beforeDeadline(
      Promise.resolve(supabase.from('ai_import_limits').select('*').single()),
    );
    if (error || !limits) throw new Error(`reading limits failed: ${error?.message}`);

    const media = await beforeDeadline(loadVerifiedFiles(supabase, `${uid}/${importId}`, limits as Limits));
    const catalog = await beforeDeadline(loadCatalog(supabase, uid));

    const response = await beforeDeadline(callModel(() =>
      ai.generate({
        model,
        system: SYSTEM_PROMPT,
        prompt: [...media, { text: buildUserPrompt(catalog.map((e) => e.name), requestedType) }],
        config: { maxOutputTokens: MAX_OUTPUT_TOKENS },
        abortSignal: controller.signal,
        // Capped so retries can't outlast the deadline.
        use: [retry({ maxRetries: 2, maxDelayMs: 4000 })],
      })
    ));

    const usage = {
      p_input_tokens: response.usage?.inputTokens ?? null,
      p_output_tokens: response.usage?.outputTokens ?? null,
      p_model: (model as { name?: string }).name ?? null,
    };

    // Cut off by the output cap: too much content for one import.
    if (response.finishReason === 'length') {
      await finish({ p_failure_code: 'timeout', ...usage });
      return;
    }

    const outcome = normalizeResult(parseModelJson(response.text), catalog, requestedType);
    if (outcome.kind === 'ok') {
      await finish({ p_detected_type: outcome.detectedType, p_result: outcome.result, ...usage });
    } else {
      await finish({
        p_failure_code: outcome.kind === 'no_workout_found' ? 'no_workout_found' : 'invalid_output',
        ...usage,
      });
    }
  } catch (e) {
    if (e instanceof DeadlineExceeded) {
      await fail('timeout');
    } else if (e instanceof JobFailure) {
      console.warn(`[ai_import] job ${jobId} refused: ${e.message}`);
      await fail(e.code);
    } else if (e instanceof UserFacingError) {
      // callModel has already logged the provider's error.
      await fail('model_error');
    } else {
      console.error('[ai_import] job failed:', e);
      await fail('internal_error');
    }
  } finally {
    clearTimeout(timer);
    stopListening();
  }
}

/**
 * `startAiImport`: claims an import job for files already uploaded to
 * `{uid}/{importId}/`, returns its ID, and finishes the AI work in the
 * background. The app learns the outcome from the job row.
 *
 * The job keeps the caller's JWT, so all of its access stays under their RLS.
 * It has no tools, and writes only to its own job through `ai_import_finish`.
 */
export function defineStartAiImport(ai: Ai, model: ModelArgument, runtime: JobRuntime = edgeRuntime()) {
  return ai.defineFlow(
    {
      name: 'startAiImport',
      inputSchema: z.object({
        importId: z.string().uuid(),
        requestedType: z.enum(['workout', 'program']).optional(),
      }),
      outputSchema: z.object({ jobId: z.string() }),
    },
    async ({ importId, requestedType }, { context }) => {
      const { auth, supabase } = requireUserContext(context);

      const { data: jobId, error } = await supabase.rpc('ai_import_start', {
        p_import_id: importId,
        p_requested_type: requestedType ?? null,
      });
      if (error) {
        const reason = error.message.match(/^([a-z_]+):/)?.[1];
        const status = reason ? START_REFUSALS[reason] : undefined;
        if (reason && status) throw new UserFacingError(status, reason);
        console.error('[ai_import] start failed:', error.message);
        throw new UserFacingError('UNAVAILABLE', 'Imports are unavailable right now. Try again in a moment.');
      }

      runtime.waitUntil(
        runJob({ jobId, importId, requestedType, uid: auth.uid, supabase, ai, model, runtime }),
      );
      return { jobId };
    },
  );
}
