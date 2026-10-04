-- Run once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: each statement either uses IF NOT EXISTS or drops its
-- own policy first. Nothing here touches existing data except the one
-- UPDATE that promotes an admin per club (step 2).
--
-- Confirmed from your actual schema: club_members.role only allows
-- 'member' or 'owner' (not 'admin') - every statement below uses
-- 'owner' as the admin role value to match.

-- 1. New column for the "Manage club" cadence setting.
alter table book_clubs add column if not exists meeting_cadence jsonb;

-- 2. Make sure every existing club has at least one admin ('owner').
--    club_members has no join-timestamp column, so there's no way to
--    pick the actual earliest joiner - this deterministically promotes
--    one member (by user_id order) per club that currently has no
--    owner at all. If you want a *specific* person instead, just run:
--      update club_members set role = 'owner'
--      where club_id = '<club id>' and user_id = '<their user id>';
update club_members cm
set role = 'owner'
where (cm.club_id, cm.user_id) in (
  select distinct on (club_id) club_id, user_id
  from club_members
  order by club_id, user_id
)
and not exists (
  select 1 from club_members cm2
  where cm2.club_id = cm.club_id and cm2.role = 'owner'
);

-- 3. Let any signed-in user create a club (Settings → Book Club
--    Memberships → Create a club).
drop policy if exists "authenticated users can create clubs" on book_clubs;
create policy "authenticated users can create clubs"
on book_clubs for insert
to authenticated
with check (true);

-- 4. Only a club's owner(s) can change its settings (name, cadence).
drop policy if exists "club admins can update their club" on book_clubs;
create policy "club admins can update their club"
on book_clubs for update
to authenticated
using (exists (
  select 1 from club_members
  where club_members.club_id = book_clubs.id
  and club_members.user_id = auth.uid()
  and club_members.role = 'owner'
));

-- 5. Meetings: only owners can create, edit, or delete them. (If you
--    already have a broader policy covering these actions, these are
--    additive - Postgres OR's multiple permissive policies together.)
drop policy if exists "club admins can insert meetings" on club_books;
create policy "club admins can insert meetings"
on club_books for insert
to authenticated
with check (exists (
  select 1 from club_members
  where club_members.club_id = club_books.club_id
  and club_members.user_id = auth.uid()
  and club_members.role = 'owner'
));

drop policy if exists "club admins can update meetings" on club_books;
create policy "club admins can update meetings"
on club_books for update
to authenticated
using (exists (
  select 1 from club_members
  where club_members.club_id = club_books.club_id
  and club_members.user_id = auth.uid()
  and club_members.role = 'owner'
));

drop policy if exists "club admins can delete meetings" on club_books;
create policy "club admins can delete meetings"
on club_books for delete
to authenticated
using (exists (
  select 1 from club_members
  where club_members.club_id = club_books.club_id
  and club_members.user_id = auth.uid()
  and club_members.role = 'owner'
));

-- 6. Owner can delete their own club. No UI button calls this yet (the
--    app has no "Delete club" feature) - this just means you can clean
--    up a club via the Supabase table editor without it silently
--    no-op'ing under RLS, the way the leftover "QA Verify Club" test
--    row did before this policy existed.
drop policy if exists "club owners can delete their club" on book_clubs;
create policy "club owners can delete their club"
on book_clubs for delete
to authenticated
using (exists (
  select 1 from club_members
  where club_members.club_id = book_clubs.id
  and club_members.user_id = auth.uid()
  and club_members.role = 'owner'
));
