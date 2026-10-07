import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

interface RequestBody {
  vocabulary_id: string;
  word: string;
  language: string;
  native_language?: string;
}

interface ExplanationResponse {
  definition: string;
  explanation: string;
  usage: string;
  examples: string[];
  synonyms: string[];
  collocations: string[];
  common_mistakes: string[];
}

const systemPrompt = `You are a vocabulary learning assistant.
Given a word and its language, generate educational content to help learners remember and use it.
Return ONLY valid JSON — no markdown, no code fences, no extra text.`;

function buildUserPrompt(word: string, language: string, nativeLanguage: string): string {
  return `Generate learning content for the ${language} word: "${word}"
The learner's native language is ${nativeLanguage}. Write explanations in ${nativeLanguage}.

Return a JSON object with exactly these fields:
{
  "definition": "Clear, concise definition in ${nativeLanguage} (1-2 sentences)",
  "explanation": "Explanation of nuance, origin, or context in ${nativeLanguage} (2-3 sentences)",
  "usage": "When and how to use this word in ${nativeLanguage} (1-2 sentences)",
  "examples": ["3 natural example sentences using the word in ${language}"],
  "synonyms": ["3-5 synonyms or near-synonyms in ${language}"],
  "collocations": ["4-6 common word combinations in ${language} (e.g. 'make a decision')"],
  "common_mistakes": ["2-3 common mistakes ${nativeLanguage} speakers make, with corrections in ${nativeLanguage}"]
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

  const { vocabulary_id, word, language, native_language } = body;
  if (!vocabulary_id || !word || !language) {
    return new Response("Missing required fields", { status: 400 });
  }
  const nativeLanguage = native_language || "Korean";

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
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: buildUserPrompt(word, language, nativeLanguage) },
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

  let explanation: ExplanationResponse;
  try {
    explanation = JSON.parse(content);
  } catch {
    console.error("Failed to parse AI response:", content);
    return new Response("Invalid AI response format", { status: 502 });
  }

  // Persist to Supabase using service role (bypasses RLS for server write)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const updateRes = await fetch(
    `${supabaseUrl}/rest/v1/vocabulary_items?id=eq.${vocabulary_id}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        definition: explanation.definition,
        explanation: explanation.explanation,
        usage: explanation.usage,
        examples: explanation.examples,
        synonyms: explanation.synonyms,
        collocations: explanation.collocations,
        common_mistakes: explanation.common_mistakes,
      }),
    }
  );

  if (!updateRes.ok) {
    const errText = await updateRes.text();
    console.error("DB update error:", errText);
    return new Response("Database update failed", { status: 500 });
  }

  const updated = await updateRes.json();
  return new Response(JSON.stringify(updated[0] ?? {}), {
    headers: { "Content-Type": "application/json" },
  });
});
