-- Migration: normalize the question_type CHECK constraint on review_results.
--
-- 20261006000001 created the constraint as `question_type_valid`
-- ('free_recall', 'translation'). 20261007000002 tried to widen it but dropped
-- `review_results_question_type_check` — a name that did not exist — and added
-- a second constraint. Both constraints must pass, so:
--   * 'meaning'   (failed meaning step) was rejected by question_type_valid
--   * 'knowledge' ("I don't know this word") was rejected by both
-- The app now treats history inserts as best-effort, but the rows were lost.
--
-- Idempotent: safe whether or not the old constraints still exist.

ALTER TABLE public.review_results
  DROP CONSTRAINT IF EXISTS question_type_valid;

ALTER TABLE public.review_results
  DROP CONSTRAINT IF EXISTS review_results_question_type_check;

ALTER TABLE public.review_results
  ADD CONSTRAINT review_results_question_type_check
  CHECK (question_type IN ('free_recall', 'translation', 'meaning', 'knowledge'));

-- "I don't know" results are stored with answer_type 'skip'
-- (20261012000001); re-assert it in case that migration was not applied.
ALTER TABLE public.review_results
  DROP CONSTRAINT IF EXISTS review_results_answer_type_check;

ALTER TABLE public.review_results
  ADD CONSTRAINT review_results_answer_type_check
  CHECK (answer_type IN ('text', 'voice', 'skip'));
