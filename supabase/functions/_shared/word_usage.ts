import { normalizeLanguage } from "./language.ts";

/**
 * Deterministic check whether a translation contains the target word.
 *
 * A positive result is reliable and is given to the evaluator as a fact.
 * A negative result only means that no known form was found — the evaluator
 * still reads the answer itself (inflections this check does not know, kana
 * spellings…), see evaluate-answer.
 */
export interface WordCheck {
  found: boolean;
  matchedForm: string | null;
}

const NOT_FOUND: WordCheck = { found: false, matchedForm: null };

export function checkWordUsage(
  word: string,
  userAnswer: string,
  language: string,
): WordCheck {
  switch (normalizeLanguage(language)) {
    case "Japanese":
      return checkJapanese(word, userAnswer);
    case "Chinese":
    case "Korean":
      return checkSubstring(word, userAnswer);
    default:
      return checkAlphabetic(word, userAnswer);
  }
}

// ---------------------------------------------------------------------------
// Japanese
// ---------------------------------------------------------------------------

const KANJI = /[㐀-䶿一-鿿豈-﫿々]/;
const HIRAGANA_RUN = /^[ぁ-ゖ]{0,4}/;
// 相手(あいて) / 相手（あいて） reading annotations and 〜 placeholders are
// not part of the word.
const READING_ANNOTATION = /[(（][ぁ-ゖァ-ヺー・\s]*[)）]/g;
const PLACEHOLDER = /[〜～~…]/g;

/**
 * Kana that can follow the stem of each inflection class, so the dictionary
 * form also matches what learners actually write: 思う → 思った, 取る → 取って.
 */
const GODAN_NEXT: Record<string, string> = {
  "う": "わいうえおっ",
  "く": "かきくけこいっ", // っ: 行く → 行った
  "ぐ": "がぎぐげごい",
  "す": "さしすせそ",
  "つ": "たちつてとっ",
  "ぬ": "なにぬねのん",
  "ぶ": "ばびぶべぼん",
  "む": "まみむめもん",
  "る": "らりるれろっ",
};
// Verbs ending in る may be ichidan: 見た, 出ます, 食べない, 食べよう, 食べさせる
const ICHIDAN_NEXT = "るれろよたてまなさずらにちそすやづ";
// 高い → 高く, 高かった, 高ければ, 高さ, 高そう, 高すぎる, 高め, 高み
const I_ADJECTIVE_NEXT = "いくかけさそすめみ";
// 勉強する → 勉強した, 勉強します, 勉強させる, 勉強せず
const SURU_NEXT = "しすさせ";
// After a one-kanji stem that follows another kanji, these usually end a
// compound noun or na-adjective rather than inflect the verb: 大切な,
// 大切に, 大切さ are not 切る. (Japanese has no spaces, so 毎日働いて —
// a kanji right before the stem — is otherwise normal.)
const COMPOUND_NEXT = "なにさ";

interface Inflection {
  stem: string;
  next: string;
}

function inflections(word: string): Inflection[] {
  const result: Inflection[] = [];
  if (word.length > 2 && word.endsWith("する")) {
    result.push({ stem: word.slice(0, -2), next: SURU_NEXT });
  }
  const stem = word.slice(0, -1);
  if (!stem) return result;
  const last = word.slice(-1);
  if (last === "い") result.push({ stem, next: I_ADJECTIVE_NEXT });
  const godan = GODAN_NEXT[last];
  if (godan) {
    result.push({ stem, next: last === "る" ? godan + ICHIDAN_NEXT : godan });
  }
  return result;
}

function cleanJapaneseWord(word: string): string {
  return word
    .replace(READING_ANNOTATION, "")
    .replace(PLACEHOLDER, "")
    .normalize("NFKC")
    .replace(/\s+/g, "");
}

function checkJapanese(word: string, userAnswer: string): WordCheck {
  const target = cleanJapaneseWord(word);
  // NFKC: half-width katakana, full-width ASCII and compatibility kanji are
  // written differently by different keyboards.
  const text = userAnswer.normalize("NFKC").replace(/\s+/g, "");
  if (!target) return NOT_FOUND;
  if (text.includes(target)) return { found: true, matchedForm: target };

  for (const { stem, next } of inflections(target)) {
    const form = findInflected(text, stem, next);
    if (form) return { found: true, matchedForm: form };
  }
  return NOT_FOUND;
}

/** First occurrence of [stem] followed by one of [next], with its ending. */
function findInflected(text: string, stem: string, next: string): string | null {
  for (
    let i = text.indexOf(stem);
    i >= 0;
    i = text.indexOf(stem, i + 1)
  ) {
    const end = i + stem.length;
    const after = text.charAt(end); // "" at the end of the text
    if (!after || !next.includes(after)) continue;
    if (
      stem.length === 1 && COMPOUND_NEXT.includes(after) &&
      KANJI.test(text.charAt(i - 1))
    ) continue;
    const ending = text.slice(end).match(HIRAGANA_RUN)?.[0] ?? "";
    return stem + ending;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Chinese / Korean
// ---------------------------------------------------------------------------

function checkSubstring(word: string, userAnswer: string): WordCheck {
  const target = word.normalize("NFKC").trim().toLowerCase();
  const text = userAnswer.normalize("NFKC").toLowerCase();
  return target && text.includes(target)
    ? { found: true, matchedForm: word }
    : NOT_FOUND;
}

// ---------------------------------------------------------------------------
// Alphabetic languages
// ---------------------------------------------------------------------------

function escapeRegex(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Unicode-aware word boundaries: \b treats accented letters as non-word
// characters, so "café" or "sí" could never match.
function wordPattern(word: string, { prefix = false } = {}): RegExp {
  const end = prefix ? "" : "(?![\\p{L}\\p{N}_])";
  return new RegExp(`(?<![\\p{L}\\p{N}_])${escapeRegex(word)}${end}`, "iu");
}

const FUNCTION_WORDS = new Set([
  "be", "a", "an", "the", "to", "of", "in", "on", "at",
]);
const ENDINGS = ["s", "es", "ed", "ing", "er", "est", "ly"];
const IRREGULAR_FORMS: Record<string, string[]> = {
  be: ["is", "am", "are", "was", "were", "been", "being"],
  have: ["has", "had", "having"],
  do: ["does", "did", "doing", "done"],
  go: ["goes", "went", "going", "gone"],
};

function checkAlphabetic(word: string, userAnswer: string): WordCheck {
  const targetWord = word.normalize("NFC").trim().toLowerCase();
  const text = userAnswer.normalize("NFC");
  if (!targetWord) return NOT_FOUND;

  if (wordPattern(targetWord).test(text)) {
    return { found: true, matchedForm: word };
  }

  // Phrases like "be subject to": the content words must all be present.
  const wordParts = targetWord.split(/\s+/);
  if (wordParts.length > 1) {
    const contentWords = wordParts.filter((w) => !FUNCTION_WORDS.has(w));
    if (
      contentWords.length > 0 &&
      contentWords.every((cw) => wordPattern(cw, { prefix: true }).test(text))
    ) {
      return { found: true, matchedForm: contentWords.join(" ") };
    }
  }

  for (const ending of ENDINGS) {
    const conjugated = targetWord + ending;
    if (wordPattern(conjugated).test(text)) {
      return { found: true, matchedForm: conjugated };
    }
  }

  for (const form of IRREGULAR_FORMS[targetWord] ?? []) {
    if (wordPattern(form).test(text)) {
      return { found: true, matchedForm: form };
    }
  }

  return NOT_FOUND;
}
