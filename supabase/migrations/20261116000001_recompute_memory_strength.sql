-- Migration: recompute memory_strength with the streak-aware log scale.
--
-- The old display strength was sm2_interval / 60, so a word answered
-- correctly three times in a row (interval ~16 days) still showed 0.27,
-- "critical". MemoryService.strengthFor now maps:
--   sm2_repetitions = 0 → 0.0
--   otherwise           → 0.30 + 0.70 * ln(interval) / ln(60), capped at 1.0
--
-- Only rows with a streak are rewritten. Rows with sm2_repetitions = 0 are
-- either unreviewed or last answered wrong (both already "critical"), or
-- were reviewed before SM-2 existed and keep their legacy strength until
-- the next review.
--
-- The updated_at trigger bumps every rewritten row, so clients pick the
-- new values up through the regular delta sync.

with recomputed as (
  select
    id,
    least(
      1.0,
      0.30 + 0.70 * ln(greatest(sm2_interval, 1)::double precision) / ln(60.0)
    ) as strength
  from public.memory_states
  where sm2_repetitions > 0
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
