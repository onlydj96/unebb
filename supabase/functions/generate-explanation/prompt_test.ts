// Run: deno test --allow-env supabase/functions
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { strictSchemaProblems } from "../_shared/openai.ts";
import { buildExplanationRequest, EXPLANATION_SCHEMA } from "./prompt.ts";

test("the explanation schema is valid for Structured Outputs strict mode", () => {
  assert.deepEqual(strictSchemaProblems(EXPLANATION_SCHEMA), []);
});

test("the explanation request keeps gpt-4o-mini and requests the strict schema", () => {
  const request = buildExplanationRequest("相手", "Japanese", "Korean");
  assert.equal(request.model, "gpt-4o-mini");
  assert.equal(request.temperature, 0.3);
  assert.deepEqual(request.response_format, {
    type: "json_schema",
    json_schema: { name: "explanation", strict: true, schema: EXPLANATION_SCHEMA },
  });
  const [system, user] = request.messages as { role: string; content: string }[];
  assert.equal(system.role, "system");
  assert.ok(!system.content.includes("相手"));
  assert.ok(user.content.includes('"相手"'));
  assert.ok(user.content.includes("KANJI READING RULE"));
});
