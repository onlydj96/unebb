import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

interface RequestBody {
  word: string;
  language: string;
  definition: string;
  usage: string;
  user_answer: string;
  answer_type: "text" | "voice";
  // New: replaces question_type. Accept old name for backwards compat.
  eval_type?: "meaning" | "translation";
  question_type?: "free_recall" | "translation"; // legacy — mapped to eval_type
  question_context?: string; // For translation: the native-language sentence shown to user
  known_patterns?: string[]; // User's pre-existing error patterns (max 5)
  native_language?: string; // Learner's native language for feedback
}

interface EvaluationResponse {
  meaning_score: number;
  usage_score: number;
  example_score: number;
  grammar_score: number;
  overall_score: number;
  feedback: string;
  weak_point: string | null;
  detected_patterns: string[]; // NEW: patterns found in this answer
}

const systemPrompt = `You are an expert language learning evaluator.
Evaluate how well a learner understands a vocabulary word based on their response.
Focus on SEMANTIC UNDERSTANDING, not exact wording.
Return ONLY valid JSON — no markdown, no code fences, no extra text.
All scores must be numbers between 0.0 and 1.0.`;

function buildKnownPatternsBlock(patterns: string[] | undefined): string {
  if (!patterns || patterns.length === 0) return "";
  const list = patterns.slice(0, 5).map((p) => `  - ${p}`).join("\n");
  return `Known recurring errors for this learner:\n${list}\nCheck whether any of these patterns recur.\n\n`;
}

function buildMeaningPrompt(body: RequestBody, nativeLanguage: string): string {
  return `Check if the learner knows the meaning of the ${body.language} word: "${body.word}"

Reference definition: "${body.definition}"
Learner's answer: "${body.user_answer}"
The learner's native language is ${nativeLanguage}. Write feedback and weak_point in ${nativeLanguage}.

This is a SIMPLE meaning check. The learner should provide a brief translation or definition.
Be LENIENT - accept synonyms and paraphrases that capture the core meaning.

Examples of acceptable answers for "adjacent":
- "인접한" ✓
- "가까운" ✓ (close enough)
- "옆에 있는" ✓ (paraphrase)
- "나란히" ✓ (synonym)

Return a JSON object with exactly these fields:
{
  "meaning_score": <0.0–1.0, does the answer capture the core meaning? Be LENIENT>,
  "usage_score": <always set to meaning_score for this simple check>,
  "example_score": <always set to meaning_score>,
  "grammar_score": <always 1.0 for brief answers>,
  "overall_score": <same as meaning_score>,
  "feedback": "<very brief feedback in ${nativeLanguage}: '정확합니다!' or '아쉽게도 틀렸습니다'>",
  "weak_point": "<only if wrong, explain the correct meaning briefly in ${nativeLanguage}>",
  "detected_patterns": []
}

Pattern detection guidance for detected_patterns:
- List 0–3 SHORT labels (max 12 words each) for RECURRING grammar or usage errors
  observed in THIS answer that a language teacher would flag.
- Example: "uses infinitive instead of gerund after prepositions"
- Only include genuinely problematic patterns, not minor slips.
- Return an empty array [] if no significant patterns found.

Scoring guidance:
- 0.9–1.0: Excellent understanding
- 0.7–0.9: Good understanding with minor gaps
- 0.5–0.7: Partial understanding
- 0.3–0.5: Significant gaps
- 0.0–0.3: Fundamental misunderstanding`;
}

function buildTranslationPrompt(body: RequestBody, nativeLanguage: string): string {
  return `You are an expert ${body.language} teacher providing detailed, constructive feedback on a learner's translation.

Original sentence (${nativeLanguage}): "${body.question_context}"
Target word/phrase to use: "${body.word}"
Word definition: "${body.definition}"
Learner's ${body.language} translation: "${body.user_answer}"

The learner's native language is ${nativeLanguage}. ALL feedback and weak_point MUST be written in ${nativeLanguage}.
${buildKnownPatternsBlock(body.known_patterns)}

CRITICAL EVALUATION RULES:
1. The target word/phrase "${body.word}" may be given in its base/infinitive form (e.g., "be subject to")
2. The learner MUST use this word/phrase, but may need to conjugate/adapt it for grammar (e.g., "is subject to", "was subject to", "are subject to")
3. ACCEPT grammatically correct variations of the target word/phrase:
   - Verb conjugations: "be" → "is/am/are/was/were/been/being"
   - Tense changes: "run" → "runs/ran/running"
   - Subject-verb agreement: "he is subject to" (NOT "he be subject to")
4. DO NOT penalize correct grammatical adaptations of the target word/phrase
5. The learner deserves FULL credit if they use the target word/phrase with correct grammar

Your task:
1. Check if the learner used "${body.word}" (or its grammatically correct form) in their translation
2. Analyze the translation for meaning accuracy, word usage, grammar, and naturalness
3. Provide SPECIFIC, DETAILED feedback on what works and what doesn't
4. Explain grammatical errors with examples
5. Suggest more natural alternatives when applicable
6. CRITICAL: If the learner did NOT use "${body.word}" at all in their translation, you MUST provide example sentences that correctly use "${body.word}" in the feedback

Return a JSON object with exactly these fields:
{
  "meaning_score": <0.0–1.0, does the translation preserve the original meaning?>,
  "usage_score": <0.0–1.0, did the learner use "${body.word}" (or its grammatically correct form) in context? FULL CREDIT if they conjugated it correctly>,
  "example_score": <0.0–1.0, is the translation natural and idiomatic? Would a native speaker say this?>,
  "grammar_score": <0.0–1.0, is the ${body.language} grammatically correct?>,
  "overall_score": <0.0–1.0, overall translation quality>,
  "feedback": "<DETAILED feedback in ${nativeLanguage}, 3-5 sentences covering:
    - What the learner did well (specific praise, especially if they correctly conjugated "${body.word}")
    - If they used a grammatically correct form of "${body.word}" (e.g., "is subject to" from "be subject to"), PRAISE this!
    - Specific grammar errors with corrections (e.g., '시제 오류: was standing → stood가 더 자연스럽습니다')
    - Word choice issues (e.g., '단어 선택: "place" 대신 "location" 또는 "spot"이 더 적절합니다')
    - Naturalness improvements (e.g., '어순: 영어에서는 "I was standing at a place adjacent to the building" 보다 "I stood next to the building" 또는 "I was standing in a spot adjacent to the building"이 더 자연스럽습니다')
    - **CRITICAL**: If the learner did NOT use "${body.word}" AT ALL (not even a conjugated form), provide 1-2 example sentences showing how to correctly use "${body.word}" in this context
      Example: '목표 단어 "${body.word}" 사용 예시: "I was standing in a spot adjacent to the building." 또는 "The cafe is adjacent to the library."'
    - Provide a COMPLETE, corrected version of the sentence>",
  "weak_point": "<ONE most important specific issue to focus on in ${nativeLanguage}, with concrete example and correction.
    Format: '[Category]: [Specific error] → [Correction]'
    Example: '관사 사용: "I was standing at place"에서 "a place" 또는 "the place"가 필요합니다'
    Example: '전치사 선택: "adjacent with" → "adjacent to"가 올바른 표현입니다'
    Example: '시제 일치: 과거 상황이므로 "am standing" → "was standing"이 적절합니다'
    Example: '목표 단어 미사용: "${body.word}"를 사용하지 않았습니다 → "I stood next to the building" 대신 "I was standing in a spot adjacent to the building"처럼 "${body.word}"를 포함해야 합니다'
    If translation is excellent (score > 0.9), set to null>",
  "detected_patterns": ["<short error pattern label in ${nativeLanguage}>", ...]
}

Pattern detection guidance for detected_patterns:
- List 0–3 SHORT labels (max 12 words each) for RECURRING grammar or usage errors
- Examples: "관사(a/an/the) 누락", "전치사 혼동 (at/in/on)", "시제 불일치", "어순 부자연스러움"
- Only include genuinely problematic patterns that indicate systematic gaps in knowledge
- Return an empty array [] if no significant patterns found

Scoring guidance:
- 0.9–1.0: Excellent - used target word/phrase with correct grammar, natural, grammatically perfect, idiomatic
- 0.7–0.9: Good - used target word/phrase correctly, meaning clear, minor grammar/naturalness issues
- 0.5–0.7: Acceptable - used target word/phrase, meaning mostly preserved, noticeable grammar errors or awkward phrasing
- 0.3–0.5: Poor - target word missing OR used incorrectly, meaning partially lost, significant grammar errors
- 0.0–0.3: Very poor - target word completely missing, meaning lost, major errors

CRITICAL SCORING RULES:
1. If learner used "${body.word}" in ANY grammatically correct form (e.g., "is subject to" from "be subject to"), they deserve AT LEAST 0.7 overall_score
2. DO NOT give 0.0-0.3 scores if they correctly used a conjugated/adapted form of "${body.word}"
3. Be SPECIFIC and CONSTRUCTIVE. Instead of "문법 오류가 있습니다", say "관사 오류: 'place' 앞에 'a'가 필요합니다 (a place)"
4. Recognize and PRAISE correct conjugations: "be subject to" → "is subject to" is CORRECT for 3rd person singular!`;
}

function clampScore(score: unknown): number {
  const n = typeof score === "number" ? score : parseFloat(String(score));
  if (isNaN(n)) return 0;
  return Math.min(1.0, Math.max(0.0, n));
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Missing authorization", { status: 401 });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const { word, language, definition, user_answer, answer_type } = body;
  if (!word || !language || !definition || !user_answer || !answer_type) {
    return new Response("Missing required fields", { status: 400 });
  }

  // Resolve eval type: new field takes priority, legacy field as fallback
  const evalType: "meaning" | "translation" =
    body.eval_type ??
    (body.question_type === "translation" ? "translation" : "meaning");

  if (evalType === "translation" && !body.question_context) {
    return new Response(
      "question_context required for translation type",
      { status: 400 },
    );
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    return new Response("Server configuration error", { status: 500 });
  }

  const nativeLanguage = body.native_language || "Korean";

  const userPrompt = evalType === "translation"
    ? buildTranslationPrompt(body, nativeLanguage)
    : buildMeaningPrompt(body, nativeLanguage);

  const openaiRes = await fetch(OPENAI_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${openaiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
    }),
  });

  if (!openaiRes.ok) {
    const errText = await openaiRes.text();
    console.error("OpenAI error:", errText);
    return new Response("AI service error", { status: 502 });
  }

  const openaiJson = await openaiRes.json();
  const content = openaiJson.choices?.[0]?.message?.content;
  if (!content) {
    return new Response("Empty AI response", { status: 502 });
  }

  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(content);
  } catch {
    console.error("Failed to parse AI response:", content);
    return new Response("Invalid AI response format", { status: 502 });
  }

  const evaluation: EvaluationResponse = {
    meaning_score: clampScore(raw.meaning_score),
    usage_score: clampScore(raw.usage_score),
    example_score: clampScore(raw.example_score),
    grammar_score: clampScore(raw.grammar_score),
    overall_score: clampScore(raw.overall_score),
    feedback: typeof raw.feedback === "string" ? raw.feedback : "",
    weak_point:
      typeof raw.weak_point === "string" && raw.weak_point.length > 0
        ? raw.weak_point
        : null,
    detected_patterns: Array.isArray(raw.detected_patterns)
      ? (raw.detected_patterns as unknown[])
          .filter((p): p is string => typeof p === "string" && p.length > 0)
          .slice(0, 3)
      : [],
  };

  return new Response(JSON.stringify(evaluation), {
    headers: { "Content-Type": "application/json" },
  });
});
