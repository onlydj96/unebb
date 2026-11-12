-- Add 'skip' to answer_type check constraint
ALTER TABLE review_results DROP CONSTRAINT IF EXISTS review_results_answer_type_check;
ALTER TABLE review_results ADD CONSTRAINT review_results_answer_type_check
  CHECK (answer_type IN ('text', 'voice', 'skip'));
