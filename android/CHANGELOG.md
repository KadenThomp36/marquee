# Android changelog

## 0.2.0 — widgets, notifications, shortcuts (Unreleased)

- **Home-screen widgets.**
  - **Up Next** adapts to its size: one show with its art, two rows at 2×2, three across
    when wide, four rows when tall. The brass check marks the episode watched without
    opening the app, and the widget moves on to the next one.
  - **Episodes waiting** shows how many episodes you're behind, and what's next.
  - **Reading** shows what's on the go with progress, plus +1 for manga.
  - Settings › Home screen pins any of the three. "Not paired" and "All caught up"
    faces cover the empty states.
- **Notifications.**
  - Real push through UnifiedPush (ntfy and other distributors), using the Web Push
    the server already sends. Messages are end-to-end encrypted and need no Firebase or
    server change.
  - Without a distributor, Marquee checks the inbox every half hour instead.
  - Tapping a notification opens what it's about. "Send a test" and system-settings
    shortcuts sit in Settings.
  - Unpairing unsubscribes the device from the server before the token is revoked.
- **Launcher shortcuts.**
  - Up Next and Search, plus shortcuts that follow your queue: mark the next episode of
    your top show, or start a reading session, without opening the app.
  - An Assistant capability lets you say "open my reading in Marquee" (Up Next,
    upcoming, reading, book requests, history, lists, settings).
- **Fix:** widgets that were already running didn't redraw with fresh data. Updates now
  bump each widget's state so it re-reads the snapshot.
- When Up Next is empty, the widgets also list shows from "Haven't watched in a while",
  so a backlog doesn't read as "All caught up".

## 0.1.0 — first build, at parity with iOS (Unreleased)

Needs a Marquee server on build `20260727a` or newer to pair. Book requests and request
details need web build `20261120i`, the Year in Review needs `20261120d` and Folio needs
`20261120b`. Everything newer decodes as optional, so an older server just doesn't show it.

### Pairing and plumbing
- Pairing works like the iOS app's: server address (https first, then http), then a
  six-digit pairing code or your password, then a device name.
- The token is sent as a Bearer header and kept in DataStore under an Android Keystore
  AES-GCM key. It's excluded from backups. Unpair revokes the token server-side first.
- Screens open on their last good copy and revalidate in the background. A launch
  without the server shows what was last synced.
- Midnight Marquee in dark (the default) and light, with Limelight and variable Archivo.
- Navigation: a bottom bar on phones and a navigation rail when the window is wide.
  Each tab keeps its own back stack, and tapping the tab you're on returns to its top.
- `marquee://` deep links and web hash routes; notification links open in place.

### Next
- A greeting, the notification bell with its unread count, and **Up Next**, which
  scrolls left into history with day dividers and opens on the first card in the queue.
- The **punch**: a WATCHED stamp, a haptic and an undoable snackbar receipt. The mark
  goes to the server straight away and any celebration it earns is queued.
- **Continue reading**: +1 chapter, log progress, or stop a running session.
- Rails: On your watchlist, Haven't watched in a while, On the calendar, Because you
  watched, Around the house, Fresh reviews. When the queue is empty, the screen points
  you to the watchlist instead.

### Detail pages
- **Show**: the hero with chips (status, certification, IMDb with vote count, networks,
  seasons, origin), your star rating, a progress bar, and the watchlist control (Add →
  On your watchlist → Watching ▾ with Stop in the menu → Resume). Also Favourite, List,
  Share, Episodes (admins), IMDb and Remove; the overview; Continue watching; Where to
  watch; the cast; and the artwork gallery behind the poster.
- **Ratings chart**: per-episode lines by season, IMDb points filled and TMDB points
  hollow, season averages coloured on the quality ramp, and the best episode marked.
- **Seasons**: an accordion with ticks, mark/unmark all, request state per season, a
  "you're ahead" prompt, and a long press to edit the watch date.
- **Episode**: the still behind a spoiler-veiled overview, credits, guest stars, Mark
  watched, and previous/next.
- **Film**: Mark watched, Watchlist, rating, request, where to watch, cast, reviews.
- **Person**: bio and credits filtered by TV or films.
- **Reviews**: write, edit, delete and reply. The house's reviews and the community's
  are veiled until you've watched it.

### Requests (Overseerr)
- A status pill with an icon (Requested, Searching, Downloading, Partly on Plex, On
  Plex) and a progress bar with the time left in words. It updates every 8 s while busy.
- The season sheet shows a strip of every season, select-all, each season's state and a
  counted Request bar. A request lands with a check.
- The details panel shows what's on Plex (resolution, HDR, codecs, size), current
  downloads, and who asked, with **Delete request** (it asks first).

### Library
- **Shows**: Watchlist (grouped Ready to binge / Airing now / Coming soon, with hours),
  Watching, Caught up, Finished and Stopped. Your last shelf is remembered. Rows show
  provider, IMDb, household and Start/punch. A long press stops, resumes or removes,
  and removing an unstarted show can be undone. **Can't decide?** deals three.
- **Films**: Watchlist (Out now / Coming soon) and Watched, with household faces;
  removing can be undone.
- **Reading**: books and manga shelves (Reading, Want, Paused, Finished, Didn't
  finish), a live session strip, an add field searching Hardcover/AniList, +1 and log
  on tiles, a long-press move/remove with Undo, and the door to book requests.

### Reading
- **Book/manga page**: shelf states (Paused and Didn't finish under "…"), progress in
  pages, % or chapters, a session timer and End session, the Folio sync line, the Reading
  stats door, rating, dates, the manga chapter list, the reading log with a sitting
  editor, Around the house, **Wrong book?**, and Hardcover/AniList links.
- **One progress sheet** for every way of logging: a mode-aware readout, a slider with
  haptic ticks, jump chips, exact entry and session stats. "Finished it" appears only at
  the end; discarding a session asks first.
- **Reading stats per book**: the finish date lit on a marquee sign, the numbers, the
  whole book as one strip coloured by source, the calendar, chapter pace, and every
  sitting grouped by month (tap one to fix it).
- **Series and author pages**: your copies first with #N badges, then the rest from
  Hardcover to add from.
- **Reading stats**: totals, pace, streaks, the last 30 days, by month, the clock,
  weekdays and the ratings histogram.
- **Book requests (Shelfmark)**: the Request button sits in the book's action area. The
  status pill is polled every 4 s while the request moves and opens the detail sheet:
  the copy, In Calibre, who asked, **Choose a copy** (good matches first, tried copies
  marked), Try again, Cancel, Delete and Request another copy. **You › Book requests**
  searches the downloader and lists every request in the house; it shows two panes when
  the window is wide.

### Upcoming, Search
- Upcoming shows new chapters, then days (Tonight, Tomorrow, weekday, date) of episodes
  and films.
- Search covers shows and films, plus books and manga for readers (All / Shows & films
  / Books / Manga), with quick-add. Discover sections show when the field is empty.

### You
- **Profile**: a banner (choose one, or remove it), an avatar (photo picker), headline
  counts, favourites (long-press to remove), the Year in Review teaser, watched rails
  (opening a full grid with year dividers), lists, links (lists, history, notifications,
  book requests), the household, and **the numbers**: tiles, records, month by month,
  the watch clock, most watched, genres, your shows, films by decade, ratings, and
  deeper cuts.
- **Lists**: your lists and shared ones, New list, visibility with a collab audience,
  remove items, delete a list. Add to list from any title.
- **History**: TV runs grouped by month and day, a Films tab, endless scroll.
- **Notifications**: the inbox, Mark all read, links followed.
- **Settings**: this device and Unpair, devices (sign one out or every other one, pair
  a new one), the Plex link (PIN flow), Overseerr, IMDb sync, notification preferences
  with lead days, tracking extras (books/manga), Folio, appearance.
- **Folio**: switch it on, auto capture, paired readers with last sync and Unpair,
  **Pair a reader** (a six-digit code; the reader appears when it registers), and
  **Waiting for a book** with Match (your shelf first, then Hardcover), Look now and
  Ignore.

### Year in Review
- A countdown leader rolls it in. Then: a guessing game, the count, show of the year,
  your persona stamp, prime time, the big month, genres, films, your reading year and
  record, your rank in the household, the records, and a ticket to share (text only;
  it never names the server).
- It's drawn on a fixed 360×640 canvas fitted to the screen. Tap to go on, tap the left
  edge to go back. Opened out, it reads two slides a spread.
- After release day it opens by itself, once, on whichever device opens first.

### Celebrations
- Finishing a season or a series raises a fanfare: chasing bulbs, spotlight rays, a foil
  COMPLETE stamp slammed over the poster with a shake and a haptic, confetti, run stats,
  and "your 12th season finished in 2026". A series finale gets red velvet. Completions
  banked server-side (Plex overnight) celebrate on the next launch.

### Not yet (follow-ups)
- An offline write queue: iOS queues marks made offline and replays them. Android
  shows the error and refreshes instead.
- The screening room and curtain (iOS's half-open Duo modes). Tabletop posture is
  detected (`isTabletop()`) but nothing uses it yet.
- A Live Update for downloads, and ending a reading session at a page from a shortcut
  ("I'm on page 214"); the shortcut for that opens the book instead.
- Imports (TV Time zip, Goodreads CSV) and household admin aren't in iOS Settings
  either; they stay in the web app.
