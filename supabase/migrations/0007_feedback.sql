-- A simple feedback inbox: any signed-in user can submit a note (bug report,
-- suggestion, anything), read by the owner directly via the Table Editor /
-- SQL Editor -- there's no in-app reader, this is a one-way mailbox by
-- design for the beta.
--
-- Apply via the Supabase Dashboard SQL Editor (no CLI available).

create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  message text not null,
  page text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_feedback_created on feedback(created_at desc);

alter table feedback enable row level security;

create policy "a signed-in user can submit feedback"
  on feedback for insert
  with check (auth.uid() = user_id);

-- Deliberately no select policy: only the project owner (via the Dashboard,
-- which bypasses RLS) reads submissions. Nobody else, including the
-- submitter, can read feedback rows back through the client.
