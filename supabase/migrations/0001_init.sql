-- Book Tracker: single key-value table holding the app's existing localStorage-shaped
-- data (books array, reading goal, series cache, book club meetings) per user.
create table if not exists kv_store (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table kv_store enable row level security;

create policy "Users manage their own data"
  on kv_store
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Enable realtime change broadcasts so other signed-in devices update live.
alter publication supabase_realtime add table kv_store;
