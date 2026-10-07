-- Migration: create user_error_patterns table
-- Tracks per-word and global grammar error patterns for context-aware AI feedback.
-- NULL vocabulary_id = global pattern; non-NULL = word-specific pattern.

CREATE TABLE public.user_error_patterns (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vocabulary_id  UUID REFERENCES public.vocabulary_items(id) ON DELETE CASCADE,
  pattern_text   TEXT NOT NULL,
  count          INTEGER NOT NULL DEFAULT 1,
  last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Composite index for the two primary access patterns:
--   1. All global patterns for a user  (vocabulary_id IS NULL)
--   2. All word-specific patterns      (vocabulary_id = ?)
CREATE INDEX user_error_patterns_user_vocab_idx
  ON public.user_error_patterns (user_id, vocabulary_id);

-- Row Level Security
ALTER TABLE public.user_error_patterns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own error patterns"
  ON public.user_error_patterns FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own error patterns"
  ON public.user_error_patterns FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own error patterns"
  ON public.user_error_patterns FOR UPDATE
  USING (auth.uid() = user_id);
