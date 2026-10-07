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

function buildMeaningPrompt(body: RequestBody): string {
  return `Evaluate the learner's understanding of the ${body.language} word: "${body.word}"

Reference definition: "${body.definition}"
Reference usage: "${body.usage}"
Learner's answer: "${body.user_answer}"
${buildKnownPatternsBlock(body.known_patterns)}
Return a JSON object with exactly these fields:
{
  "meaning_score": <0.0–1.0, does the learner understand the core meaning?>,
  "usage_score": <0.0–1.0, does the learner understand when/how to use the word?>,
  "example_score": <0.0–1.0, if an example was provided, is it appropriate?>,
  "grammar_score": <0.0–1.0, is the learner's language grammatically valid?>,
  "overall_score": <0.0–1.0, overall understanding>,
  "feedback": "<concise, educational feedback focused on what they got right/wrong>",
  "weak_point": "<one specific weakness to address, or null if none>",
  "detected_patterns": ["<short label for pattern A>", ...]
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

function buildTranslationPrompt(body: RequestBody): string {
  return `Evaluate the learner's translation of a sentence that conveys the concept of the ${body.language} word: "${body.word}"

Original sentence shown to learner: "${body.question_context}"
Target word to use in translation: "${body.word}"
Word definition: "${body.definition}"
Learner's ${body.language} translation: "${body.user_answer}"
${buildKnownPatternsBlock(body.known_patterns)}
Evaluate:
1. Overall translation accuracy (does it convey the same meaning?)
2. Correct usage of "${body.word}" or its equivalent in ${body.language}
3. Grammar and naturalness of the ${body.language} translation

Return a JSON object with exactly these fields:
{
  "meaning_score": <0.0–1.0, does the translation preserve the original meaning?>,
  "usage_score": <0.0–1.0, did the learner use "${body.word}" or equivalent correctly?>,
  "example_score": <0.0–1.0, is the translation natural and idiomatic?>,
  "grammar_score": <0.0–1.0, is the ${body.language} grammatically correct?>,
  "overall_score": <0.0–1.0, overall translation quality>,
  "feedback": "<concise feedback on translation quality and word usage>",
  "weak_point": "<one specific issue to improve, or null if none>",
  "detected_patterns": ["<short label for pattern A>", ...]
}

Pattern detection guidance for detected_patterns:
- List 0–3 SHORT labels (max 12 words each) for RECURRING grammar or usage errors
  observed in THIS translation that a language teacher would flag.
- Example: "omits article before countable noun", "confuses preposition 'at' with 'in'"
- Only include genuinely problematic patterns, not minor slips.
- Return an empty array [] if no significant patterns found.

Scoring guidance:
- 0.9–1.0: Excellent translation with natural word usage
- 0.7–0.9: Good translation with minor issues
- 0.5–0.7: Acceptable but with noticeable problems
- 0.3–0.5: Significant translation errors
- 0.0–0.3: Major misunderstanding or missing the target word entirely`;
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

  const userPrompt = evalType === "translation"
    ? buildTranslationPrompt(body)
    : buildMeaningPrompt(body);

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
