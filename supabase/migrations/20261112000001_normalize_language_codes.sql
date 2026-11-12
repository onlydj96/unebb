-- Migration: store languages by the app's English names
--
-- Imported words were stored with ISO codes ('ja', 'en', 'es') while the app
-- and the Edge Functions use names ('Japanese'). Japanese words stored as
-- 'ja' therefore never got the Japanese rules: no hiragana readings, an IPA
-- "pronunciation", and the word-usage check of evaluate-answer reported the
-- target word as missing even when the learner had written it.
--
-- The Edge Functions now normalise codes themselves; this aligns the data so
-- decks, filters, labels and text-to-speech see one value per language.
--
-- A word that already exists under the name (same user, same spelling) keeps
-- its code: renaming it would violate vocabulary_items_user_word_idx, and
-- merging duplicates (with their review history) is left to the user.

create or replace function pg_temp.language_name(code text)
returns text
language sql
immutable
as $$
  select case split_part(replace(lower(btrim(code)), '_', '-'), '-', 1)
    when 'en' then 'English'
    when 'es' then 'Spanish'
    when 'fr' then 'French'
    when 'de' then 'German'
    when 'ja' then 'Japanese'
    when 'jp' then 'Japanese'
    when 'zh' then 'Chinese'
    when 'ko' then 'Korean'
    when 'kr' then 'Korean'
    when 'it' then 'Italian'
    when 'pt' then 'Portuguese'
    when 'ru' then 'Russian'
  end
$$;

update public.vocabulary_items v
set language = pg_temp.language_name(v.language)
where pg_temp.language_name(v.language) is not null
  and v.language <> pg_temp.language_name(v.language)
  and not exists (
    select 1
    from public.vocabulary_items o
    where o.user_id = v.user_id
      and lower(o.word) = lower(v.word)
      and o.language = pg_temp.language_name(v.language)
  );

update public.decks d
set language = pg_temp.language_name(d.language)
where pg_temp.language_name(d.language) is not null
  and d.language <> pg_temp.language_name(d.language);
