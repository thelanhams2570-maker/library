// Supabase Edge Function: polls GoodReads' public per-shelf RSS feeds (no login
// needed) and upserts new/changed books straight into your kv_store 'books' row.
// Meant to be triggered on a schedule (see supabase/migrations/0002_goodreads_cron.sql),
// not called from the browser.
//
// Secrets used:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY -- auto-provided by Supabase for every function
//   GOODREADS_TARGET_USER_ID -- the auth.users.id (uuid) whose kv_store row to update.
//                               Set this one yourself: Edge Functions -> Secrets.

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TARGET_USER_ID = Deno.env.get("GOODREADS_TARGET_USER_ID");

// Public GoodReads user id -- not sensitive, safe to hardcode.
const GOODREADS_USER_ID = "47413800";
const SHELVES: { shelf: string; status: string }[] = [
  { shelf: "read", status: "read" },
  { shelf: "currently-reading", status: "reading" },
];

const STATUS_PRI: Record<string, number> = { read: 5, reading: 4, tbr: 3, owned: 3, want: 3, wishlist: 3, dnf: 0 };

function tag(xml: string, name: string): string {
  const re = new RegExp(`<${name}>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${name}>`);
  const m = xml.match(re);
  return m ? m[1].trim() : "";
}

function normTitle(t: string): string {
  return String(t || "").toLowerCase().trim().replace(/\s*\([^)]*\)\s*$/, "").trim();
}

function titlesMatch(t1: string, t2: string): boolean {
  const a = normTitle(t1), b = normTitle(t2);
  if (a === b) return true;
  const [s, l] = a.length <= b.length ? [a, b] : [b, a];
  if (!l.startsWith(s)) return false;
  const nc = l[s.length];
  return nc === ":" || nc === "(" || (nc === " " && l[s.length + 1] === "-");
}

function parseItems(xml: string): string[] {
  const items: string[] = [];
  const re = /<item>([\s\S]*?)<\/item>/g;
  let m;
  while ((m = re.exec(xml))) items.push(m[1]);
  return items;
}

async function fetchShelf(shelf: string) {
  const url = `https://www.goodreads.com/review/list_rss/${GOODREADS_USER_ID}?shelf=${shelf}`;
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (compatible; BookTrackerSync/1.0)" } });
  if (!res.ok) throw new Error(`GoodReads feed error for shelf ${shelf}: ${res.status}`);
  const xml = await res.text();
  return parseItems(xml);
}

serve(async () => {
  try {
    if (!TARGET_USER_ID) throw new Error("GOODREADS_TARGET_USER_ID secret is not set");

    // 1. Pull current books row.
    const getRes = await fetch(
      `${SUPABASE_URL}/rest/v1/kv_store?user_id=eq.${TARGET_USER_ID}&key=eq.books&select=value`,
      { headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` } },
    );
    if (!getRes.ok) throw new Error(`Failed to read kv_store: ${await getRes.text()}`);
    const rows = await getRes.json();
    const books: any[] = (rows[0]?.value as any[]) || [];

    let added = 0, updated = 0;

    for (const { shelf, status } of SHELVES) {
      let items: string[];
      try {
        items = await fetchShelf(shelf);
      } catch (e) {
        console.error(String(e));
        continue;
      }

      for (const item of items) {
        const rawTitle = tag(item, "title");
        const author = tag(item, "author_name");
        if (!rawTitle || !author) continue;

        const sm = rawTitle.match(/\(([^,]+),\s*#?([0-9.]+)\)\s*$/);
        const series = sm ? sm[1].trim() : "";
        const seriesNumber = sm ? sm[2] : "";
        const title = rawTitle.replace(/\s*\([^)]+\)\s*$/, "").trim();

        const isbn = tag(item, "isbn");
        const userRating = parseInt(tag(item, "user_rating")) || 0;
        const avgRating = parseFloat(tag(item, "average_rating")) || 0;
        const readAtRaw = tag(item, "user_read_at");
        const dateRead = readAtRaw ? new Date(readAtRaw).toISOString().slice(0, 7) : "";
        const coverUrl = tag(item, "book_medium_image_url");

        const authorNorm = author.trim().toLowerCase();
        const existing = books.find(
          (b) => (b.author || "").trim().toLowerCase() === authorNorm && titlesMatch(b.title, title),
        );

        if (existing) {
          let changed = false;
          if ((STATUS_PRI[status] || 0) > (STATUS_PRI[existing.status] || 0)) { existing.status = status; changed = true; }
          if (userRating && (!existing.rating || userRating > existing.rating)) { existing.rating = userRating; changed = true; }
          if (avgRating && !existing.grRating) { existing.grRating = avgRating; changed = true; }
          if (dateRead && !existing.dateRead) { existing.dateRead = dateRead; changed = true; }
          if (isbn && !existing.isbn) { existing.isbn = isbn; changed = true; }
          if (series && !existing.series) { existing.series = series; existing.seriesNumber = seriesNumber; changed = true; }
          if (coverUrl && !existing.coverUrl) { existing.coverUrl = coverUrl; changed = true; }
          if (changed) updated++;
        } else {
          books.push({
            id: crypto.randomUUID(),
            title,
            author,
            status,
            formats: [],
            borrowedFormats: [],
            series,
            seriesNumber,
            dateRead,
            dateAdded: new Date().toISOString().slice(0, 10),
            rating: userRating,
            grRating: avgRating,
            isbn,
            notes: "",
            genre: [],
            coverUrl,
            readFormat: "",
          });
          added++;
        }
      }
    }

    if (added || updated) {
      const putRes = await fetch(`${SUPABASE_URL}/rest/v1/kv_store`, {
        method: "POST",
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates",
        },
        body: JSON.stringify([{ user_id: TARGET_USER_ID, key: "books", value: books, updated_at: new Date().toISOString() }]),
      });
      if (!putRes.ok) throw new Error(`Failed to write kv_store: ${await putRes.text()}`);
    }

    return new Response(JSON.stringify({ ok: true, added, updated, total: books.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ ok: false, error: String((err as Error)?.message || err) }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
