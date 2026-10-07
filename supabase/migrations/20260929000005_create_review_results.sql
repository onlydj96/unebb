-- Migration: create review_results table
-- Every recall attempt is stored permanently — this is the historical learning log.
-- Rows must NEVER be updated or deleted (append-only history).

create table if not exists public.review_results (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  session_id      uuid not null references public.review_sessions (id) on delete cascade,
  vocabulary_id   uuid not null references public.vocabulary_items (id) on delete cascade,

  answer_type     text not null check (answer_type in ('text', 'voice')),
  user_answer     text not null,

  -- AI evaluation scores (0.0 - 1.0)
  meaning_score   double precision not null,
  usage_score     double precision not null,
  example_score   double precision not null,
  grammar_score   double precision not null,
  overall_score   double precision not null,

  feedback        text not null,
  weak_point      text,

  previous_memory_strength  double precision not null,
  updated_memory_strength   double precision not null,

  reviewed_at     timestamptz not null default now(),

  -- Score range constraints
  constraint meaning_score_range check (meaning_score between 0.0 and 1.0),
  constraint usage_score_range check (usage_score between 0.0 and 1.0),
  constraint example_score_range check (example_score between 0.0 and 1.0),
  constraint grammar_score_range check (grammar_score between 0.0 and 1.0),
  constraint overall_score_range check (overall_score between 0.0 and 1.0),
  constraint prev_strength_range check (previous_memory_strength between 0.0 and 1.0),
  constraint updated_strength_range check (updated_memory_strength between 0.0 and 1.0)
);

create index if not exists review_results_user_id_idx
  on public.review_results (user_id);

create index if not exists review_results_vocabulary_idx
  on public.review_results (vocabulary_id, reviewed_at desc);

create index if not exists review_results_session_idx
  on public.review_results (session_id);

-- Row Level Security
alter table public.review_results enable row level security;

create policy "Users can read own results"
  on public.review_results for select
  using (auth.uid() = user_id);

create policy "Users can insert own results"
  on public.review_results for insert
  with check (auth.uid() = user_id);

-- No update or delete policies — history is immutable
