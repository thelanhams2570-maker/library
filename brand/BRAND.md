# Anthology brand rules

Tagline: **Your life, in books.** Practical line: **Your books, collected.**

## Logo
| File | Use |
| --- | --- |
| `logos/anthology-logo-horizontal.svg` | Primary. Desktop header, emails, marketing. With tagline. |
| `logos/anthology-logo-horizontal-no-tagline.svg` | App header and anywhere the lockup is under 48px tall. |
| `logos/anthology-logo-stacked.svg` | Welcome / sign-in screen, splash, print. |
| `…-reverse.svg` versions | On forest `#163D33` or dark backgrounds. |
| `logos/anthology-mark-*.svg` | Mark alone: avatars, loading states, small spaces. Sage on light, moss on forest, forest at 24px and under. |
| `app-icons/` | Favicon, Apple touch icon, PWA icons (see below). |

- Minimum sizes: horizontal lockup 24px tall; mark 16px.
- Clear space on every side: the width of one quote mark.
- Don't: recolour in terracotta or sand, add gradients or shadows, rotate, retype the wordmark in a live font, close the gap between the two quote marks, or place the light logo on a photo without a solid panel.

### Favicon and app icon wiring
```html
<link rel="icon" href="brand/app-icons/favicon.svg" type="image/svg+xml">
<link rel="icon" href="brand/app-icons/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="brand/app-icons/apple-touch-icon.png">
<link rel="manifest" href="site.webmanifest">
<meta name="theme-color" content="#163D33">
```

## Colour
All values live in `tokens.css`. Contrast measured on cream `#FBF8F3`.

| Token | Hex | Job | Text-safe? |
| --- | --- | --- | --- |
| forest | #163D33 | Primary buttons, headings, wordmark | Yes, 11.3:1 |
| sage | #5E8C79 | Logo mark, icons, large fills | No (3.6:1). Large text and fills only |
| sage-text | #3F6F5D | Links, tags, small green text | Yes, 5.4:1 |
| moss | #A7BBA8 | Mark on forest, illustrations | No |
| mist | #E7EEE8 | Bands, tag backgrounds, empty progress tracks | Background |
| cream | #FBF8F3 | Page background | Background |
| surface | #FFFFFF | Cards, sheets | Background |
| ink | #17211D | Body text | Yes, 15.6:1 |
| muted | #55625C | Authors, dates, captions | Yes, 6.0:1 |
| terracotta | #D9A783 | Progress bars, star ratings | No (2.0:1). Fills only |
| terracotta-text | #94582C | "Due back", warnings | Yes, 5.4:1 |
| sand | #EAD9C6 | Marketing and print only | Not used in the app |

Rough proportions on a screen: cream and white 70%, ink 15%, forest 8%, sage and mist 5%, terracotta 2%. Book covers bring the rest of the colour.

Dark mode (already in `tokens.css`): background #0E1915, cards #15241F, text #EEF1EC, primary #8FBFA9.

## Type
Load from Google Fonts:
```html
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Playfair:ital,opsz,wght@0,5..1200,300..800;1,5..1200,300..800&family=Inter:wght@400..600&display=swap">
```
If the "Playfair" family fails to load, use "Playfair Display" for headings 24px and up, and keep book titles in lists at 600 weight.

| Style | Font | Size / line height |
| --- | --- | --- |
| Display | Playfair 500 | 48 / 52 |
| H1 | Playfair 500 | 34 / 40 |
| H2 | Playfair 500 | 26 / 32 |
| Book title (lists) | Playfair 600 | 18 / 24 |
| Quote / note | Playfair italic 400 | 20 / 30 |
| Body | Inter 400 | 16 / 26 |
| Label / button | Inter 500 | 14 / 20 |
| Caption | Inter 400 | 13 / 20, muted |
| Eyebrow | Inter 600 | 11 / 16, uppercase, tracked 0.18em, sparingly |

Sentence case everywhere except the eyebrow and the logo tagline.

## Shape, elevation, icons
- Radius: covers 3px, buttons and inputs 8px, cards 12px, hero cards and bottom sheets 20px, chips and search pill.
- One soft shadow (`--shadow-lift`) on tappable cards only. No other shadows.
- Focus ring: 2px sage outline, 2px offset.
- Icons: Lucide (`lucide` package), 1.5px stroke, ink or muted. Nav: house (Home), library (Library), users (Club), sparkles (Discover), user (Me), list (Series), arrow-left-right (Lent and borrowed), calendar (Meetings).

## Voice
A knowledgeable friend: warm, curious, down to earth, never gushing.
- Yes: "You already own this in ebook." No: "Duplicate item detected."
- Yes: "Sam has your copy." No: "Loan status: active."
- Yes: "3 books to go to hit 52." No: "You're behind pace!"
