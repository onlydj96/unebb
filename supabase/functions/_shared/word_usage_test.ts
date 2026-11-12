// Run: deno test supabase/functions/_shared
//  or: node --test supabase/functions/_shared/word_usage_test.ts (Node ≥ 23)
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { kanaOnly } from "./japanese.ts";
import { normalizeLanguage } from "./language.ts";
import { checkWordUsage } from "./word_usage.ts";

const found = (word: string, answer: string, language = "Japanese") =>
  checkWordUsage(word, answer, language).found;

test("normalizeLanguage maps ISO codes and names to the app's names", () => {
  assert.equal(normalizeLanguage("ja"), "Japanese");
  assert.equal(normalizeLanguage(" JA-jp "), "Japanese");
  assert.equal(normalizeLanguage("ja_JP"), "Japanese");
  assert.equal(normalizeLanguage("japanese"), "Japanese");
  assert.equal(normalizeLanguage("Japanese"), "Japanese");
  assert.equal(normalizeLanguage("en"), "English");
  assert.equal(normalizeLanguage("es-MX"), "Spanish");
  assert.equal(normalizeLanguage("Klingon"), "Klingon");
  assert.equal(normalizeLanguage(undefined), "");
});

// Real answers that were graded "target word missing" (language stored as "ja").
test("Japanese words stored with the 'ja' code are found", () => {
  assert.ok(found("思う", "はたしはあのえががとってもおもしろいだと思う", "ja"));
  assert.ok(found("雨", "今日は外にあったら우산を持ってるね。なぜなら雨が来る気がする", "ja"));
  assert.ok(found("店", "はたしはまちにある一番すきな店に行きます。", "ja"));
  assert.ok(found("国", "ぼくはいろんあ文化を持ってる国に旅行するのを好きです。", "ja"));
  assert.ok(found("人", "あの人は本とに易しい。", "ja"));
  assert.ok(found("男", "あの男はいつも정장を言って来ます。", "ja"));
});

test("Japanese words really absent are still reported missing", () => {
  assert.ok(!found("道", "こにまちは本とに美しいと涼しい。", "ja"));
  assert.ok(!found("先生", "おれたちのはんの", "ja"));
  assert.ok(!found("学生", "僕の友達は大學で勉強している学校です。", "ja"));
});

test("Japanese verbs are found in inflected forms", () => {
  assert.deepEqual(checkWordUsage("思う", "本当にそう思った。", "Japanese"), {
    found: true,
    matchedForm: "思った",
  });
  assert.ok(found("思う", "そう思います"));
  assert.ok(found("思う", "そう思わない"));
  assert.ok(found("働く", "毎日働いています"));
  assert.ok(found("行く", "学校に行った"));
  assert.ok(found("泳ぐ", "海で泳いだ"));
  assert.ok(found("話す", "友達と話した"));
  assert.ok(found("待つ", "駅で待って"));
  assert.ok(found("死ぬ", "花が死んだ"));
  assert.ok(found("遊ぶ", "公園で遊んで"));
  assert.ok(found("読む", "本を読みました"));
  assert.ok(found("連絡を取る", "昨日、相手に連絡を取った。"));
  assert.ok(found("食べる", "朝ご飯を食べた"));
  assert.ok(found("食べる", "食べられない"));
  assert.ok(found("見る", "映画を見ました"));
  assert.ok(found("出る", "家を出た"));
  assert.ok(found("来る", "友達が来ない"));
});

test("Japanese adjectives and する-verbs are found in inflected forms", () => {
  assert.ok(found("高い", "値段が高かった"));
  assert.ok(found("美しい", "美しくて静かです"));
  assert.ok(found("勉強する", "毎日勉強しています"));
  assert.ok(found("決心する", "留学すると決心した"));
});

test("Japanese matching ignores spacing, readings and width variants", () => {
  assert.ok(found("相手(あいて)", "相手に連絡した"));
  assert.ok(found("〜に対して", "彼に対して怒った"));
  assert.ok(found("思う", "そう 思 った"));
  assert.ok(found("コーヒー", "ｺｰﾋｰを飲む"));
});

test("Japanese inflection matching does not accept other words", () => {
  assert.ok(!found("切る", "大切なものです")); // 大切 is not 切る
  assert.ok(!found("切る", "大切にしてください"));
  assert.ok(!found("働く", "労働は大変だ"));
  assert.ok(found("切る", "紙を切った"));
  assert.ok(!found("思う", "思")); // a bare stem is not a form
  assert.ok(!found("思う", "おもう")); // kana spelling is left to the evaluator
});

test("alphabetic matching handles accents and inflections", () => {
  assert.ok(found("café", "Fuimos al café ayer.", "es"));
  assert.ok(found("sí", "Dijo que sí.", "Spanish"));
  assert.ok(!found("sí", "Así es.", "Spanish"));
  assert.ok(found("adjacent", "The shop is adjacent to the bank.", "en"));
  assert.ok(found("be subject to", "Prices are subject to change.", "English"));
  assert.ok(found("abandon", "They abandoned the car.", "English"));
  assert.ok(found("go", "She went home.", "English"));
  assert.ok(!found("adjacent", "The shop is next to the bank.", "English"));
});

test("kanaOnly keeps the kana of a reading", () => {
  assert.equal(kanaOnly("あいて"), "あいて");
  assert.equal(kanaOnly("相手(あいて)"), "あいて");
  assert.equal(kanaOnly("/byōin/"), "");
  assert.equal(kanaOnly("ｺｰﾋｰ"), "コーヒー");
});
