// Run: deno test --allow-env supabase/functions
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { strictSchemaProblems } from "../_shared/openai.ts";
import {
  buildEvaluationRequest,
  EVALUATION_SCHEMA,
  type EvaluationInput,
  MEANING_SYSTEM_PROMPT,
  TRANSLATION_SYSTEM_PROMPT,
} from "./prompts.ts";

type Message = { role: string; content: string };

const english: EvaluationInput = {
  word: "meticulous",
  language: "English",
  definition: "showing great attention to detail",
  user_answer: "She was meticulous about her notes.",
  question_context: "그녀는 노트 정리에 아주 꼼꼼했다.",
  known_patterns: ["가정법 시제 혼동", "복수형 -s 누락"],
};

const japanese: EvaluationInput = {
  word: "約束",
  language: "Japanese",
  definition: "promise; appointment",
  user_answer: "友達とやくそくした。",
  question_context: "친구와 약속했다.",
  known_patterns: ["조사 혼동 (は/が)"],
};

const messages = (request: Record<string, unknown>) =>
  request.messages as Message[];

test("the evaluation schema is valid for Structured Outputs strict mode", () => {
  assert.deepEqual(strictSchemaProblems(EVALUATION_SCHEMA), []);
  const request = buildEvaluationRequest("meaning", english, "Korean");
  assert.deepEqual(request.response_format, {
    type: "json_schema",
    json_schema: { name: "evaluation", strict: true, schema: EVALUATION_SCHEMA },
  });
});

test("system prompts are identical for every request (cacheable prefix)", () => {
  for (const evalType of ["meaning", "translation"] as const) {
    const a = messages(buildEvaluationRequest(evalType, english, "Korean"));
    const b = messages(buildEvaluationRequest(evalType, japanese, "English"));
    assert.equal(a[0].role, "system");
    assert.equal(a[0].content, b[0].content);
    assert.equal(
      a[0].content,
      evalType === "meaning" ? MEANING_SYSTEM_PROMPT : TRANSLATION_SYSTEM_PROMPT,
    );
    for (const value of [
      english.word,
      english.definition,
      english.user_answer,
      english.question_context!,
      ...english.known_patterns!,
      japanese.word,
      japanese.user_answer,
    ]) {
      assert.ok(!a[0].content.includes(value), `${evalType} system prompt contains "${value}"`);
    }
  }
});

test("request values go in the user message", () => {
  const user = messages(buildEvaluationRequest("translation", english, "Korean"))[1];
  assert.equal(user.role, "user");
  for (const value of [
    "Target language: English",
    "Learner's native language: Korean",
    `"${english.question_context}"`,
    `"${english.word}"`,
    `"${english.definition}"`,
    `"${english.user_answer}"`,
    "  - 가정법 시제 혼동",
    "  - 복수형 -s 누락",
    "VERIFIED BY SYSTEM",
  ]) {
    assert.ok(user.content.includes(value), `missing ${value}`);
  }
  // English has no kanji reading rule.
  assert.ok(!user.content.includes("KANJI READING RULE"));
});

test("Japanese requests carry the reading rule and the kana-spelling note", () => {
  const user = messages(buildEvaluationRequest("translation", japanese, "Korean"))[1];
  assert.ok(user.content.includes("KANJI READING RULE"));
  assert.ok(user.content.includes("spelled it in kana instead of kanji"));
});

test("the meaning check ignores known patterns and the word-usage check", () => {
  const user = messages(buildEvaluationRequest("meaning", english, "Korean"))[1];
  assert.ok(!user.content.includes("가정법 시제 혼동"));
  assert.ok(!user.content.includes("SYSTEM"));
  assert.ok(user.content.includes(`Learner's answer: "${english.user_answer}"`));
});

test("the meaning check uses low reasoning effort, translation the default", () => {
  assert.equal(buildEvaluationRequest("meaning", english, "Korean").reasoning_effort, "low");
  assert.equal(buildEvaluationRequest("translation", english, "Korean").reasoning_effort, "medium");
});
