-- Add pronunciation column to vocabulary_items
ALTER TABLE vocabulary_items
ADD COLUMN IF NOT EXISTS pronunciation TEXT;

COMMENT ON COLUMN vocabulary_items.pronunciation IS 'IPA phonetic transcription of the word';
