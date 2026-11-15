// Run: deno test --allow-env supabase/functions
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { requireUser, userIdFromClaims } from "./auth.ts";

const USER_ID = "8f14e45f-ceea-467e-a8d6-8b0a2f0c9d11";

const request = (authorization?: string) =>
  new Request("http://localhost/fn", {
    method: "POST",
    headers: authorization ? { Authorization: authorization } : {},
  });

test("userIdFromClaims accepts only signed-in users", () => {
  assert.equal(userIdFromClaims({ role: "authenticated", sub: USER_ID }), USER_ID);
  // The anon key: valid signature, but no user behind it.
  assert.equal(userIdFromClaims({ role: "anon" }), null);
  assert.equal(userIdFromClaims({ role: "anon", sub: USER_ID }), null);
  assert.equal(userIdFromClaims({ role: "service_role" }), null);
  assert.equal(userIdFromClaims({ role: "authenticated", sub: "not-a-uuid" }), null);
  assert.equal(userIdFromClaims({ role: "authenticated" }), null);
  assert.equal(userIdFromClaims(null), null);
});

test("requireUser rejects a request without a bearer token", async () => {
  for (const header of [undefined, "Basic abc", "Bearer ", "Bearer    "]) {
    const result = await requireUser(request(header));
    assert.ok(result instanceof Response);
    assert.equal(result.status, 401);
  }
});

// Runs before the client is created: the client is cached once env is set.
test("requireUser reports missing server configuration", async () => {
  Deno.env.delete("SUPABASE_URL");
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  const result = await requireUser(request("Bearer abc.def.ghi"));
  assert.ok(result instanceof Response);
  assert.equal(result.status, 500);
});

test("requireUser rejects a malformed token without a network call", async () => {
  Deno.env.set("SUPABASE_URL", "http://127.0.0.1:9");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
  const original = globalThis.fetch;
  globalThis.fetch = () => Promise.reject(new Error("unexpected network call"));
  try {
    const result = await requireUser(request("Bearer not-a-jwt"));
    assert.ok(result instanceof Response);
    assert.equal(result.status, 401);
  } finally {
    globalThis.fetch = original;
  }
});
