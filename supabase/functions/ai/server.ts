import { fetchHandlers } from '@genkit-ai/fetch';
import { createAi } from './genkit.ts';
import { defineFlows } from './flows/mod.ts';

// The Flutter web build calls this cross-origin, so it needs CORS. Mobile and
// desktop ignore these headers. Access is controlled by the user JWT, not by
// origin, so `*` is fine here.
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/**
 * Builds the request handler shared by the edge function (index.ts) and the
 * local trace-capturing dev server (dev.ts).
 *
 *   POST .../ai/<flowName>   body: {"data": <flow input>}
 *   -> 200 {"result": <flow output>}   | 4xx/5xx {"status", "message"}
 */
export function createHandler(): (req: Request) => Promise<Response> {
  const handle = fetchHandlers(defineFlows(createAi()), '/ai');

  return async (req) => {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    const res = await handle(req);
    const headers = new Headers(res.headers);
    for (const [k, v] of Object.entries(CORS_HEADERS)) headers.set(k, v);
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
  };
}
