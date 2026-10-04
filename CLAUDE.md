# Anthology — product brief

## What it is
A personal library and book-club app. Positioning: "Your whole reading life in one place —
every format you own, every series you're in, and the club you read with."

Long-term users: any serious reader (a Goodreads replacement). Beta users: Taria + her
12-person club "No Shelf Control", most of whom use Goodreads today. The club is the
acquisition channel; the personal library is the retention engine.
"Relationship to a book" = formats & copies, how it made me feel, my reading history
over time, and social context (who recommended it, club discussion, lending).

## Product principles (apply to every change)
1. Answer the user's question, not show the database. Every screen leads with the one thing
   the user most likely came to do.
2. The book, the shelf and the club are the heroes. AI is a quiet helper, never the headline.
3. Value with zero books: a new club member must get value before importing anything.
4. Show the relationship: a book is a story (got it, read it, lent it, discussed it), not a status.
5. Spoiler-safe by default: club ratings and comments stay hidden until a member marks the book finished.
6. Never block the UI on AI or network calls: async, skeleton states, timeouts, friendly errors.

## Design system
Archive green, aged cream, deep ink, warm gold accent; serif headings, sans body.
Avoid generic SaaS defaults. Mobile-first for Club, Add book and Search.

## Information architecture
Home · Library · Series · Club · Discover · Insights; Settings (incl. Data tools).
Clicking a book opens a read-only Book page; editing is behind an Edit button.

## Tech constraints
GitHub Pages front end + Supabase (auth, Postgres, row-level security). Do not change
hosting or auth without asking. Never expose service keys client-side.

## Ways of working
- Before coding, restate the goal, list the files you'll touch, and propose a plan. Wait for OK
  on anything that changes the data model.
- Small, reviewable changes. One feature per branch/commit.
- After building, run the app, take screenshots at desktop (1280px) and mobile (375px), and
  check them against the acceptance criteria. Report what you verified and what you didn't.
- Write a short changelog entry in plain English for a non-designer.
