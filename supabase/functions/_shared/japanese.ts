// Kanji are unreadable without their reading, so every Japanese text the
// learner reads outside of a question carries hiragana after each kanji word.

/**
 * Prompt block that makes the model annotate every kanji word in [fields]
 * with its hiragana reading: 漢字(かんじ).
 */
export function kanjiReadingRule(fields: string[]): string {
  return `
KANJI READING RULE (mandatory — the learner may not be able to read kanji):
Every time Japanese text containing kanji appears in ${fields.join(", ")}, write the hiragana
reading in parentheses immediately after each kanji word: 漢字(ひらがな).
- Annotate each kanji word separately; okurigana stays outside: 連絡(れんらく)を取(と)る
- Words written only in hiragana or katakana get no annotation: ありがとう, コーヒー
- Example sentence: 相手(あいて)に連絡(れんらく)を取(と)った。
- Collocation: 決心(けっしん)をする
- Japanese quoted inside native-language text: "相手(あいて)"는 대화나 행동의 대상이 되는 사람을 뜻합니다.
`;
}

const NOT_KANA = /[^ぁ-ゖァ-ヺー]/g;

/** Keeps only the kana of a reading: "相手(あいて)" → "あいて", "/aite/" → "". */
export function kanaOnly(text: string): string {
  return text.normalize("NFKC").replace(NOT_KANA, "");
}
