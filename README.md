# My Books

A personal book tracker — library, series gap detection, authors, reports,
AI recommendations, and book club history. Runs as a static site hosted on
GitHub Pages, with data stored in a private Supabase database so it updates
in real time across every device you sign in on.

## How it works

- `index.html` is the whole app (no build step, no framework).
- Data lives in a Supabase Postgres table (`kv_store`), one row per data
  type (`books`, `goal`, `series_cache`, `bookclub`), scoped to your account
  by Row Level Security. Every change saves to `localStorage` instantly and
  syncs to Supabase in the background; other signed-in tabs/devices get the
  update live via Supabase Realtime.
- The AI features (series lookup, recommendations, genre backfill) call a
  Supabase Edge Function (`supabase/functions/ai-proxy`), which holds your
  Anthropic API key server-side and forwards the request. The key never
  touches the browser.

## One-time setup

### 0. Bring your existing data across

Before doing anything else, open your existing Book Tracker artifact, go to
**Import → Export JSON backup**, and save `my-books-backup.json` somewhere.
You'll restore it into the new site in step 8 below (this only migrates the
books list — re-set your reading goal afterwards if you had one).

### 1. Create a free Supabase project

Go to [supabase.com](https://supabase.com) → New project. Pick any name and
region, and save the database password somewhere safe (you likely won't need
it again).

### 2. Run the database migration

In the Supabase dashboard: **SQL Editor → New query**, paste the contents of
[`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql), and
run it. This creates the `kv_store` table with security rules so only your
account can ever read or write your rows.

### 3. Create your account

**Authentication → Users → Add user**. Use your own email and choose a
password (tick "Auto confirm user" if offered, so you can sign in right
away). This app is single-user — there's no public sign-up page — so this is
the only account that will ever exist.

### 4. Get your API keys

**Settings → API**. Copy the **Project URL** and the **anon public key**.
Open `config.js` in this repo and paste them in:

```js
const SUPABASE_URL = 'https://your-project-ref.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-public-key';
```

These are safe to commit — they're public by design; your data is protected
by the Row Level Security policy from step 2, not by secrecy of this key.

### 5. Get an Anthropic API key

Create one at [console.anthropic.com](https://console.anthropic.com) →
**API Keys**. Usage for this app is small (a handful of short requests per
session) — expect at most a few dollars a month even with regular use.

### 6. Deploy the AI proxy function

In the Supabase dashboard: **Edge Functions → Create a new function**, name
it `ai-proxy`, and paste in the contents of
[`supabase/functions/ai-proxy/index.ts`](supabase/functions/ai-proxy/index.ts).
Deploy it.

Then go to **Edge Functions → Secrets** (or **Project Settings → Edge
Functions**) and add:

```
ANTHROPIC_API_KEY = sk-ant-...
```

If you'd rather use the CLI instead of the dashboard:

```
supabase login
supabase link --project-ref your-project-ref
supabase functions deploy ai-proxy
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

### 7. Commit and push

```
git add config.js
git commit -m "Add Supabase config"
git push
```

### 8. Turn on GitHub Pages

On GitHub: this repo → **Settings → Pages** → Source: **Deploy from a
branch** → Branch: **main**, folder **/ (root)** → Save. GitHub will give you
a URL like `https://thelanhams2570-maker.github.io/library/` within a
minute or two, and it will redeploy automatically every time you push to
`main`.

### 9. Sign in and restore your data

Visit your new site, sign in with the account from step 3, go to
**Import → Restore from JSON**, and pick the `my-books-backup.json` file
from step 0. Your library is now live and synced.

## Day to day

- Open the site on your phone or laptop — sign in once, and changes on one
  device appear on the other within a second or two.
- **Settings → Sign out** if you ever need to switch accounts.
- Keep exporting a JSON backup occasionally as a safety net — Supabase's
  free tier is generous, but backups are free insurance.

## Costs

- Supabase free tier: 500MB database, 50k monthly active users, 2GB file
  storage — this app uses a tiny fraction of that.
- GitHub Pages: free for public repos.
- Anthropic API: pay-as-you-go, billed to your own account; only used when
  you click an AI feature (series lookup, recommendations, genre backfill,
  suggest genre).
