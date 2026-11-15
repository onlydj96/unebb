// Run: deno test --allow-env supabase/functions
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { chatJson, strictJsonFormat, strictSchemaProblems } from "./openai.ts";

type FetchStub = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

async function withFetch<T>(stub: FetchStub, run: () => Promise<T>): Promise<T> {
  const original = globalThis.fetch;
  globalThis.fetch = stub as typeof fetch;
  // The error paths log on purpose; keep the test output readable.
  const originalError = console.error;
  console.error = () => {};
  try {
    return await run();
  } finally {
    globalThis.fetch = original;
    console.error = originalError;
  }
}

const reply = (content: unknown, extra: Record<string, unknown> = {}) =>
  new Response(
    JSON.stringify({ choices: [{ message: { content, ...extra } }] }),
    { status: 200 },
  );

const call = (timeoutMs = 1000) =>
  chatJson({ apiKey: "sk-test", timeoutMs, body: { model: "m" } });

test("chatJson returns the parsed object and sends the key and body", async () => {
  let sent: RequestInit | undefined;
  const result = await withFetch((_url, init) => {
    sent = init;
    return Promise.resolve(reply('{"sentence":"안녕"}'));
  }, () => call());

  assert.ok(result.ok);
  assert.deepEqual(result.json, { sentence: "안녕" });
  assert.equal((sent?.headers as Record<string, string>).Authorization, "Bearer sk-test");
  assert.equal(sent?.body, '{"model":"m"}');
  assert.ok(sent?.signal instanceof AbortSignal);
});

test("chatJson maps an OpenAI error status to 502", async () => {
  const result = await withFetch(
    () => Promise.resolve(new Response("rate limited", { status: 429 })),
    () => call(),
  );
  assert.ok(!result.ok);
  assert.equal(result.response.status, 502);
});

test("chatJson maps the timeout to 504", async () => {
  const result = await withFetch(
    (_url, init) =>
      new Promise((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => reject(init.signal!.reason));
      }),
    () => call(20),
  );
  assert.ok(!result.ok);
  assert.equal(result.response.status, 504);
  assert.equal(await result.response.text(), "AI service timeout");
});

test("chatJson maps a network failure to 502", async () => {
  const result = await withFetch(
    () => Promise.reject(new TypeError("connection reset")),
    () => call(),
  );
  assert.ok(!result.ok);
  assert.equal(result.response.status, 502);
});

test("chatJson rejects refusals, empty, unparsable and non-object replies", async () => {
  const cases: [Response, string][] = [
    [reply(null, { refusal: "I can't help with that." }), "AI service error"],
    [reply(""), "Empty AI response"],
    [reply("{not json"), "Invalid AI response format"],
    [reply("[1,2]"), "Invalid AI response format"],
  ];
  for (const [response, message] of cases) {
    const result = await withFetch(() => Promise.resolve(response), () => call());
    assert.ok(!result.ok);
    assert.equal(result.response.status, 502);
    assert.equal(await result.response.text(), message);
  }
});

test("strictJsonFormat wraps the schema for Structured Outputs", () => {
  const schema = { type: "object", properties: {}, required: [], additionalProperties: false };
  assert.deepEqual(strictJsonFormat("x", schema), {
    type: "json_schema",
    json_schema: { name: "x", strict: true, schema },
  });
});

test("strictSchemaProblems finds what strict mode rejects", () => {
  assert.deepEqual(
    strictSchemaProblems({
      type: "object",
      properties: {
        a: { type: "string" },
        b: { type: "array", items: { type: "object", properties: { c: { type: "number" } } } },
      },
      required: ["a", "z"],
    }),
    [
      "$: additionalProperties must be false",
      "$.b: not required",
      "$.b[]: additionalProperties must be false",
      "$.b[].c: not required",
      "$: requires unknown property z",
    ],
  );
  assert.deepEqual(
    strictSchemaProblems({
      type: "object",
      properties: { a: { type: ["string", "null"] } },
      required: ["a"],
      additionalProperties: false,
    }),
    [],
  );
});
