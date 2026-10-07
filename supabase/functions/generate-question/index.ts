import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

interface RequestBody {
  word: string;
  language: string;
  definition: string;
  usage: string;
  examples: string[];
  native_language: string; // e.g. "Korean"
  question_type: "translation";
}

interface QuestionResponse {
  question_type: "translation";
  sentence: string;   // sentence in native_language that uses the word's concept
  word_hint: string;  // the target word to use in translation
}

const systemPrompt = `You are a language learning exercise generator.
Create natural, contextual sentences in the learner's native language
that illustrate the meaning of a target vocabulary word.
Return ONLY valid JSON — no markdown, no code fences, no extra text.`;

function buildUserPrompt(body: RequestBody): string {
  const exampleStr = body.examples?.slice(0, 2).join("; ") ?? "";
  return `Target ${body.language} word: "${body.word}"
Definition: "${body.definition}"
Usage: "${body.usage}"
${exampleStr ? `Example sentences: "${exampleStr}"` : ""}

Create a sentence in ${body.native_language} that naturally conveys the concept of "${body.word}".
The sentence should make sense in everyday life and hint at the word's meaning without directly stating it.

Return a JSON object:
{
  "question_type": "translation",
  "sentence": "<A natural ${body.native_language} sentence (1-2 sentences) whose meaning, when translated to ${body.language}, naturally requires using the word '${body.word}' or a close equivalent>",
  "word_hint": "${body.word}"
}`;
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

  const { word, language, definition, native_language, question_type } = body;
  if (!word || !language || !definition || !native_language || !question_type) {
    return new Response("Missing required fields", { status: 400 });
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    return new Response("Server configuration error", { status: 500 });
  }

  const openaiRes = await fetch(OPENAI_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${openaiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.7,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: buildUserPrompt(body) },
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

  const result: QuestionResponse = {
    question_type: "translation",
    sentence: typeof raw.sentence === "string" ? raw.sentence : "",
    word_hint: typeof raw.word_hint === "string" ? raw.word_hint : word,
  };

  if (!result.sentence) {
    return new Response("AI returned empty sentence", { status: 502 });
  }

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
