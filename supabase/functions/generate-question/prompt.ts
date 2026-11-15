// Prompt and output schema for generate-question.

import { strictJsonFormat } from "../_shared/openai.ts";

export interface QuestionInput {
  word: string;
  language: string;
  definition: string;
  usage: string;
  examples: string[];
  native_language: string; // e.g. "Korean"
}

// Only the sentence comes from the model: question_type is fixed and
// word_hint is always the stored word, so generating them was wasted output.
export const QUESTION_SCHEMA = {
  type: "object",
  properties: { sentence: { type: "string" } },
  required: ["sentence"],
  additionalProperties: false,
};

export const SYSTEM_PROMPT = `You are a language learning exercise generator.
Create natural, contextual sentences in the learner's native language
that illustrate the meaning of a target vocabulary word.
Reply with the JSON object defined by the response schema.`;

export function buildUserPrompt(body: QuestionInput): string {
  const exampleStr = body.examples?.slice(0, 2).join("; ") ?? "";
  return `Target ${body.language} word: "${body.word}"
Definition: "${body.definition}"
Usage: "${body.usage}"
${exampleStr ? `Example sentences: "${exampleStr}"` : ""}

Create a sentence in ${body.native_language} that naturally conveys the concept of "${body.word}".
The sentence should make sense in everyday life and hint at the word's meaning without directly stating it.
This is the question the learner answers: write it only in ${body.native_language} — no ${body.language} words and no readings or pronunciations.

Return a JSON object:
{
  "sentence": "<A natural ${body.native_language} sentence (1-2 sentences) whose meaning, when translated to ${body.language}, naturally requires using the word '${body.word}' or a close equivalent>"
}`;
}

/** The Chat Completions body for one translation question. */
export function buildQuestionRequest(
  body: QuestionInput,
): Record<string, unknown> {
  return {
    model: "gpt-4o-mini",
    temperature: 0.7,
    response_format: strictJsonFormat("question", QUESTION_SCHEMA),
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: buildUserPrompt(body) },
    ],
  };
}
