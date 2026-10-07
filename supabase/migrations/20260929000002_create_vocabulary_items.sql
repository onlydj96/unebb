-- Migration: create vocabulary_items table
-- Stores vocabulary registered by users. AI-generated fields are nullable
-- and populated by the generate-explanation Edge Function after word creation.

create table if not exists public.vocabulary_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,

  word        text not null,
  language    text not null,

  -- AI-generated fields (populated asynchronously after word creation)
  definition       text,
  explanation      text,
  usage            text,
  examples         text[],
  synonyms         text[],
  collocations     text[],
  common_mistakes  text[],

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Indexes
create index if not exists vocabulary_items_user_id_idx
  on public.vocabulary_items (user_id);

create unique index if not exists vocabulary_items_user_word_idx
  on public.vocabulary_items (user_id, lower(word), language);

-- Auto-update updated_at
create trigger vocabulary_items_set_updated_at
  before update on public.vocabulary_items
  for each row execute procedure public.set_updated_at();

-- Row Level Security
alter table public.vocabulary_items enable row level security;

create policy "Users can read own vocabulary"
  on public.vocabulary_items for select
  using (auth.uid() = user_id);

create policy "Users can insert own vocabulary"
  on public.vocabulary_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update own vocabulary"
  on public.vocabulary_items for update
  using (auth.uid() = user_id);

create policy "Users can delete own vocabulary"
  on public.vocabulary_items for delete
  using (auth.uid() = user_id);
