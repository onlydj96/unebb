-- Migration: memory model v2 (docs/MEMORY_MODEL.md, MemoryService).
--
-- Applies the current review rules to stored memory states wherever the
-- stored data allows it:
--
-- 1. Recalled meanings graded as misses. Before 2026-11-16 a weak
--    translation could sink the combined score of a word whose meaning had
--    been recalled, and the word was reset as if forgotten. Only a recalled
--    meaning reaches the translation step, so a word whose latest review
--    (the one its memory state records) is a translation counts as
--    recalled once. If nothing but misses came before, its ease factor is
--    what the current rules give: 2.5, minus the grade-3 step of a recall
--    with a weak sentence (-0.14).
-- 2. Correct answers after a miss that left sm2_repetitions at 0 (client of
--    2026-11-20) count as recalled once.
-- 3. A miss before a word was ever recalled no longer lowers the ease
--    factor: words never recalled get the initial 2.5 back.
-- 4. memory_strength / recall_probability / stage hold the strength right
--    after the last review on the new scale (MemoryService.peakStrength):
--      last answer wrong (or never reviewed) → 0.0
--      interval 1–21 days                    → 0.70 … 0.80 (good)
--      interval 21 days–1 year               → 0.80 … 1.00 (strong)
--
-- The updated_at trigger bumps every rewritten row, so clients pick the new
-- values up through the regular delta sync.

-- 1. Recalled meanings graded as misses --------------------------------------
with latest as (
  select distinct on (vocabulary_id) vocabulary_id, question_type, reviewed_at
  from public.review_results
  order by vocabulary_id, reviewed_at desc
)
update public.memory_states m
set
  sm2_repetitions     = 1,
  sm2_interval        = 1,
  consecutive_correct = 1,
  correct_count       = m.correct_count + 1,
  incorrect_count     = greatest(m.incorrect_count - 1, 0),
  ease_factor         = case when m.correct_count = 0 then 2.36
                             else m.ease_factor end,
  next_review_at      = greatest(m.next_review_at,
                                 m.last_reviewed_at + interval '1 day')
from latest l
where l.vocabulary_id = m.vocabulary_id
  and l.question_type = 'translation'
  and m.consecutive_correct = 0
  and m.last_reviewed_at is not null
  -- The same review: history rows are best-effort, so a later miss may be
  -- missing from review_results.
  and abs(extract(epoch from (m.last_reviewed_at - l.reviewed_at))) < 300;

-- 2. Correct answers after a miss -------------------------------------------
update public.memory_states
set
  sm2_repetitions = 1,
  sm2_interval    = 1,
  next_review_at  = greatest(next_review_at,
                             last_reviewed_at + interval '1 day')
where sm2_repetitions = 0
  and consecutive_correct > 0
  and last_reviewed_at is not null;

-- 3. Ease factor of words never recalled -------------------------------------
update public.memory_states
set ease_factor = 2.5
where correct_count = 0
  and ease_factor <> 2.5;

-- 4. Stored strength on the new scale ----------------------------------------
with recomputed as (
  select
    id,
    case
      when consecutive_correct = 0 then 0.0::double precision
      when greatest(sm2_interval, 1) < 21 then
        0.70 + 0.10 * ln(greatest(sm2_interval, 1)::double precision)
                    / ln(21::double precision)
      else least(
        1.0::double precision,
        0.80 + 0.20 * ln(sm2_interval::double precision / 21)
                    / ln(365::double precision / 21)
      )
    end as strength
  from public.memory_states
  where review_count > 0
)
update public.memory_states m
set
  memory_strength    = r.strength,
  recall_probability = r.strength,
  stage = case
    when r.strength >= 0.80 then 1
    when r.strength >= 0.60 then 2
    when r.strength >= 0.30 then 3
    else 4
  end
from recomputed r
where m.id = r.id;
