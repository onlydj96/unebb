-- Migration: create memory_states table
-- One row per vocabulary item per user — represents CURRENT memory state.
-- recall_probability mirrors memory_strength for MVP; reserved for future
-- time-decayed Ebbinghaus calculation (DECISION-2).

create table if not exists public.memory_states (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  vocabulary_id   uuid not null references public.vocabulary_items (id) on delete cascade,

  memory_strength   double precision not null default 0.0,
  recall_probability double precision not null default 0.0,
  stage             integer not null default 4,

  last_reviewed_at  timestamptz,
  next_review_at    timestamptz not null default now(),

  review_count      integer not null default 0,
  correct_count     integer not null default 0,
  incorrect_count   integer not null default 0,
  consecutive_correct integer not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- Each vocabulary item has exactly one memory state per user
  unique (vocabulary_id, user_id),

  -- Strength and probability must be in [0.0, 1.0]
  constraint memory_strength_range check (memory_strength between 0.0 and 1.0),
  constraint recall_probability_range check (recall_probability between 0.0 and 1.0),
  -- Stage must be 1-4
  constraint stage_range check (stage between 1 and 4)
);

create index if not exists memory_states_user_id_idx
  on public.memory_states (user_id);

-- Regular index — planner uses this for "where next_review_at <= now()" queries.
-- Partial index with now() is not allowed (now() is STABLE, not IMMUTABLE).
create index if not exists memory_states_next_review_idx
  on public.memory_states (user_id, next_review_at);

-- Auto-update updated_at
create trigger memory_states_set_updated_at
  before update on public.memory_states
  for each row execute procedure public.set_updated_at();

-- Row Level Security
alter table public.memory_states enable row level security;

create policy "Users can read own memory states"
  on public.memory_states for select
  using (auth.uid() = user_id);

create policy "Users can insert own memory states"
  on public.memory_states for insert
  with check (auth.uid() = user_id);

create policy "Users can update own memory states"
  on public.memory_states for update
  using (auth.uid() = user_id);
