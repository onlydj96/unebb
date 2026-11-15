// Prompt and output schema for generate-explanation.

import { kanjiReadingRule } from "../_shared/japanese.ts";
import { strictJsonFormat } from "../_shared/openai.ts";

const text = { type: "string" };
const textList = { type: "array", items: { type: "string" } };

export const EXPLANATION_SCHEMA = {
  type: "object",
  properties: {
    pronunciation: text,
    definition: text,
    explanation: text,
    usage: text,
    examples: textList,
    synonyms: textList,
    collocations: textList,
    common_mistakes: textList,
  },
  required: [
    "pronunciation",
    "definition",
    "explanation",
    "usage",
    "examples",
    "synonyms",
    "collocations",
    "common_mistakes",
  ],
  additionalProperties: false,
};

export const SYSTEM_PROMPT = `You are a vocabulary learning assistant.
Given a word and its language, generate educational content to help learners remember and use it.
Return ONLY valid JSON — no markdown, no code fences, no extra text.`;

// Every Japanese word written in kanji — in any field, including words quoted
// inside the native-language explanation — carries its hiragana reading.
const japaneseReadingRule = kanjiReadingRule([
  "ANY field (definition, explanation, usage, examples, synonyms, collocations, common_mistakes)",
]) +
  `The "pronunciation" field is the exception: it is the hiragana reading of the whole word only.
`;

export function buildUserPrompt(word: string, language: string, nativeLanguage: string): string {
  const isJapanese = language === "Japanese";
  const pronunciationGuide = isJapanese
    ? "Hiragana reading (e.g. あいて for 相手)"
    : "IPA phonetic transcription (e.g. /əˈbændən/ for English)";

  return `Generate learning content for the ${language} word: "${word}"
The learner's native language is ${nativeLanguage}. Write explanations in ${nativeLanguage}.
${isJapanese ? japaneseReadingRule : ""}
Return a JSON object with exactly these fields:
{
  "pronunciation": "${pronunciationGuide}",
  "definition": "Clear, concise definition in ${nativeLanguage} (1-2 sentences)",
  "explanation": "Explanation of nuance, origin, or context in ${nativeLanguage} (2-3 sentences)",
  "usage": "When and how to use this word in ${nativeLanguage} (1-2 sentences)",
  "examples": ["3 natural example sentences using the word in ${language}"],
  "synonyms": ["3-5 synonyms or near-synonyms in ${language}"],
  "collocations": ["4-6 common word combinations in ${language} (e.g. 'make a decision')"],
  "common_mistakes": ["2-3 common mistakes ${nativeLanguage} speakers make, with corrections in ${nativeLanguage}"]
}`;
}

/** The Chat Completions body for one explanation. */
export function buildExplanationRequest(
  word: string,
  language: string,
  nativeLanguage: string,
): Record<string, unknown> {
  return {
    model: "gpt-4o-mini",
    temperature: 0.3,
    response_format: strictJsonFormat("explanation", EXPLANATION_SCHEMA),
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: buildUserPrompt(word, language, nativeLanguage) },
    ],
  };
}
