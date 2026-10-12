# Marquee for iOS — addendum: reading progress & sessions

Companion to `IOS_PORT_BRIEF.md`. Read that first; every rule there (pairing, no
homelab details, server API only, design identity) applies here unchanged.

## Why this addendum exists

The web app just replaced its reading progress/session UX. The old flow — a number
field with −/+ steppers, a bare "type a number" box when a session ended, a full
re-render on every change — was the worst part of the product, and the owner said so.
The web fix (build `20260812a`, see `rdScrubber` in `static/app.js`) is the new
*floor*, not the target. On iOS you have real physics, real haptics and real sheet
presentation: **this area is where the native app should most obviously beat the web.**

## The interaction, in product terms

One recurring moment: *"I just put the book down — capture where I am, in one
thumb motion, in under five seconds."* Everything below serves that.

What the web version now does (parity baseline):

- One bottom sheet for all progress entry, opened from the detail page, from any
  shelf card's progress bar, and from ending a live session.
- A large drag-anywhere track with a big live readout. The readout speaks the
  user's chosen unit for that title — pages, percent, or chapters — and books with
  a table of contents snap to chapter boundaries and show the chapter title.
- Quick-add chips for the common increments, a "Finished it" affordance, and
  tap-the-number to type an exact position.
- Ending a session shows the session's own numbers *in the sheet, above Save*:
  elapsed time, units gained, approximate pace, and a marker on the track where
  the session began. Ending and discarding are separate, honest actions.
- Saving never reloads the screen; the page updates in place.
- Reaching 100% offers finishing the book, which also stamps the finish date.

## Where iOS should go past it

Liberties encouraged — these are directions, not specs. Keep the grammar
(one gesture, mode-aware readout, session numbers at the moment of ending),
improve everything else.

- **Feel.** A scrubber with real deceleration, rubber-banding at the ends, and
  `SensoryFeedback` ticks that scale with scrub speed (coarse ticks per chapter,
  fine per page — not one buzz per pixel). Snap points you can feel. If a Digital
  Crown ever exists in scope (watch app), this is its natural home.
- **Presentation.** A proper sheet with detents: compact detent = readout + track +
  chips (the five-second case); expanded = TOC list, session numbers, notes.
  Liquid Glass belongs on the sheet chrome and floating controls, never behind the
  readout numerals.
- **Sessions as first-class time.** A running session is a Live Activity: elapsed
  time and current book on the Lock Screen / Dynamic Island, with "End" deep-linking
  straight into the scrubber. Starting a session could offer a Focus suggestion.
  Ending one deserves a small, satisfying summary moment (the web toast is the
  minimum, not the model).
- **Ambient entry points.** A widget showing the current book and progress that
  deep-links to the scrubber; App Intents — "log my reading", "I'm on page 214",
  "start a reading session" — that resolve against the current book without
  opening the app; StandBy showing the live session.
- **Offline-first.** A progress update is tiny and idempotent — queue it and sync
  later; never block the sheet on the network. (Server behaviour notes: progress
  is stored canonically in pages for books; sessions auto-create checkpoint
  entries; the state endpoints are safe to replay.)
- **Accessibility.** The scrubber must be fully usable via VoiceOver
  (adjustable trait, increment = one chapter or a sensible page step), respect
  Reduce Motion, and never rely on drag as the only path — chips and typed entry
  are the accessible equivalents, keep them.

## Server contract (already live — no additions needed)

Everything ships against the existing API: reading shelf and per-title state
(progress, mode, dates, rating), session start/end (end accepts a position or a
discard flag, and bumps shelf progress itself), an active-sessions list for
resuming after app restarts, per-medium stats, and the reading log with editable
entries. Read the handlers in `main.py` for exact shapes; nothing about this
feature requires new endpoints.

Two behaviour rules worth restating from the main brief because this feature
touches them constantly: **progress is canonical in pages** for books (convert
for display only, and pass stored values through untouched when the user didn't
edit them — round-tripping through percent drifts), and **timestamps are naive
household-local**, never UTC.

## Definition of done for this area

1. Logging "I stopped on page N" takes one gesture from the shelf, and works
   offline.
2. A live session survives app termination and is visible without unlocking the
   phone; ending it from the Live Activity lands in the scrubber with the
   session's numbers already there.
3. The chapter-snap experience on a TOC'd book feels like flipping to a chapter,
   not like operating a slider.
4. VoiceOver users can do everything drag users can.
5. Put the web version (`#/book/…` on any tracked book) next to yours: if yours
   isn't clearly nicer to use one-handed on a phone, it isn't done.
