// Shared request authentication for Edge Functions.
//
// The platform's JWT check only proves the caller holds *some* valid token
// (the public anon key passes too). Every function that spends OpenAI credit
// or writes data must resolve the actual signed-in user first.
//
// getClaims() verifies tokens signed with the project's asymmetric signing
// keys locally, against the JWKS it caches, so those requests no longer wait
// for an Auth server round trip (/auth/v1/user) before doing real work.
// Tokens signed with the legacy shared secret (HS256) cannot be verified
// locally; for those getClaims() asks the Auth server, as before.

import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.118.0";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

export function textResponse(message: string, status: number): Response {
  return new Response(message, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

// One client per worker, so the JWKS cache survives between requests.
let authClient: SupabaseClient | null = null;

function getAuthClient(): SupabaseClient | null {
  if (authClient) return authClient;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return null;
  authClient = createClient(supabaseUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  return authClient;
}

/**
 * The user id carried by verified JWT [claims], or null when the token does
 * not belong to a signed-in user (the anon key has role "anon" and no sub).
 */
export function userIdFromClaims(
  claims: { role?: unknown; sub?: unknown } | null | undefined,
): string | null {
  if (claims?.role !== "authenticated") return null;
  return isUuid(claims.sub) ? claims.sub : null;
}

/**
 * Returns the id of the signed-in user making [req], or an error Response
 * (401) when the request carries no user session.
 */
export async function requireUser(
  req: Request,
): Promise<{ userId: string } | Response> {
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
  if (!token) return textResponse("Missing authorization", 401);

  const client = getAuthClient();
  if (!client) return textResponse("Server configuration error", 500);

  let userId: string | null;
  try {
    const { data, error } = await client.auth.getClaims(token);
    userId = error ? null : userIdFromClaims(data?.claims);
  } catch (error) {
    console.error("Session check failed:", error);
    return textResponse("Session check failed", 500);
  }
  if (!userId) return textResponse("Invalid or expired session", 401);
  return { userId };
}
