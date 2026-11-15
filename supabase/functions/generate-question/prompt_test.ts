// Run: deno test --allow-env supabase/functions
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { strictSchemaProblems } from "../_shared/openai.ts";
import { buildQuestionRequest, QUESTION_SCHEMA } from "./prompt.ts";

test("the question schema is valid for Structured Outputs strict mode", () => {
  assert.deepEqual(strictSchemaProblems(QUESTION_SCHEMA), []);
});

test("the question request keeps gpt-4o-mini and requests the strict schema", () => {
  const request = buildQuestionRequest({
    word: "meticulous",
    language: "English",
    definition: "showing great attention to detail",
    usage: "Used for careful work",
    examples: ["She is meticulous.", "A meticulous plan.", "Third example."],
    native_language: "Korean",
  });
  assert.equal(request.model, "gpt-4o-mini");
  assert.equal(request.temperature, 0.7);
  assert.deepEqual(request.response_format, {
    type: "json_schema",
    json_schema: { name: "question", strict: true, schema: QUESTION_SCHEMA },
  });
  const [system, user] = request.messages as { role: string; content: string }[];
  assert.ok(!system.content.includes("meticulous"));
  assert.ok(user.content.includes('"She is meticulous.; A meticulous plan."'));
  assert.ok(!user.content.includes("Third example."));
});
