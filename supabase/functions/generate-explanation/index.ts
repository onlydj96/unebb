import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { isUuid, requireUser, textResponse } from "../_shared/auth.ts";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

interface RequestBody {
  vocabulary_id: string;
  word?: string; // ignored — the stored word is authoritative
  language?: string; // ignored — the stored language is authoritative
  native_language?: string;
}

interface ExplanationResponse {
  pronunciation: string;
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

// Kanji are unreadable without their reading, so every Japanese word written
// in kanji — in any field, including words quoted inside the native-language
// explanation — carries its hiragana in parentheses.
const japaneseReadingRule = `
KANJI READING RULE (mandatory):
Every time Japanese text containing kanji appears in ANY field (definition, explanation,
usage, examples, synonyms, collocations, common_mistakes), write the hiragana reading in
parentheses immediately after each kanji word: 漢字(ひらがな).
- Annotate each kanji word separately; okurigana stays outside: 連絡(れんらく)を取(と)る
- Words written only in hiragana or katakana get no annotation: ありがとう, コーヒー
- Example sentence: 相手(あいて)に連絡(れんらく)を取(と)った。
- Collocation: 決心(けっしん)をする
- Japanese quoted inside native-language text: "相手(あいて)"는 대화나 행동의 대상이 되는 사람을 뜻합니다.
The "pronunciation" field is the exception: it is the hiragana reading of the whole word only.
`;

function buildUserPrompt(word: string, language: string, nativeLanguage: string): string {
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

function asText(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function asTextList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((v): v is string => typeof v === "string" && v.trim().length > 0)
    : [];
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return textResponse("Method not allowed", 405);
  }

  // 1. Who is calling?
  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return textResponse("Invalid JSON body", 400);
  }
  if (!isUuid(body.vocabulary_id)) {
    return textResponse("vocabulary_id must be a UUID", 400);
  }
  const nativeLanguage = asText(body.native_language) ?? "Korean";

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!openaiKey || !supabaseUrl || !serviceKey) {
    return textResponse("Server configuration error", 500);
  }
  const dbHeaders = {
    "Content-Type": "application/json",
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };
  // Every query is scoped to the caller: the service role bypasses RLS, so
  // ownership must be enforced here (previously any caller could overwrite
  // any user's word by id).
  const rowFilter =
    `id=eq.${body.vocabulary_id}&user_id=eq.${auth.userId}`;

  // 2. Load the word from the caller's own vocabulary before spending credit.
  const rowRes = await fetch(
    `${supabaseUrl}/rest/v1/vocabulary_items?${rowFilter}&select=word,language`,
    { headers: dbHeaders },
  );
  if (!rowRes.ok) {
    console.error("DB read error:", await rowRes.text());
    return textResponse("Database read failed", 500);
  }
  const rows = await rowRes.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  if (!row) return textResponse("Vocabulary item not found", 404);

  // 3. Generate the content.
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
        { role: "user", content: buildUserPrompt(row.word, row.language, nativeLanguage) },
      ],
    }),
  });

  if (!openaiRes.ok) {
    console.error("OpenAI error:", await openaiRes.text());
    return textResponse("AI service error", 502);
  }

  const openaiJson = await openaiRes.json();
  const content = openaiJson.choices?.[0]?.message?.content;
  if (!content) return textResponse("Empty AI response", 502);

  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(content);
  } catch {
    console.error("Failed to parse AI response:", content);
    return textResponse("Invalid AI response format", 502);
  }

  // 4. Validate before persisting — a missing definition would leave the word
  //    unusable for reviews.
  const explanation: ExplanationResponse = {
    pronunciation: asText(raw.pronunciation) ?? "",
    definition: asText(raw.definition) ?? "",
    explanation: asText(raw.explanation) ?? "",
    usage: asText(raw.usage) ?? "",
    examples: asTextList(raw.examples),
    synonyms: asTextList(raw.synonyms),
    collocations: asTextList(raw.collocations),
    common_mistakes: asTextList(raw.common_mistakes),
  };
  if (!explanation.definition) {
    console.error("AI response without definition:", content);
    return textResponse("Invalid AI response format", 502);
  }

  // 5. Persist (scoped to the caller's row). The word filter skips the write
  //    if the word was renamed while generating — the content describes the
  //    old spelling; the client regenerates for the new one.
  const unchangedWord = `&word=eq.${encodeURIComponent(row.word)}`;
  const updateRes = await fetch(
    `${supabaseUrl}/rest/v1/vocabulary_items?${rowFilter}${unchangedWord}`,
    {
      method: "PATCH",
      headers: { ...dbHeaders, Prefer: "return=representation" },
      body: JSON.stringify(explanation),
    },
  );

  if (!updateRes.ok) {
    console.error("DB update error:", await updateRes.text());
    return textResponse("Database update failed", 500);
  }

  const updated = await updateRes.json();
  if (!Array.isArray(updated) || updated.length === 0) {
    // Deleted or renamed between the read and the write.
    return textResponse("Vocabulary item changed during generation", 409);
  }
  return new Response(JSON.stringify(updated[0]), {
    headers: { "Content-Type": "application/json" },
  });
});
