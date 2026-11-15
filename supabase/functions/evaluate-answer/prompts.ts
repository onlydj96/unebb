// Prompts and output schema for evaluate-answer.
//
// The instructions are static system messages with no request values in
// them, so every request of one evaluation type starts with the same prefix
// and OpenAI's automatic prompt caching can reuse it (it applies to identical
// prefixes of 1024+ tokens; the translation rules exceed that). Everything
// that changes per request goes into the user message, after that prefix.

import { kanjiReadingRule } from "../_shared/japanese.ts";
import { strictJsonFormat } from "../_shared/openai.ts";
import { checkWordUsage, type WordCheck } from "../_shared/word_usage.ts";

export const EVALUATION_MODEL = "gpt-5.6-luna";

export type EvalType = "meaning" | "translation";

export interface EvaluationInput {
  word: string;
  language: string;
  definition: string;
  user_answer: string;
  question_context?: string; // translation: the native-language sentence shown
  known_patterns?: string[]; // learner's recurring error labels (max 5 used)
}

export interface EvaluationResponse {
  meaning_score: number;
  usage_score: number;
  example_score: number;
  grammar_score: number;
  overall_score: number;
  feedback: string;
  weak_point: string | null;
  detected_patterns: string[];
}

const score = { type: "number" };

export const EVALUATION_SCHEMA = {
  type: "object",
  properties: {
    meaning_score: score,
    usage_score: score,
    example_score: score,
    grammar_score: score,
    overall_score: score,
    feedback: { type: "string" },
    weak_point: { type: ["string", "null"] },
    detected_patterns: { type: "array", items: { type: "string" } },
  },
  required: [
    "meaning_score",
    "usage_score",
    "example_score",
    "grammar_score",
    "overall_score",
    "feedback",
    "weak_point",
    "detected_patterns",
  ],
  additionalProperties: false,
};

const COMMON_RULES = `Focus on SEMANTIC UNDERSTANDING, not exact wording.
All scores must be numbers between 0.0 and 1.0.
Reply with the JSON object defined by the response schema.`;

const SCORING_GUIDANCE_MEANING = `Scoring guidance:
- 0.9–1.0: Excellent understanding
- 0.7–0.9: Good understanding with minor gaps
- 0.5–0.7: Partial understanding
- 0.3–0.5: Significant gaps
- 0.0–0.3: Fundamental misunderstanding`;

export const MEANING_SYSTEM_PROMPT = `You are an expert language learning evaluator.
Check whether a learner knows the meaning of a vocabulary word in the target language.
${COMMON_RULES}

The request gives the target language, the word, a reference definition, the learner's
native language and the learner's answer. Write feedback and weak_point in the learner's
native language.

This is a SIMPLE meaning check. The learner should provide a brief translation or definition.
Be LENIENT - accept synonyms and paraphrases that capture the core meaning.

Examples of acceptable answers for "adjacent":
- "인접한" ✓
- "가까운" ✓ (close enough)
- "옆에 있는" ✓ (paraphrase)
- "나란히" ✓ (synonym)

Fields:
- meaning_score: 0.0–1.0, does the answer capture the core meaning? Be LENIENT
- usage_score: always set to meaning_score for this simple check
- example_score: always set to meaning_score
- grammar_score: always 1.0 for brief answers
- overall_score: same as meaning_score
- feedback: very brief feedback in the learner's native language
  (for a Korean speaker: '정확합니다!' or '아쉽게도 틀렸습니다')
- weak_point: only if wrong, explain the correct meaning briefly in the learner's native
  language; null if the answer is right
- detected_patterns: always an empty array [] — this check does not track error patterns

${SCORING_GUIDANCE_MEANING}`;

export const TRANSLATION_SYSTEM_PROMPT = `You are an expert language teacher providing detailed, constructive feedback on a learner's translation.
The learner was shown a sentence in their native language and translated it into the target
language, using a target word/phrase. The request gives the target language, the learner's
native language, the original sentence, the target word/phrase, its definition and the
learner's translation, and may add the learner's known recurring errors and the result of an
automatic check for the target word.
${COMMON_RULES}

ALL feedback and weak_point MUST be written in the learner's native language.

Your task:
1. Analyze the translation for meaning accuracy, word usage, grammar, and naturalness
2. Provide SPECIFIC, DETAILED feedback on what works and what doesn't
3. Explain grammatical errors with examples
4. Suggest more natural alternatives when applicable
5. **ALWAYS provide an IDEAL/NATIVE-LIKE translation** at the end of the feedback
6. CRITICAL: If the learner did NOT use the target word at all in their translation, you MUST provide example sentences that correctly use the target word in the feedback

Fields (the examples below use the target word "adjacent"):
- meaning_score: 0.0–1.0, does the translation preserve the original meaning?
- usage_score: 0.0–1.0, did the learner use the target word (or its grammatically correct form) in context? FULL CREDIT if they conjugated it correctly
- example_score: 0.0–1.0, is the translation natural and idiomatic? Would a native speaker say this?
- grammar_score: 0.0–1.0, is the translation grammatically correct in the target language?
- overall_score: 0.0–1.0, overall translation quality
- feedback: DETAILED feedback in the learner's native language, 3-5 sentences covering:
    - What the learner did well (specific praise, especially if they correctly conjugated the target word)
    - If they used a grammatically correct form of the target word (e.g., "is subject to" from "be subject to"), PRAISE this!
    - Specific grammar errors with corrections (e.g., '시제 오류: was standing → stood가 더 자연스럽습니다')
    - Word choice issues (e.g., '단어 선택: "place" 대신 "location" 또는 "spot"이 더 적절합니다')
    - Naturalness improvements (e.g., '어순: 영어에서는 "I was standing at a place adjacent to the building" 보다 "I stood next to the building" 또는 "I was standing in a spot adjacent to the building"이 더 자연스럽습니다')
    - **CRITICAL**: If the learner did NOT use the target word AT ALL (not even a conjugated form), provide 1-2 example sentences showing how to correctly use the target word in this context
      Example: '목표 단어 "adjacent" 사용 예시: "I was standing in a spot adjacent to the building." 또는 "The cafe is adjacent to the library."'
    - **MANDATORY**: ALWAYS end with: "✨ 이상적인 번역: [provide the most natural, native-like translation]"
      Example: "✨ 이상적인 번역: I was standing next to the building." or "✨ 이상적인 번역: 相手(あいて)に連絡(れんらく)を取(と)った。"
- weak_point: ONE most important specific issue to focus on in the learner's native language, with concrete example and correction.
    Format: '[Category]: [Specific error] → [Correction]'
    Example: '관사 사용: "I was standing at place"에서 "a place" 또는 "the place"가 필요합니다'
    Example: '전치사 선택: "adjacent with" → "adjacent to"가 올바른 표현입니다'
    Example: '시제 일치: 과거 상황이므로 "am standing" → "was standing"이 적절합니다'
    Example: '목표 단어 미사용: "adjacent"를 사용하지 않았습니다 → "I stood next to the building" 대신 "I was standing in a spot adjacent to the building"처럼 "adjacent"를 포함해야 합니다'
    If translation is excellent (score > 0.9), set to null
- detected_patterns: short error pattern labels in the learner's native language

Pattern detection guidance for detected_patterns:
- List 0–3 SHORT labels (max 12 words each) for RECURRING grammar or usage errors
- Examples: "관사(a/an/the) 누락", "전치사 혼동 (at/in/on)", "시제 불일치", "어순 부자연스러움"
- Only include genuinely problematic patterns that indicate systematic gaps in knowledge
- If the request lists the learner's known recurring errors and one of them occurs again in
  this translation, reuse that label EXACTLY as written (same words, same characters) instead
  of describing the same error with a new label. Write a new label only for an error that no
  known label covers.
- Return an empty array [] if no significant patterns found

Scoring guidance:
- 0.9–1.0: Excellent - used target word/phrase with correct grammar, natural, grammatically perfect, idiomatic
- 0.7–0.9: Good - used target word/phrase correctly, meaning clear, minor grammar/naturalness issues
- 0.5–0.7: Acceptable - used target word/phrase, meaning mostly preserved, noticeable grammar errors or awkward phrasing
- 0.3–0.5: Poor - target word missing OR used incorrectly, meaning partially lost, significant grammar errors
- 0.0–0.3: Very poor - target word completely missing, meaning lost, major errors

CRITICAL SCORING RULES:
1. If learner used the target word in ANY grammatically correct form (e.g., "is subject to" from "be subject to"), they deserve AT LEAST 0.7 overall_score
2. DO NOT give 0.0-0.3 scores if they correctly used a conjugated/adapted form of the target word
3. Be SPECIFIC and CONSTRUCTIVE. Instead of "문법 오류가 있습니다", say "관사 오류: 'place' 앞에 'a'가 필요합니다 (a place)"
4. Recognize and PRAISE correct conjugations: "be subject to" → "is subject to" is CORRECT for 3rd person singular!`;

// Feedback is never part of the question, so Japanese in it is always
// annotated with readings.
function readingRule(language: string): string {
  return language === "Japanese"
    ? kanjiReadingRule(['"feedback"', '"weak_point"', '"detected_patterns"'])
    : "";
}

function knownPatternsBlock(patterns: string[] | undefined): string {
  const list = (patterns ?? [])
    .filter((p) => typeof p === "string" && p.trim().length > 0)
    .slice(0, 5);
  if (list.length === 0) return "";
  return `Known recurring errors for this learner (reuse a label verbatim in detected_patterns if it recurs):
${list.map((p) => `  - ${p}`).join("\n")}
`;
}

// A found word is certain and stated as fact. A miss is not: the search
// cannot know every inflection or spelling, and stating it as fact made the
// model tell learners that a word they had written was missing.
export function wordUsageNote(
  word: string,
  language: string,
  check: WordCheck,
): string {
  if (check.found) {
    return `✅ VERIFIED BY SYSTEM: The target word "${word}" WAS FOUND in the learner's translation (matched form: "${check.matchedForm}").
Trust this verification. DO NOT claim the word is missing. The learner DID use the target word. Give appropriate credit for usage_score (at least 0.7).`;
  }
  const isJapanese = language === "Japanese";
  return `⚠️ SYSTEM CHECK: An automatic search did not find "${word}" (or a regular inflection of it) in the learner's translation.
The search cannot recognise every form, so read the translation yourself before deciding:
- If the learner wrote "${word}" in another inflected form${isJapanese ? " or spelled it in kana instead of kanji" : ""}, it counts as USED: give usage credit and DO NOT say the word is missing.${isJapanese ? " For a kana spelling, also show the kanji spelling." : ""}
- Only if "${word}" is really absent (a synonym or a different word does NOT count): set usage_score to 0.0-0.3 and provide example sentences showing how to use "${word}" correctly.`;
}

export function buildMeaningUserPrompt(
  input: EvaluationInput,
  nativeLanguage: string,
): string {
  return [
    `Target language: ${input.language}`,
    `Learner's native language: ${nativeLanguage}`,
    readingRule(input.language).trim(),
    `Word: "${input.word}"`,
    `Reference definition: "${input.definition}"`,
    `Learner's answer: "${input.user_answer}"`,
  ].filter((line) => line.length > 0).join("\n");
}

export function buildTranslationUserPrompt(
  input: EvaluationInput,
  nativeLanguage: string,
  wordCheck: WordCheck,
): string {
  return [
    `Target language: ${input.language}`,
    `Learner's native language: ${nativeLanguage}`,
    readingRule(input.language).trim(),
    knownPatternsBlock(input.known_patterns).trim(),
    wordUsageNote(input.word, input.language, wordCheck),
    `Original sentence (${nativeLanguage}): "${input.question_context ?? ""}"`,
    `Target word/phrase to use: "${input.word}"`,
    `Word definition: "${input.definition}"`,
    `Learner's ${input.language} translation: "${input.user_answer}"`,
  ].filter((line) => line.length > 0).join("\n\n");
}

/** The Chat Completions body for one evaluation. */
export function buildEvaluationRequest(
  evalType: EvalType,
  input: EvaluationInput,
  nativeLanguage: string,
): Record<string, unknown> {
  const isTranslation = evalType === "translation";
  return {
    model: EVALUATION_MODEL,
    // The meaning check is a lenient synonym match; spending less reasoning
    // on it shortens the first wait of every review. The translation review
    // keeps the model's default effort.
    reasoning_effort: isTranslation ? "medium" : "low",
    response_format: strictJsonFormat("evaluation", EVALUATION_SCHEMA),
    messages: [
      {
        role: "system",
        content: isTranslation
          ? TRANSLATION_SYSTEM_PROMPT
          : MEANING_SYSTEM_PROMPT,
      },
      {
        role: "user",
        content: isTranslation
          ? buildTranslationUserPrompt(
            input,
            nativeLanguage,
            checkWordUsage(input.word, input.user_answer, input.language),
          )
          : buildMeaningUserPrompt(input, nativeLanguage),
      },
    ],
  };
}
