-- book_clubs.created_by, club_books.created_by, and club_suggestions.suggested_by
-- all reference profiles(id) with no ON DELETE behavior specified (defaults to
-- NO ACTION), which blocks deleting a user's account entirely if they've ever
-- created a club, added a meeting, or suggested a book -- discovered while
-- cleaning up a test account during this session's QA. The right behavior is
-- to keep the club/meeting/suggestion (it's shared club history, not the
-- departing user's to take with them) and just drop the "who did this"
-- attribution to null.

alter table book_clubs drop constraint if exists book_clubs_created_by_fkey;
alter table book_clubs add constraint book_clubs_created_by_fkey
  foreign key (created_by) references profiles(id) on delete set null;

alter table club_books drop constraint if exists club_books_created_by_fkey;
alter table club_books add constraint club_books_created_by_fkey
  foreign key (created_by) references profiles(id) on delete set null;

alter table club_suggestions drop constraint if exists club_suggestions_suggested_by_fkey;
alter table club_suggestions add constraint club_suggestions_suggested_by_fkey
  foreign key (suggested_by) references profiles(id) on delete set null;
