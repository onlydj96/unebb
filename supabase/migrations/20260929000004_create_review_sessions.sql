-- Migration: create review_sessions table
-- Represents one learning session. completed_at is null until the session ends.

create table if not exists public.review_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,

  started_at      timestamptz not null default now(),
  completed_at    timestamptz,

  total_items     integer not null default 0,
  completed_items integer not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists review_sessions_user_id_idx
  on public.review_sessions (user_id);

create trigger review_sessions_set_updated_at
  before update on public.review_sessions
  for each row execute procedure public.set_updated_at();

-- Row Level Security
alter table public.review_sessions enable row level security;

create policy "Users can read own sessions"
  on public.review_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert own sessions"
  on public.review_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own sessions"
  on public.review_sessions for update
  using (auth.uid() = user_id);
