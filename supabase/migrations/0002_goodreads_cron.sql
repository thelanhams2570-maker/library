-- Schedules the goodreads-sync edge function to run once a day.
-- Uses pg_cron (scheduler) + pg_net (makes HTTP calls from inside Postgres).
-- The bearer token below is the project's anon public key -- safe to be here,
-- it's not a secret (see config.js comments for why).

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'goodreads-daily-sync',
  '0 17 * * *', -- 17:00 UTC daily -- adjust the hour to suit you
  $$
  select net.http_post(
    url := 'https://anxvjvhaszczjdchrfaj.supabase.co/functions/v1/goodreads-sync',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFueHZqdmhhc3pjempkY2hyZmFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0NDU0ODksImV4cCI6MjEwNjAyMTQ4OX0.JXefyReJKwnXuXh36wxDE7PlhWFYjuaCR4jyEu9ACfU',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- To check past runs: select * from cron.job_run_details order by start_time desc limit 20;
-- To stop it: select cron.unschedule('goodreads-daily-sync');
