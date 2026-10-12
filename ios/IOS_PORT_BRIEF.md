# Marquee for iOS — port brief

> **Paste-able prompt (short form):**
>
> Build a native iOS app (SwiftUI, iOS 26+, Liquid Glass) that is a full client for
> **Marquee**, the self-hosted household media tracker in this repository. The server
> stays exactly as it is — a single-file FastAPI + SQLite app serving a JSON API at
> `/api/*` — and the iOS app replaces the vanilla-JS web client in `static/`. Read
> `main.py` for the API and data model and `static/app.js` + `static/app.css` for what
> every screen does and how it looks/feels today. Keep the product recognisable
> (same information architecture, same "Midnight Marquee" art-deco identity) but you may
> restructure navigation where a native app should differ from a hash-routed SPA.
> **Hard requirement:** nothing about the owner's homelab may ship in the app — no server
> URL, hostname, tailnet name, IP, port or credential in code, `Info.plist`, or the repo.
> The app is useless until the user manually pairs it with their own Marquee server
> (enter URL + sign in, or claim a pairing code) and every integration (Plex, Overseerr,
> notifications) is configured per-install and stored in the Keychain. Full detail below.

---

## 1. What Marquee is

A from-scratch, self-hosted **media tracker** for one household — a TV-Time replacement
that also tracks films, books and manga. Real product, real daily users, real history
(5 accounts, ~14k episode watches, ~330 films, ~28 books). The quality bar is "every
screen looks designed, not generated".

**Current stack (the part you keep):**

| Layer | File | Size | Notes |
|---|---|---|---|
| Backend | `main.py` | ~5,300 lines | FastAPI + stdlib `sqlite3` (WAL), one file, no ORM |
| Web client | `static/app.js` | ~5,100 lines | vanilla JS, hash router, no framework, no build step |
| Styling | `static/app.css` | ~2,100 lines | design tokens at the top of the file |
| Shell | `static/index.html`, `static/sw.js` | | PWA manifest + service worker |

The iOS app talks to the same `/api/*` endpoints the web client uses. Do not fork the
backend logic into Swift; if something is missing, add a small endpoint to `main.py`
(section 6 lists the few additions the port genuinely needs).

---

## 2. Hard rules (non-negotiable)

1. **No homelab details anywhere in the app or repo.** No default server URL, hostname,
   tailnet name, LAN IP, port, container id, API key, token, or account name — not in
   Swift source, not in `Info.plist`, not in xcconfig, not in tests, not in screenshots
   committed to the repo, not in fixture JSON. The binary must be equally useless to a
   stranger as to the owner until it is paired.
2. **Manual pairing only.** First launch shows a pairing screen. The user supplies their
   own server URL and signs in (or claims a short-lived pairing code generated inside
   their existing web UI). There is no discovery, no directory, no fallback host, no
   "demo mode" pointing anywhere real.
3. **Credentials live in the Keychain**, never in `UserDefaults`, never in a plist,
   never logged. Session token is revocable server-side; a "Sign out / unpair" action
   deletes it from both sides.
4. **Every third-party integration stays server-side.** The phone talks to *the Marquee
   server only* for data (the one exception: poster/still images load directly from
   `image.tmdb.org`, `assets.hardcover.app` etc. because the API returns absolute CDN
   URLs). TMDB, IMDb, Hardcover, AniList, MangaDex, Plex and Overseerr keys stay in the
   server's `settings` table. The app must never embed an API key of any kind.
5. **No analytics, no crash reporters, no third-party SDKs** that phone home — a crash
   report containing the server URL would defeat rule 1. If you want diagnostics, log
   locally and let the user export.
6. **Never point development or tests at the live server.** Run your own instance:
   `pip install fastapi uvicorn httpx && python main.py` gives you a local server on
   `:8010` with an empty SQLite DB; register the first account (it becomes admin) and
   seed it by hand. The production database is the household's real history.

---

## 3. Screen inventory (what to port)

Read `static/app.js` — every route below is a `routes.*` function in that file, and the
CSS for each lives in a commented section of `static/app.css`. Behaviour notes are the
non-obvious parts you'd otherwise miss.

### Watch Next (home) — `routes.home`, `renderHome`
- Time-of-day greeting; **Up Next** rail of in-progress shows with a punch button that
  marks the next episode watched with an animation, then advances the card in place.
- The rail scrolls **left into history**: past watches render off-screen left with
  vertical day dividers (Today / Yesterday / This week / Last week / Last month /
  Earlier). Scroll position is anchored to the first "next" card on load.
- **Haven't watched in a while** (nothing in 30 days), **Upcoming** rail,
  **Around the house** (other members' recent watches with avatars), **Recommended**
  (lazy), **Recent reviews**.
- One `GET /api/dashboard` call backs the whole screen.

### Upcoming — `routes.upcoming`
Calendar of episodes airing soon, grouped by day, for followed shows.

### Show detail — `routes.show`
Hero (poster, tagline, chips: status/cert/**IMDb rating + vote count**/network/season
count/origin), progress bar, star rating, Follow / Watching / Archive, **Request** via
Overseerr (per-season sheet with availability and live download progress), Favorite,
List, Share, Episodes editor (admin), IMDb link, Remove.
- **Tap the poster → full-screen artwork gallery** (`GET /api/images/...`, posters +
  backdrops, swipe, thumbnail strip).
- **Where to watch** is collapsed behind one summarising button ("Hulu, Paramount+ and
  11 more" / "Ready to play on your Plex").
- **Ratings panel**: per-episode line chart per season + per-season averages, IMDb first
  with TMDB fallback drawn as hollow points; season averages are vote-weighted for IMDb.
- Seasons accordion: per-episode tick, "mark all", per-season availability badges.
- Cast strip (tap → person page), household reviews + external reviews.

### Episode detail — `routes.episode`
Still hero, `S5 · E14` meta, runtime, air date, IMDb rating, spoiler-veiled overview
(unveils once watched), director/writer/guest cast, mark watched, prev/next episode nav.

### Movies — `routes.movies` / Movie detail — `routes.movie`
Watched / Watchlist grids; detail mirrors the show page (artwork gallery, where-to-watch,
request, favorite, list, share, IMDb).

### Search & Discover — `routes.search`
Type-ahead search across shows + films, trending, "because you watched X", acclaimed.
Result tiles carry quick-add buttons and a **bookmark marker when the title is already on
one of your lists**.

### Lists — `routes.lists`, `routes.list`
Named lists with a default "Want to Watch"; visibility private / public / collab;
collab lists have a **shared-with audience** (everyone in the household, or named
members). Add-to-list sheet from any title.

### Reading (opt-in per user) — `routes.reading`, `renderRDetail`, `routes.bookBrowse`
Books (Hardcover) and manga/manhwa/manhua (AniList + MangaDex chapter lists) with:
progress in pages / % / chapters, reading **sessions** with a live timer, per-medium
stats (pace, streaks, clock, monthly), detail pages with a "Wrong book?" edition picker,
author and series browse pages, Goodreads CSV import, date-fill wizard.

### Profile — `routes.profile`
Banner + avatar, headline counts, favorites strip, recap teaser, **watched rails**
(shows / films, newest first) each opening a full grid with **year dividers**
(`routes.watched`), lists, household members, and a full stats section: tiles, line
charts, a watch-clock heatmap, ratings histogram, records.

### History — `routes.history`
Reverse-chronological timeline with month and day dividers, same-show-same-day runs
collapsed into episode ranges, infinite scroll, separate films tab.

### Recap — `routes.recap`
Year-in-review, unlocked in December.

### Notifications — `routes.inbox`
In-app inbox + per-type preferences (premieres, new episodes, someone reviewed, etc.),
Web Push subscription on the web client (see §7 for the native equivalent).

### Settings — `routes.settings`
Plex link (PIN flow), IMDb ratings sync status + manual sync, notification prefs,
"Tracking extras" (books / manga toggles), imports (TV Time zip, Goodreads CSV),
household admin (members, open/close registration).

### Celebrations — `celeShow`, `celeConfetti`
Finishing a **season** or a **whole series** fires a full-screen fanfare: marquee bulbs,
spotlight rays, a foil COMPLETE stamp slammed over the poster with a shake and a haptic,
canvas confetti, run stats, "your 12th season finished in 2026". A series finale gets a
red-velvet variant. **Completions are recorded server-side as milestones**, so one that
happened while the app was closed (Plex marking your last episode overnight) is banked
and celebrated on next launch — `GET /api/celebrations`, then
`POST /api/celebrations/seen`. This is the app's signature moment; make the native
version better than the web one, not weaker.

---

## 4. Data sources (all wired server-side already)

| Source | Used for | Notes |
|---|---|---|
| **TMDB** | shows, films, episodes, images, cast, providers | server holds the token |
| **IMDb non-commercial datasets** | ratings + vote counts for films, shows, seasons, episodes | server downloads two TSVs daily and joins them; ~18k episodes rated |
| **Plex** | automatic watch tracking | per-user PIN link, server polls history every ~75s, plus a webhook |
| **Overseerr** | request media, download progress | live progress polled while in flight |
| **Hardcover** | books (metadata, covers, series, community ratings) | per-user bearer token in server settings |
| **AniList + MangaDex** | manga metadata + chapter lists | keyless |
| **Open Library** | book chapter TOCs only | keyless |
| **JustWatch (via TMDB)** | where-to-watch | |
| **Imports** | TV Time zip, Goodreads CSV | multipart upload endpoints |

The iOS app consumes all of this through Marquee's own API. It never authenticates to
any of these services itself.

---

## 5. API contract

Base: `https://<paired-host>/api`. Auth today is an httpOnly cookie `sid` set by
`POST /api/login` (`{username, password}`); `GET /api/me` bootstraps the session.
Everything is JSON; timestamps are **naive local household time** (see §8).

Grouped highlights (full list: `grep -n '^@app\.' main.py`):

- **Session** `/login` `/logout` `/me` `/register` `/signup_open` `/build`
- **Home & browse** `/dashboard` `/upcoming` `/search` `/discover` `/history`
- **Shows** `/show/{id}` · `/show/{id}/watch` (mark, unwatch, set_date, mark-previous) ·
  `/show/{id}/season/{n}/watch` · `/show/{id}/follow` · `/show/{id}/ratings` ·
  `/show/{id}/episode/{s}/{n}` · `/show/{id}/episodes/custom`
- **Films** `/movies` · `/movie/{id}` · `/movie/{id}/state` · `/add`
- **Artwork & providers** `/images/{type}/{id}` · `/watch_providers/{type}/{id}`
- **Lists** `/lists` · `/lists/members` · `/list/{id}` · `/list/{id}/item` ·
  `/list/{id}/visibility` · `/item/{type}/{id}/lists`
- **Social** `/reviews/{type}/{id}` · `/review/{id}` · `/review/{id}/reply` ·
  `/external_reviews/{type}/{id}` · `/members` · `/users`
- **Profile & stats** `/profile` · `/profile/{username}` · `/profile/avatar` ·
  `/profile/banner*` · `/profile/features` · `/stats` · `/stats/advanced` ·
  `/watched/{username}/{shows|movies}` · `/favorites` · `/recap/{year}`
- **Reading** `/reading` · `/reading/stats` · `/reading/active` · `/books/search` ·
  `/books/add` · `/book/{id}` · `/book/{id}/state` · `/book/{id}/matches` ·
  `/book/{id}/rematch` · `/books/browse` · `/manga/*` · `/{kind}/{id}/session/start|end`
- **Integrations** `/plex/status` · `/plex/pin` · `/plex/poll` · `/plex/unlink` ·
  `/request` · `/request/status/{type}/{id}` · `/request/config` · `/overseerr/me` ·
  `/imdb/status` · `/imdb/sync`
- **Notifications** `/notifications` · `/notifications/prefs` · `/notifications/read` ·
  `/push/*`
- **Celebrations** `/celebrations` · `/celebrations/seen`

Read the handler for anything whose shape matters — they're short and the response dicts
are literal.

---

## 6. Pairing, auth, and the small server changes it needs

Design the pairing flow first; everything else depends on it.

**Flow A — URL + sign-in (must work):**
1. Pairing screen: text field for the server address, with a plain-language hint that
   this is *their own* Marquee server. Validate by hitting `GET /api/build`.
2. Sign in with username + password → store the session token in the Keychain.
3. Offer "Trust this network only" behaviour for `http://` LAN addresses: keep ATS on and
   set `NSAllowsLocalNetworking` rather than disabling ATS globally; add
   `NSLocalNetworkUsageDescription` explaining it in the owner's words.

**Flow B — pairing code (nicer, do it if you can):**
The signed-in web UI generates a 6-digit code (short TTL); the app claims it and receives
a session token bound to a device name shown in Settings, revocable per device.

**Server additions this port justifies** (keep them small, backwards compatible, and in
the existing style — no new dependencies):
1. Accept `Authorization: Bearer <token>` in `current_user()` alongside the cookie.
2. `POST /api/login` gains an opt-in JSON token in the response body for native clients.
3. `POST /api/pair/start` (authenticated) → `{code, expires_at}`;
   `POST /api/pair/claim {code, device_name}` (unauthenticated) → `{token, user}`.
   Store `device_name` + `created_at` on the `sessions` row; list and revoke in Settings.
4. Optional: APNs registration mirroring `push_subscriptions` if you do real push (§7).

Everything else the app needs already exists.

---

## 7. Native opportunities (this is why we're porting)

Deliver at least the first three:

- **Widgets** — Up Next (poster + next episode + punch deep link), currently-reading
  progress, "N episodes waiting". Home Screen, Lock Screen, and StandBy sizes.
- **Live Activity** for Overseerr downloads — the web app polls a progress bar; on iOS
  this belongs on the Lock Screen / Dynamic Island until the download completes.
- **App Intents / Shortcuts** — "Mark the next episode of X watched", "What's up next?",
  "Start a reading session", plus Spotlight-indexed shows and films.
- **Notifications** — phase 1: background refresh (`BGAppRefreshTask`) that checks
  `/notifications` + `/celebrations` and raises local notifications; phase 2: APNs.
- **Offline** — cache the last dashboard, profile and shelf plus poster art; queue writes
  (mark watched, rate, list add) and replay on reconnect. Marks are idempotent
  server-side (`INSERT OR IGNORE`), so replay is safe; state changes are last-write-wins.
- **Handoff + universal links** for `#/show/…`-style deep links, share sheet extensions,
  Focus filters, and a Control Center control for "punch next episode".

---

## 8. Behaviour gotchas that will bite you

- **Timestamps are naive household-local**, not UTC (the DB was migrated deliberately in
  build `20260718a`). Send `YYYY-MM-DDTHH:MM:SS` local time; never send `Z`.
- **Episode "watched" is a row, not a flag** — `watches(user_id, show_id, season, number)`.
  Un-watching deletes it and clears any milestone so finishing again re-celebrates.
- **A season only counts as finished when it has no unaired episodes**; a series needs an
  Ended/Canceled status. Don't reimplement this client-side — read the milestones.
- **Custom episodes exist** (`episodes.source='custom'`, e.g. a fan-edit series with 472
  episodes across 38 seasons). Don't assume TMDB numbering is complete or contiguous.
- **Ratings have two sources per episode**; `src` tells you which, and the UI is expected
  to show that distinction rather than silently mixing them.
- **Books/manga are opt-in per user** (`users.features`) — hide the whole section unless
  enabled, exactly as the web client does.
- **Progress modes** — a book's progress may be expressed in pages, percent or chapters;
  the canonical stored value is pages. Converting on every write drifts values; pass
  stored values through untouched when the user didn't edit the field.
- Season/series completion, notification scans and Plex polling all happen **server-side
  on a timer** — the app observes, it does not drive them.

---

## 9. Design brief

**Identity (keep it — it is the app's personality).** "Midnight Marquee": an art-deco
cinema feel, near-black grounds, warm brass accents, generous poster art.

| Token | Value | Use |
|---|---|---|
| bg / panel / panel-2 | `#0F0D0A` / `#17140F` / `#1F1A13` | grounds |
| ink / ink-2 / muted | `#F2ECDF` / `#B3A88F` / `#7C7360` | text |
| amber / amber-2 / dim | `#F0B544` / `#FFD98A` / `#8F6D28` | accent, tint |
| velvet | `#B0404F` | series-finale moments, destructive |
| Display face | **Limelight** (OFL) | wordmark, titles, the COMPLETE stamp |
| Body face | **Archivo** variable (OFL) | everything else |

Full palette including the CVD-validated chart hues: top of `static/app.css`.

**Liquid Glass — the point of the port.** Target iOS 26+, SwiftUI, and use the real
system materials rather than imitating them:

- `TabView` with the system Liquid Glass tab bar; `.tabBarMinimizeBehavior(.onScrollDown)`
  so poster art owns the screen while scrolling; search as a dedicated tab role.
- `NavigationStack` + large titles, `.toolbar` items grouped so the system can render them
  as glass clusters; `.scrollEdgeEffectStyle(.soft, for: .top)` over hero artwork.
- `.glassEffect(_:in:)` for floating controls (punch button, request pill, the artwork
  gallery chrome), wrapped in a `GlassEffectContainer` when several sit together;
  `.glassEffectID` + `glassEffectUnion` to morph the punch button into the celebration.
- `.buttonStyle(.glass)` for primary actions; `.tint(.marqueeAmber)` app-wide.
- `.backgroundExtensionEffect()` to bleed backdrop art behind the sidebar on iPad.
- **Restraint:** glass belongs to the navigation and control layer, never stacked
  glass-on-glass, never behind body text. Posters and charts stay opaque and legible.
- Honour **Reduce Transparency**, **Reduce Motion**, **Increase Contrast** and Dynamic
  Type up to accessibility sizes; VoiceOver labels on every poster tile and progress bar.
- Light and dark both, even though the web app is dark-only — a glass design that only
  works on black isn't finished.

**Structure — liberties allowed.** Suggested tabs: **Next**, **Upcoming**, **Library**
(films + shows + reading), **Search**, **You**. Collapsing the web app's Movies and
Reading tabs into one Library, promoting search to a tab role, and moving History and
Lists under You are all fine — anything that reads as a native app rather than a
transplanted SPA. Keep the *information* and the *identity*; the layout may change.

**Motion.** The web app's signatures worth keeping: punch-to-next-episode, the completion
fanfare (§3), poster-to-fullscreen artwork transitions (use zoom navigation transitions),
progress bars that fill with a spring, and haptics on every meaningful commit. Native
gives you real physics — use it.

---

## 10. Definition of done

1. A fresh install on a stranger's phone reveals **nothing** about the owner's homelab
   and cannot reach it without them typing their own server address and credentials.
2. Feature parity with the checklist in §3 for: home, show, episode, film, search, lists,
   profile + stats, history, reading, settings, celebrations. (Recap and admin tools may
   land last.)
3. Works against a *stock* Marquee server with only the §6 additions applied — no other
   backend changes, no schema forks.
4. At least three native capabilities from §7 shipped.
5. Accessibility: VoiceOver-navigable, Dynamic Type to XXL without clipping, no colour-only
   status, Reduce Motion path for the fanfare.
6. Offline launch shows the last cached state rather than a spinner or an error.
7. No secrets in the repo; a `git log -p` for hostnames, IPs and tokens comes back empty.
8. Ships to the owner via TestFlight or a personal signing profile — no App Store listing
   is implied, and nothing in the app assumes a public audience.

## 11. Suggested order

1. Pairing + Keychain + API client + models (§6) — prove it against a local server.
2. Watch Next, Show, Episode: the punch loop end to end, with the fanfare.
3. Films, Search, Lists, artwork gallery.
4. Profile, stats, history, watched grids.
5. Reading.
6. Settings, Plex/Overseerr surfaces, notifications.
7. Widgets, Live Activity, Shortcuts, offline queue.
8. Accessibility, light mode, iPad, polish pass.

Read the web client before writing each screen — it already encodes a year of decisions
about what this product is.
