-- Migration: Add SM-2 spaced repetition fields to memory_states
-- and question_type / question_context to review_results.

-- SM-2 fields on memory_states
ALTER TABLE public.memory_states
  ADD COLUMN IF NOT EXISTS ease_factor DOUBLE PRECISION NOT NULL DEFAULT 2.5,
  ADD COLUMN IF NOT EXISTS sm2_interval INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS sm2_repetitions INTEGER NOT NULL DEFAULT 0;

-- ease_factor must be >= 1.3 (SM-2 lower bound)
ALTER TABLE public.memory_states
  ADD CONSTRAINT IF NOT EXISTS ease_factor_min
  CHECK (ease_factor >= 1.3);

-- Question type tracking on review_results
ALTER TABLE public.review_results
  ADD COLUMN IF NOT EXISTS question_type TEXT NOT NULL DEFAULT 'free_recall',
  ADD COLUMN IF NOT EXISTS question_context TEXT;

-- question_type must be one of the supported types
ALTER TABLE public.review_results
  ADD CONSTRAINT IF NOT EXISTS question_type_valid
  CHECK (question_type IN ('free_recall', 'translation'));
