-- Book Club sharing: lets multiple Supabase accounts share one book club's
-- meeting schedule while each member tracks their own reading status/rating
-- independently. Everything else (the personal `books` library) stays exactly
-- as it is today, in kv_store, private per account -- this migration only
-- adds the pieces needed for cross-account sharing.
--
-- Apply via the Supabase Dashboard SQL Editor (no CLI available in this
-- environment) -- paste this whole file and run it once.

create extension if not exists pgcrypto;

-- ───────── profiles ─────────
-- One row per auth user: first/last name + an optional avatar photo (null for
-- now -- the app falls back to an initials avatar until a real photo exists).
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name  text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- Trusted small beta: any signed-in user can see any other signed-in user's
-- name (needed for the club roster / "who's read this" lists). Revisit before
-- any wider/public signup -- this is intentionally permissive for now.
create policy "profiles readable by any signed-in user"
  on profiles for select
  using (auth.role() = 'authenticated');

create policy "users insert their own profile"
  on profiles for insert
  with check (auth.uid() = id);

create policy "users update their own profile"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a blank profile row the instant a new auth user exists, so
-- every later foreign key into profiles(id) is guaranteed to resolve even if
-- the client-side signup flow never gets to its own insert/update call.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────── book_clubs ─────────
create table if not exists book_clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

alter table book_clubs enable row level security;

create policy "any signed-in user can browse clubs"
  on book_clubs for select
  using (auth.role() = 'authenticated');

create policy "any signed-in user can create a club"
  on book_clubs for insert
  with check (auth.uid() = created_by);

create policy "creator can rename their club"
  on book_clubs for update
  using (auth.uid() = created_by);

create policy "creator can delete their club"
  on book_clubs for delete
  using (auth.uid() = created_by);

-- ───────── club_members ─────────
-- Self-serve join/leave: a user can add or remove only their own membership row.
create table if not exists club_members (
  club_id uuid not null references book_clubs(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);
create index if not exists idx_club_members_club on club_members(club_id);
create index if not exists idx_club_members_user on club_members(user_id);

alter table club_members enable row level security;

-- Membership-check helper, used by every policy below that needs to ask "is
-- this user in this club?". MUST be security definer: a plain
-- `exists (select 1 from club_members ...)` inside club_members' own select
-- policy recurses into itself (Postgres re-applies the table's RLS to the
-- subquery's own scan), causing "infinite recursion detected in policy for
-- relation club_members". Running as security definer bypasses RLS for this
-- one well-scoped check instead.
create or replace function public.is_club_member(p_club_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(select 1 from club_members where club_id = p_club_id and user_id = p_user_id);
$$;

create policy "members can see co-members of clubs they're in"
  on club_members for select
  using (public.is_club_member(club_id, auth.uid()));

create policy "a user can join a club"
  on club_members for insert
  with check (auth.uid() = user_id);

create policy "a user can leave a club"
  on club_members for delete
  using (auth.uid() = user_id);

-- ───────── club_books ─────────
-- The shared canonical meeting/book catalog for a club -- replaces the old
-- per-user BC_SEED-seeded meetings blob with one row every member reads.
create table if not exists club_books (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references book_clubs(id) on delete cascade,
  legacy_id text unique, -- old BC_SEED id, e.g. 'nsc7' -- one-time migration aid only
  meeting_name text not null,
  meeting_date date,
  book_title text not null,
  book_author text not null,
  series text not null default '',
  series_number text not null default '',
  discussion_notes text not null default '',
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_club_books_club on club_books(club_id);

alter table club_books enable row level security;

create policy "members can read their club's books"
  on club_books for select
  using (public.is_club_member(club_id, auth.uid()));

create policy "members can add their club's books"
  on club_books for insert
  with check (public.is_club_member(club_id, auth.uid()));

create policy "members can edit their club's books"
  on club_books for update
  using (public.is_club_member(club_id, auth.uid()));

-- ───────── club_book_engagement ─────────
-- Per-member, per-book: each person's own status/rating/notes, independent of
-- everyone else in the club. This is the row that makes "who's read this" and
-- "average rating" possible across accounts.
create table if not exists club_book_engagement (
  id uuid primary key default gen_random_uuid(),
  club_book_id uuid not null references club_books(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'tbr' check (status in ('tbr','reading','read','dnf')),
  rating smallint check (rating is null or rating between 0 and 5),
  notes text not null default '',
  date_read date,
  -- Optional link to a row inside THIS user's own private books[] array in
  -- kv_store. Can't be a real foreign key (that's a JSONB array element, not
  -- a table row) -- validated client-side only, and tolerated-if-stale on
  -- read, the same way the app already tolerates a stale meeting.bookId.
  personal_book_id text,
  updated_at timestamptz not null default now(),
  unique (club_book_id, user_id)
);
create index if not exists idx_engagement_book on club_book_engagement(club_book_id);
create index if not exists idx_engagement_user on club_book_engagement(user_id);

alter table club_book_engagement enable row level security;

create policy "members can read all engagement for their club's books"
  on club_book_engagement for select
  using (exists (
    select 1 from club_books cb
    where cb.id = club_book_engagement.club_book_id
      and public.is_club_member(cb.club_id, auth.uid())
  ));

create policy "a user can insert only their own engagement row"
  on club_book_engagement for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from club_books cb
      where cb.id = club_book_engagement.club_book_id
        and public.is_club_member(cb.club_id, auth.uid())
    )
  );

create policy "a user can update only their own engagement row"
  on club_book_engagement for update
  using (auth.uid() = user_id);

-- Enable realtime change broadcasts, matching kv_store's existing pattern.
alter publication supabase_realtime add table profiles, book_clubs, club_members, club_books, club_book_engagement;
