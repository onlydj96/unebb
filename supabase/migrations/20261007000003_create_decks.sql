-- Migration: create decks table
-- Allows users to organize vocabulary into themed decks (e.g., TOEIC, Japanese, etc.)

create table if not exists public.decks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,

  name        text not null,
  description text,
  language    text not null,  -- Target language for this deck

  -- Statistics (denormalized for performance)
  word_count  int not null default 0,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Indexes
create index if not exists decks_user_id_idx
  on public.decks (user_id);

create unique index if not exists decks_user_name_idx
  on public.decks (user_id, lower(name));

-- Auto-update updated_at
create trigger decks_set_updated_at
  before update on public.decks
  for each row execute procedure public.set_updated_at();

-- Row Level Security
alter table public.decks enable row level security;

create policy "Users can read own decks"
  on public.decks for select
  using (auth.uid() = user_id);

create policy "Users can insert own decks"
  on public.decks for insert
  with check (auth.uid() = user_id);

create policy "Users can update own decks"
  on public.decks for update
  using (auth.uid() = user_id);

create policy "Users can delete own decks"
  on public.decks for delete
  using (auth.uid() = user_id);

-- Add deck_id to vocabulary_items
alter table public.vocabulary_items
  add column deck_id uuid references public.decks (id) on delete cascade;

create index if not exists vocabulary_items_deck_id_idx
  on public.vocabulary_items (deck_id);

-- Function to update deck word count
create or replace function public.update_deck_word_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.decks set word_count = word_count + 1 where id = NEW.deck_id;
    return NEW;
  elsif TG_OP = 'DELETE' then
    update public.decks set word_count = word_count - 1 where id = OLD.deck_id;
    return OLD;
  elsif TG_OP = 'UPDATE' and OLD.deck_id is distinct from NEW.deck_id then
    if OLD.deck_id is not null then
      update public.decks set word_count = word_count - 1 where id = OLD.deck_id;
    end if;
    if NEW.deck_id is not null then
      update public.decks set word_count = word_count + 1 where id = NEW.deck_id;
    end if;
    return NEW;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger vocabulary_items_deck_count_trigger
  after insert or delete or update of deck_id on public.vocabulary_items
  for each row execute procedure public.update_deck_word_count();
