// The app stores languages by English name ("Japanese"), but imported words
// can carry ISO codes ("ja", "ja-JP"). Every prompt and language-specific
// rule keys on the name, so requests are normalised before use — a word
// stored as "ja" used to skip the Japanese rules entirely (no kanji readings,
// and the word-usage check always reported the word as missing).

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  es: "Spanish",
  fr: "French",
  de: "German",
  ja: "Japanese",
  jp: "Japanese",
  zh: "Chinese",
  ko: "Korean",
  kr: "Korean",
  it: "Italian",
  pt: "Portuguese",
  ru: "Russian",
};

const NAMES = new Map(
  Object.values(LANGUAGE_NAMES).map((name) => [name.toLowerCase(), name]),
);

/** "ja", "JA-jp", "japanese" → "Japanese". Unknown values are returned trimmed. */
export function normalizeLanguage(raw: string | null | undefined): string {
  const value = (raw ?? "").trim();
  const key = value.toLowerCase();
  return NAMES.get(key) ??
    LANGUAGE_NAMES[key] ??
    LANGUAGE_NAMES[key.split(/[-_]/)[0]] ??
    value;
}
