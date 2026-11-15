import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { requireUser } from "../_shared/auth.ts";
import { normalizeLanguage } from "../_shared/language.ts";
import { chatJson } from "../_shared/openai.ts";
import { buildQuestionRequest, type QuestionInput } from "./prompt.ts";

// The app gives up after 30s (AiQuestionService); stop paying for the call
// a few seconds before that.
const OPENAI_TIMEOUT_MS = 27_000;

interface RequestBody extends QuestionInput {
  question_type: "translation";
}

interface QuestionResponse {
  question_type: "translation";
  sentence: string;   // sentence in native_language that uses the word's concept
  word_hint: string;  // the target word to use in translation
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

  body.language = normalizeLanguage(body.language);
  const { word, language, definition, native_language, question_type } = body;
  if (!word || !language || !definition || !native_language || !question_type) {
    return new Response("Missing required fields", { status: 400 });
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    return new Response("Server configuration error", { status: 500 });
  }

  const ai = await chatJson({
    apiKey: openaiKey,
    timeoutMs: OPENAI_TIMEOUT_MS,
    body: buildQuestionRequest(body),
  });
  if (!ai.ok) return ai.response;
  const raw = ai.json;

  const result: QuestionResponse = {
    question_type: "translation",
    sentence: typeof raw.sentence === "string" ? raw.sentence : "",
    // Always the stored word: the model could echo it with the reading from
    // the (annotated) examples, which would give the answer away.
    word_hint: word,
  };

  if (!result.sentence) {
    return new Response("AI returned empty sentence", { status: 502 });
  }

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
