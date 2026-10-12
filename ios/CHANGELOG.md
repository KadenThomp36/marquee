# iOS changelog

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
