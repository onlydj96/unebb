-- Migration: record error patterns atomically in one call
--
-- The app recorded each detected pattern with SELECT → INSERT → one UPDATE
-- per existing row, twice per answer (word-specific and global): several
-- round trips, and two answers saved at the same time could lose count
-- increments or insert duplicate rows, because nothing made
-- (user_id, vocabulary_id, pattern_text) unique.
--
-- This merges existing duplicates, adds that unique key (a NULL
-- vocabulary_id is the global pattern, so NULLs must compare equal) and adds
-- record_error_patterns(), which does both upserts in one
-- INSERT … ON CONFLICT DO UPDATE statement.

-- 1. Labels that differ only in spacing are the same pattern.
UPDATE public.user_error_patterns
SET pattern_text = regexp_replace(btrim(pattern_text), '\s+', ' ', 'g')
WHERE pattern_text <> regexp_replace(btrim(pattern_text), '\s+', ' ', 'g');

-- 2. Merge duplicates into the oldest row of each group.
WITH groups AS (
  SELECT user_id,
         vocabulary_id,
         pattern_text,
         (array_agg(id ORDER BY created_at, id))[1] AS keep_id,
         sum(count)::integer AS total,
         max(last_seen_at) AS seen
  FROM public.user_error_patterns
  GROUP BY user_id, vocabulary_id, pattern_text
  HAVING count(*) > 1
),
kept AS (
  UPDATE public.user_error_patterns p
  SET count = g.total, last_seen_at = g.seen
  FROM groups g
  WHERE p.id = g.keep_id
)
DELETE FROM public.user_error_patterns p
USING groups g
WHERE p.user_id = g.user_id
  AND p.vocabulary_id IS NOT DISTINCT FROM g.vocabulary_id
  AND p.pattern_text = g.pattern_text
  AND p.id <> g.keep_id;

-- 3. One row per user, word (or global) and label. Its leading columns also
--    serve the (user_id, vocabulary_id) lookups of the old index.
CREATE UNIQUE INDEX IF NOT EXISTS user_error_patterns_unique_idx
  ON public.user_error_patterns (user_id, vocabulary_id, pattern_text)
  NULLS NOT DISTINCT;

DROP INDEX IF EXISTS public.user_error_patterns_user_vocab_idx;

-- 4. Record the patterns of one answer: for each label, the word-specific row
--    (only when the word belongs to the caller — RLS hides other users'
--    words) and the global row, inserted or counted up.
--    SECURITY INVOKER: the table's RLS policies apply as usual.
CREATE OR REPLACE FUNCTION public.record_error_patterns(
  p_vocabulary_id uuid,
  p_patterns text[]
)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  INSERT INTO public.user_error_patterns AS p
    (user_id, vocabulary_id, pattern_text)
  SELECT auth.uid(), scope.vocabulary_id, label.text
  FROM (
    SELECT DISTINCT left(regexp_replace(btrim(raw), '\s+', ' ', 'g'), 200) AS text
    FROM unnest(p_patterns) AS raw
    LIMIT 10
  ) AS label
  CROSS JOIN (
    SELECT v.id AS vocabulary_id
    FROM public.vocabulary_items v
    WHERE v.id = p_vocabulary_id
    UNION ALL
    SELECT NULL::uuid
  ) AS scope
  WHERE label.text <> ''
  ON CONFLICT (user_id, vocabulary_id, pattern_text)
  DO UPDATE SET count = p.count + 1, last_seen_at = now();
$$;

REVOKE ALL ON FUNCTION public.record_error_patterns(uuid, text[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_error_patterns(uuid, text[])
  TO authenticated;
