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

-- 1b. New column for the club's "About this club" landing-page text
--     (free text, admin-editable - what the club is, how to join, etc).
alter table book_clubs add column if not exists description text;

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

-- 7. New columns for the Manage Club page: join type (invite-only vs
--    public, so the "Join" list only ever shows clubs an admin has
--    explicitly opened up - every existing club defaults to invite-only,
--    nothing becomes publicly joinable on its own) and genre tags.
alter table book_clubs add column if not exists join_type text default 'invite';
alter table book_clubs drop constraint if exists book_clubs_join_type_check;
alter table book_clubs add constraint book_clubs_join_type_check check (join_type in ('invite','public'));
alter table book_clubs add column if not exists genres text[] default '{}';

-- 8. New join-timestamp column for club_members, used for the "Join
--    date" column on the Manage Club page. Existing rows have no real
--    historical join date to backfill, so they'll show today's date
--    the first time this runs; new joins get a real timestamp from
--    here on.
alter table club_members add column if not exists joined_at timestamptz default now();

-- 9. Let a club owner remove ANOTHER member from the club (distinct
--    from the existing self-service "leave club" delete, which every
--    member already has regardless of RLS). Needed for the Manage
--    Club page's per-member remove button.
drop policy if exists "club admins can remove members" on club_members;
create policy "club admins can remove members"
on club_members for delete
to authenticated
using (exists (
  select 1 from club_members cm2
  where cm2.club_id = club_members.club_id
  and cm2.user_id = auth.uid()
  and cm2.role = 'owner'
));

-- 10. Marketing preference columns for Settings → Preferences. All
--     default false (opt-in, GDPR-style) - nothing sends emails yet,
--     this just saves the preference for when that's built.
alter table profiles add column if not exists marketing_product_updates boolean default false;
alter table profiles add column if not exists marketing_content_alerts boolean default false;
alter table profiles add column if not exists marketing_activity_reminders boolean default false;

-- 11. One-off: a standalone test club so you can see the member (not
--     admin) experience without touching your existing No Shelf
--     Control admin membership. Safe to re-run - the WHERE NOT EXISTS
--     guards skip it if it's already there.
do $$
declare
  v_club_id uuid;
  v_user_id uuid;
begin
  select id into v_user_id from auth.users where email = 'thelanhams2570@gmail.com';
  if v_user_id is null then
    raise notice 'No auth user found for that email - skipping test club setup.';
    return;
  end if;
  select id into v_club_id from book_clubs where name = 'Test Club (Member)';
  if v_club_id is null then
    insert into book_clubs (name, invite_code, join_type)
    values ('Test Club (Member)', substr(md5(random()::text), 1, 10), 'invite')
    returning id into v_club_id;
  end if;
  if not exists (
    select 1 from club_members where club_id = v_club_id and user_id = v_user_id
  ) then
    insert into club_members (club_id, user_id, role) values (v_club_id, v_user_id, 'member');
  end if;
end $$;
