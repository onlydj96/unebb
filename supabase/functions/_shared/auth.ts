// Shared request authentication for Edge Functions.
//
// The platform's JWT check only proves the caller holds *some* valid token
// (the public anon key passes too). Every function that spends OpenAI credit
// or writes data must resolve the actual signed-in user first.

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

/**
 * Returns the id of the signed-in user making [req], or an error Response
 * (401) when the request carries no user session.
 */
export async function requireUser(
  req: Request,
): Promise<{ userId: string } | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return textResponse("Missing authorization", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return textResponse("Server configuration error", 500);
  }

  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: serviceKey, Authorization: authHeader },
  });
  if (!res.ok) return textResponse("Invalid or expired session", 401);

  const user = await res.json().catch(() => null);
  if (!isUuid(user?.id)) return textResponse("Invalid or expired session", 401);
  return { userId: user.id };
}
