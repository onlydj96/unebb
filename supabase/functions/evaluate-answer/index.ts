import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { requireUser } from "../_shared/auth.ts";
import { normalizeLanguage } from "../_shared/language.ts";
import { chatJson } from "../_shared/openai.ts";
import {
  buildEvaluationRequest,
  type EvalType,
  type EvaluationResponse,
} from "./prompts.ts";

// The app gives up after 30s (AiEvaluationService); stop paying for the
// call a few seconds before that.
const OPENAI_TIMEOUT_MS = 27_000;

interface RequestBody {
  word: string;
  language: string;
  definition: string;
  usage: string;
  user_answer: string;
  answer_type: "text" | "voice";
  // New: replaces question_type. Accept old name for backwards compat.
  eval_type?: EvalType;
  question_type?: "free_recall" | "translation"; // legacy — mapped to eval_type
  question_context?: string; // For translation: the native-language sentence shown to user
  known_patterns?: string[]; // User's pre-existing error patterns (max 5)
  native_language?: string; // Learner's native language for feedback
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

  // Only signed-in users may spend OpenAI credit (the anon key used to pass).
  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  // Words can be stored with ISO codes ("ja"); the rules below key on names.
  body.language = normalizeLanguage(body.language);
  const { word, language, user_answer, answer_type } = body;
  if (!word || !language || !user_answer || !answer_type) {
    return new Response("Missing required fields", { status: 400 });
  }
  // A word whose AI explanation failed has no definition yet; evaluate it
  // with the model's own knowledge instead of failing the review (400).
  body.definition = body.definition?.trim() || "(no reference definition available)";

  // Resolve eval type: new field takes priority, legacy field as fallback
  const evalType: EvalType =
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

  const result = await chatJson({
    apiKey: openaiKey,
    timeoutMs: OPENAI_TIMEOUT_MS,
    body: buildEvaluationRequest(evalType, body, nativeLanguage),
  });
  if (!result.ok) return result.response;
  const raw = result.json;

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
    // The meaning check does not track error patterns.
    detected_patterns: evalType === "translation" &&
        Array.isArray(raw.detected_patterns)
      ? (raw.detected_patterns as unknown[])
          .filter((p): p is string => typeof p === "string" && p.length > 0)
          .slice(0, 3)
      : [],
  };

  return new Response(JSON.stringify(evaluation), {
    headers: { "Content-Type": "application/json" },
  });
});
