-- Adds location/time to shared club meetings, per-member RSVPs, and a shared
-- suggestion pool for the club (replacing the old private-blob backlog, which
-- was invisible between members -- defeats the point of a shared "suggested
-- multiple times" signal).
--
-- Apply via the Supabase Dashboard SQL Editor (no CLI available).

alter table club_books add column if not exists location text not null default '';
alter table club_books add column if not exists start_time time;

-- ───────── club_meeting_rsvp ─────────
create table if not exists club_meeting_rsvp (
  id uuid primary key default gen_random_uuid(),
  club_book_id uuid not null references club_books(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'going' check (status in ('going','maybe','not_going')),
  updated_at timestamptz not null default now(),
  unique (club_book_id, user_id)
);
create index if not exists idx_rsvp_book on club_meeting_rsvp(club_book_id);
create index if not exists idx_rsvp_user on club_meeting_rsvp(user_id);

alter table club_meeting_rsvp enable row level security;

create policy "members can read all RSVPs for their club's meetings"
  on club_meeting_rsvp for select
  using (exists (
    select 1 from club_books cb
    where cb.id = club_meeting_rsvp.club_book_id
      and public.is_club_member(cb.club_id, auth.uid())
  ));

create policy "a user can insert only their own RSVP"
  on club_meeting_rsvp for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from club_books cb
      where cb.id = club_meeting_rsvp.club_book_id
        and public.is_club_member(cb.club_id, auth.uid())
    )
  );

create policy "a user can update only their own RSVP"
  on club_meeting_rsvp for update
  using (auth.uid() = user_id);

-- ───────── club_suggestions ─────────
-- A shared pool of "books someone suggested but wasn't picked yet". Repeated
-- suggestions of the same title bump times_suggested (client checks for an
-- existing match first, same titlesMatch()/normTitle() logic index.html
-- already uses for library dedup) instead of creating duplicate rows.
-- scheduled_club_book_id is set once a suggestion becomes a real meeting, so
-- the active pool can filter it out while keeping the suggestion's history.
create table if not exists club_suggestions (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references book_clubs(id) on delete cascade,
  title text not null,
  author text not null default '',
  suggested_by uuid references profiles(id),
  notes text not null default '',
  times_suggested integer not null default 1,
  scheduled_club_book_id uuid references club_books(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_suggestions_club on club_suggestions(club_id);

alter table club_suggestions enable row level security;

create policy "members can read their club's suggestions"
  on club_suggestions for select
  using (public.is_club_member(club_id, auth.uid()));

create policy "members can add suggestions to their club"
  on club_suggestions for insert
  with check (public.is_club_member(club_id, auth.uid()));

create policy "members can update their club's suggestions"
  on club_suggestions for update
  using (public.is_club_member(club_id, auth.uid()));

alter publication supabase_realtime add table club_meeting_rsvp, club_suggestions;
