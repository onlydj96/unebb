-- Migration: update question_type constraint on review_results
-- to accommodate the new 2-step flash card flow.
-- 'meaning' is the new value for step-1 (meaning recall) results.
-- Keep 'free_recall' and 'translation' so existing rows remain valid.

ALTER TABLE public.review_results
  DROP CONSTRAINT IF EXISTS review_results_question_type_check;

ALTER TABLE public.review_results
  ADD CONSTRAINT review_results_question_type_check
  CHECK (question_type IN ('free_recall', 'translation', 'meaning'));
