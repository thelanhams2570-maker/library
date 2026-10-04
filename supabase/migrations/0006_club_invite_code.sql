-- Adds a short, unguessable invite code to each club so a member can share a
-- single link ("…/?join=<code>") instead of asking the owner to add them
-- manually. club_books already has an update policy covering meeting edits
-- (migration 0003's "members can edit their club's books"), so no RLS change
-- is needed for that part of this release -- just the new column here.
--
-- Apply via the Supabase Dashboard SQL Editor (no CLI available).

alter table book_clubs add column if not exists invite_code text;

-- Backfill existing clubs with a random 8-character code (base36, collision
-- odds are negligible at this scale -- a handful of clubs for a 12-person beta).
update book_clubs set invite_code = substr(md5(random()::text || id::text), 1, 8)
where invite_code is null;

alter table book_clubs alter column invite_code set default substr(md5(random()::text || gen_random_uuid()::text), 1, 8);
alter table book_clubs add constraint book_clubs_invite_code_key unique (invite_code);

-- Invite codes must be readable by anyone with the link, even before they've
-- joined -- the existing "any signed-in user can browse clubs" select policy
-- (migration 0003) already covers this since invite_code is just a column on
-- the same row, no new policy needed.
