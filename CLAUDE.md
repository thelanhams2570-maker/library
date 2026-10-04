# Anthology — product brief

Read this before every task. Brand rules live in `brand/BRAND.md`; the task list lives in `docs/TASKS.md`.

## What it is
A personal library and book-club app. Renamed from **Anecdote** to **Anthology**: update any remaining references.

- Tagline: **Your life, in books.**
- Practical line (App Store subtitle, sign-up): **Your books, collected.**
- Positioning: every format you own, every series you're in, and the club you read with.

Long-term users: any serious reader (a Goodreads replacement).
Beta users: Taria and her 12-person book club, "No Shelf Control". Most of them use Goodreads today.
The club is how people arrive; the personal library is why they stay.

"Relationship to a book" means four things: formats and copies; how it made me feel; my reading history over time; and social context (who recommended it, club discussion, lending).

## Product principles (apply to every change)
1. Answer the user's question, not show the database. Every screen leads with the one thing the user most likely came to do.
2. The book, the shelf and the club are the heroes. AI is a quiet helper, never the headline.
3. Value with zero books: a new club member must get value before importing anything.
4. Show the relationship: a book is a story (got it, read it, lent it, discussed it), not a status.
5. Spoiler-safe by default: club ratings and comments stay hidden until a member marks the book finished.
6. Never block the UI on AI or network calls: async, skeleton states, timeouts, friendly errors.

## Design system (summary; full rules in brand/BRAND.md)
- Use `brand/tokens.css` as the single source of colours, fonts, radii and shadow. Never hard-code a hex value in a component.
- Forest `#163D33` is primary. Sage `#5E8C79` is for the logo mark, icons and large fills only (fails contrast for small text). Terracotta is for progress and ratings only.
- Fonts (Google Fonts): **Playfair** (optical sizing) for headings, book titles and quotes; **Inter** for all interface text.
- Soft shapes: 3px covers, 8px buttons and inputs, 12px cards, 20px hero cards and sheets, pill chips and search.
- Icons: Lucide, 1.5px stroke.
- Logos and icons: `brand/logos/` and `brand/app-icons/`. Never retype the wordmark in a live font.
- Photography: `brand/images/` (rules in IMAGES.md). Real book covers always beat stock photos.

## Information architecture
Home · Library · Series · Club · Discover · Insights; Settings (includes data tools).
Clicking a book opens a read-only **Book page**; editing sits behind an Edit button.
Mobile: bottom tab bar with Home, Library, Club, Discover, Me.

## Tech constraints
GitHub Pages front end + Supabase (auth, Postgres, row-level security). Do not change hosting or auth without asking. Never expose service keys client-side.

## Ways of working
- Before coding, restate the goal, list the files you'll touch and propose a plan. Wait for an OK on anything that changes the data model.
- Small, reviewable changes. One task per branch or commit.
- After building, run the app, screenshot at desktop (1280px) and mobile (375px), in light and dark, and check against the task's acceptance criteria. Report what you verified and what you didn't.
- Write a short changelog entry in plain English for a non-designer.
