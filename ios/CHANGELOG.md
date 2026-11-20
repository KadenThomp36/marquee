# iOS changelog

## Unreleased — Year in Review, and a tidier Duo

Needs web build `20261120d`.

- **Year in Review, rebuilt.** A night at the pictures: a countdown leader rolls it
  in, a guessing game ("how many hours do you think…?"), then show of the year, your
  persona stamp (Night Owl, Binger, Bookworm…), prime time, the big month, genres,
  films, your reading year, where you rank in the household, the records, and a
  ticket to share. Drawn on one canvas fitted to the screen, so it looks the same on
  every phone; on the Duo opened out it reads like a programme, two slides a spread.
- **It premieres by itself, once.** After release day (Boxing Day unless the admin
  picks another) the recap opens on its own the next time you launch, then never
  again on any device. Opening it in January still counts.
- **Duo, opened out:** Settings moved from the top of your profile to the rail; your
  numbers sit in two columns either side of the crease; the month-by-month chart
  labels each January instead of every month.
- **Reading stats, cleaner:** no bar title over the hero, sittings with the source as
  a quiet dot and chapters on their own line, chapter pace in aligned columns, no
  scroll bar running down the crease.

## Unreleased — Folio v1.1: nothing gets stuck

Needs web build `20261120b`.

- **Settings › Folio › Waiting for a book.** Sittings Folio sent for a file Marquee
  can't place yet (Hardcover down, or a book it doesn't know) are kept on the server
  and listed here by file — title, author, sittings, time, why it's waiting and when
  Marquee looks again. **Match** opens a picker with your own shelf first (it works
  while Hardcover is down) and Hardcover's search under it; the sittings land on the
  book you pick. **Ignore** is for personal documents: they're dropped and Folio's
  later sittings in that file aren't kept. **Look now** asks Hardcover straight away.
- *Record sittings automatically* now says it controls recording on the reader.
- Stats: chapter pace is printed pages an hour (or % an hour) from Folio's chapter
  positions, screens an hour only when it didn't send them; long chapter lists show
  12 with *Show all*.

## Unreleased — Folio, and one book's reading in depth

Needs a server with the Folio integration (web build `20261120a`). Everything new
decodes as optional, so an older server just doesn't show it.

### Reading stats for a book
- **A stats page per book** (from the book's page: *Reading stats*). The finish date
  is the headline — Limelight, lit like an opening date on a marquee, with the
  arithmetic under it ("11 days at your recent 6.8 pages a day — about 1 h 12 min of
  reading left"), or the finish date once it's done.
- Reading time, sittings, pace (pages an hour, or % an hour for a book with no page
  count) and a typical sitting; the **whole book as one strip** with every sitting
  laid across the stretch it covered, coloured by where it came from, and a
  *you're here* marker; a **calendar** of the days you read it; and **chapter by
  chapter** time and pace when Folio sent chapters.
- **Sittings** as a timeline grouped by month, each with its length, pages, the
  chapters it crossed, a sliver of where in the book it ran, and a source pill
  (Folio by the reader's own name, iPhone, Web). Tap one to fix it — the same edit
  sheet as the reading log. Folio sittings say how much idle time was left out.
- **On the iPhone Duo opened out it's a two-page spread** (the same `FoldSpread`
  as the show/film/book pages): summary and pace on the leading page, the sittings
  on the facing one, the gutter on the fold. Closed, it's one column.

### Folio
- **Settings › Folio** (with Books on): switch it on, *Record sittings
  automatically*, the paired readers with last sync and sittings synced, Unpair,
  and **Pair a reader** — a six-digit code for Folio's setup, using the same pairing
  flow as this app. The reader appears the moment Folio registers.
- A book's page says when Folio just synced it: "Read on Boox Palma 2 hours ago —
  40 min, 14 pages, up to Chapter 19". The reading log marks Folio rows, and shows
  percentages for a book without a page count.

## Unreleased — iPhone Duo

Built against the iOS 27.1 SDK and tried on the iPhone Duo simulator in every pose.
Everything below is gated on iOS 27.1 and on the device actually having a hinge, so
every other phone (and anything older) behaves exactly as before.

### Two pages, either side of the crease
- On the Duo's inner display the **show, film, book and manga pages become an open
  book**: the hero, overview, where-to-watch and cast on the leading page; ratings,
  seasons, chapters and reviews on the facing one. Each page scrolls on its own, and
  the gutter sits exactly over the fold (from the system's division region, asked for
  *including inactive* so the columns don't reflow as the hinge moves). An iPad gets
  the same two columns either side of the middle. Phone-sized, it's the one column it
  always was, in the same order.
- Film and reading pages gained pull-to-refresh on the way.

### The screening room
- **Prop the Duo half-open and Up Next becomes a little cinema.** The standing half is
  a marquee — the poster, the show in Limelight, the episode, bulbs chasing round the
  sign in steps like a real one. The flat half is the box office: a **showtime clock**
  that knows the episode's length ("of 48 min · ends 9:46 PM"), a brass **Mark
  watched**, and arrows through the rest of the queue.
- Laid on a table like a laptop, the sign sits above the controls; held like a book,
  they face each other. Either way the crease is the line between them.
- Marking an episode stamps **Watched** across the sign, advances to the next one,
  raises any celebration, queues offline, refreshes the widget — and Home refetches
  when you leave (`Session.watchRevision`).
- **Reading lamp:** with a reading session running, the room opens on the book instead
  — cover, "Page 244 of 331" (or "74% read"), and a ring of how far through you are
  round the session's running time, with **End session** opening the usual progress
  sheet. With both a show and a book to hand, a Watching / Reading switch.
- Folding the phone further dims the **house lights** and the bulbs glow harder. The
  clock keeps the screen awake only while it's running, survives a relaunch, and the
  room keeps the house lights down for its own sheet.
- **Leave the screening room** stays left until the phone stops being half-open. VoiceOver
  can't reach the app underneath while it's up; two-finger scrub leaves.

### Curtain up
- **Opening the phone raises a velvet curtain** whose two halves meet exactly on the
  crease and draw back from it. Keyed off the fold appearing (the outer display reports
  none), so it lands with the new screen rather than whenever the hinge reports.
  Skipped with Reduce Motion.

### Rotation on the inner display
- The app now turns on the Duo's inner display (it's iPad-sized — regular × regular),
  which is what lets the screening room go from book to tabletop. Every other phone is
  still portrait-only (`OrientationDelegate`).

### Settings
- **When it folds** — Screening room and Curtain up switches, shown only on a phone
  with a hinge.

### Fixes
- Show page: your star rating was blank on every visit after the first. The page
  opens from cache with the rating already set, and a plain `onChange` never fired for
  it (`initial: true` now).
- Upcoming: days more than a week out printed their date twice ("Oct 31, 2026
  Oct 31, 2026"); they now read "Saturday  Oct 31, 2026".

### Verify on the device
- Tabletop pose: the simulator can't rotate the Duo, so the stacked layout was checked
  by forcing it — confirm on hardware that rotating the half-open phone stacks the sign
  over the box office, and that the app really does rotate on the inner display.
- Hinge angle → house lights: the simulator reports only the three poses, so the dimming
  hasn't been seen at in-between angles.

## Unreleased — watchlist, reading on Home, sessions that end

Brings the web app's builds `20261011a`–`20261011d` to the native client, without
giving up what iOS already did better (segmented Library, widgets, App Intents, the
offline queue, haptics, pull-to-refresh). Everything new is additive against the API:
new model fields are optional, so an older server still decodes.

### Shows: a real watchlist
- **Library › Shows** is now shelves from `GET /api/shows`: **Watchlist** (default,
  remembered between launches) · Watching · Caught up · Finished · Stopped, as scrolling
  chips with counts. The library search field filters every shelf.
- The watchlist is grouped **Ready to binge / Airing now / Coming soon**, each headed with
  its count and hours. Rows show the poster, "2 seasons · 19 eps · ~16 hrs", where it
  streams (or the network), the IMDb score, and the household on one line
  ("Mia finished it · ★9", "On Jo's watchlist too", "Jo is on S2 E3").
- A big **Start** button off the art marks the first episode watched — same success
  haptic, punch receipt and celebration handling as Home — and the show moves to
  Watching. Watching rows show the next episode, what's left, hours and a progress bar.
- **Swipe to remove** (or long-press). Removing a show you never started happens at once
  with an **Undo** banner that restores it in place (re-follow with its `added_at`).
  Removing a show you've watched deletes its history, so that asks first. Watching rows
  also swipe to **Stop**, stopped rows swipe to **Resume**; stopping offers Undo.
- **Can't decide?** deals three random Ready-to-binge shows in a sheet; deal again with
  a haptic, tap one to open it.
- A server without `/api/shows` falls back to the old watched-shows grid.
- Library now opens on Shows (was Films).

### Films
- Watchlist is the default shelf, grouped **Out now / Coming soon** (soonest first).
  Watchlist tiles show runtime and certification, the streaming service, and housemates'
  faces on the art (their line is in the long-press menu and the VoiceOver label).
- Removing a film offers Undo, which restores its rating, watch date and `added_at`.
- Fixed: "Move to watchlist" removed the film from both shelves instead of moving it.

### Show page
- Watchlist language: **Add to watchlist** → **On your watchlist** (tap to take it off)
  → **Watching ▾** (Stop watching lives in the menu, never a single mis-tap) →
  **Resume watching**. Search tiles say "Add to watchlist" too.
- Clearing your star rating now actually clears it (`"rating": null`), for shows and
  reading alike.

### Home
- **Continue reading** rail after Up Next (reading users only): cover card with
  progress, "~3 days left at your pace" or "4 new chapters". The button is **+1 chapter**
  for manga and chapter-mode books, otherwise it opens the progress sheet; with a session
  running it's a **stop** button that ends it into the sheet.
- **On your watchlist** rail, whose "All" opens the Shows watchlist. When Up Next is
  empty but the watchlist isn't, Home points there instead of just saying "done".

### Reading
- New states **Paused** and **Didn't finish** — model, shelves, tiles, long-press menu,
  and the detail page (segmented Want/Reading/Finished plus a "…" menu; a paused title
  gets a "Pick it back up" button). `ReadingState` decoding is tolerant: an unknown
  state no longer fails the shelf.
- **One progress sheet** (`ReadingProgressSheet`) for every way progress gets logged —
  the detail page's bar and number, a shelf tile, Home, ending a session. Mode-aware
  readout (pages / % / chapters, with TOC chapter titles), a native slider with
  unit-scaled haptic ticks, jump chips, tap-the-number exact entry, medium/large
  detents. Offline, a progress save is queued like any other write.
- **Sessions end.** The detail page shows a running session with a live timer and
  **End session**; the sheet shows elapsed time, units gained and pace above **Save
  session**, a short "Nice session" moment only after the server confirms, and a
  failure message (the session keeps running) if it doesn't. **Discard** asks first.
- **One tap never finishes a book.** The shelf tile's checkmark is gone — it's now the
  progress sheet; "+1" that would reach the last chapter opens the sheet; "Finished it"
  only appears there at 100%. Choosing Finished from the detail page's shelf control
  asks unless you're already at the end.
- **Remove has Undo** on the shelf, via `POST /{kind}/{id}/restore` (falls back to a
  plain state write on servers without it). Removing from the detail page asks first.
- Ratings decode leniently — a book can carry a half score (`7.5`), which used to fail
  the whole shelf — and are always sent as numbers.
- Search results open the right book: Hardcover results now route to the preview
  endpoint (`book/hc/{id}`) instead of treating the Hardcover id as a local one.

### Search
- With reading on, Search covers **Books** and **Manga** too, with All / Shows & films /
  Books / Manga segments; tiles add straight to Want to read (or Reading).

### Upcoming
- **New chapters out** at the top for manga you're reading.

### Shortcuts
- New **End a Reading Session** App Intent ("I'm on page 214") — the other half of
  Start a Reading Session. Position is in the title's own unit and converted like the
  app does; leave the title empty to end whichever session is running.
- There is no reading Live Activity yet, so nothing else needed ending.

### Verify in Xcode (written on Linux, not compiled)
- Builds clean under Swift 6 strict concurrency — especially the `UndoToast` closures
  (`@MainActor () async -> Void` captured into `Task {}`), the `async let` search fan-out
  in `SearchScreen`, and `.task(id:)` closures in `UndoHost` / `ShowsShelf`.
- `ShowsShelf`'s `List`: the hidden `NavigationLink` row trick (no chevron, whole row
  opens the show) while the Start button (`.borderless`) still takes its own taps;
  swipe actions; sticky group headers look right on the Midnight ground.
- `Menu` with `.menuStyle(.button).buttonStyle(.borderedProminent)` renders as the brass
  "Watching ▾" pill on the show page.
- `@AppStorage` with the `ShowShelf` enum; `navigationDestination(item:)` from the deal
  sheet pushes onto the Library (and Home's pushed watchlist) stack.
- The progress sheet's `Slider` + `.sensoryFeedback(.selection, trigger:)` feel; the
  number-pad keyboard toolbar "Done"; detents.
- VoiceOver: Shows rows read as one button plus a separate Start button.
- `EndReadingSessionIntent` appears in Shortcuts with its parameter summary and asks
  for the position.
