# Marquee for iOS

A native SwiftUI client for Marquee, the
self-hosted household media tracker. Same product, same Midnight Marquee identity —
near-black grounds, brass amber, Limelight over Archivo, poster art given room — with
the parts of a phone the web app can't reach.

It is a **companion to your own server**. There is no Marquee service, no account to
sign up for, and no server address anywhere in this repository. On first launch the app
asks where your Marquee lives; you type it in and either sign in or claim a pairing code
from the Devices panel in your existing web UI.

## Requirements

- **iOS 26.2** or later. Not 26.0: `SwiftUI.glassEffect(_:in:)` is annotated
  `@available(iOS 26.0)` but its symbol is absent from the 26.0 runtime, so an app built
  against the 26.x SDK is killed by dyld before its first frame. 26.2 is the oldest
  version this has been verified on.
- Xcode 26.5, and [xcodegen](https://github.com/yonaskolb/XcodeGen).
- A Marquee server running build `20260727a` or newer — that build adds the token and
  pairing endpoints below. Older servers are detected and told to update rather than
  failing with something cryptic.

## Building

From `ios/` in the [marquee](https://github.com/KadenThomp36/marquee) repo — the server,
the web app and this client live and version together:

```sh
cd ios
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig   # once: your team ID
xcodegen generate
open Marquee.xcodeproj
```

`Marquee.xcodeproj` is generated and gitignored; `project.yml` is the source of truth.
The signing team lives in `Config/Signing.local.xcconfig`, which is gitignored — skip
that step and Xcode asks you to pick a team instead.

## What the server needs

Additive and backwards compatible — the web client keeps working exactly as before:

| Endpoint | Purpose |
| --- | --- |
| `POST /api/login`, `/api/register` | accept `want_token` + `device_name`, return a bearer `token` |
| `POST /api/pair/start` | issue a short-lived 6-digit code (5 minutes) from a signed-in web session |
| `POST /api/pair/claim` | exchange that code for a token |
| `GET /api/sessions` | list paired devices |
| `DELETE /api/sessions/{sid}` | revoke one device, or `others` for all but this one |

Every other call is the API the web client already uses.

## Privacy

The point of a self-hosted tracker is that nothing leaves the house, so:

- **No analytics, no crash reporter, no third-party SDKs.** A crash report carrying your
  server address would defeat the whole exercise.
- The token lives in the **Keychain**, shared with the widget through the app group and
  nowhere else. "Unpair" revokes it server-side *first*, then forgets it locally, so the
  token dies even if the app is deleted immediately afterwards.
- The app talks to exactly one host: the one you paired it with. It never authenticates
  to TMDB, IMDb, Plex, Overseerr, Hardcover, AniList or MangaDex — your server already
  holds those keys, and none of them are embedded here.
- ATS stays on. `NSAllowsLocalNetworking` is the single exception, so a server on your
  own network reachable over plain HTTP works without weakening anything else.

## Beyond the web app

- **Widgets** — Up Next on the home screen, small/medium/large, with a punch button that
  marks an episode watched without opening the app.
- **Live Activity** — an Overseerr download on the Lock Screen and in the Dynamic Island,
  from request to available.
- **App Intents / Shortcuts** — "what's up next", mark the next episode, start a reading
  session. Available to Siri and the Shortcuts app.
- **Offline queue** — marks made without a connection are queued, superseded correctly if
  you mark the same thing twice, and replayed on reconnect.
- Background refresh with local notifications for finished downloads.

## Tests

```sh
Tools/uitest.sh                      # pairing screen only — no server needed
MARQUEE_TEST_SERVER=host:port \
MARQUEE_TEST_USER=you \
MARQUEE_TEST_PASSWORD=… \
Tools/uitest.sh                      # the full walkthrough
```

Credentials come from the environment, never from this repo. Screenshots land in
`.uitest/shots/`. Useful knobs:

- `MARQUEE_TEST_SIM="iPad Pro 11-inch (M5)"` — any simulator by name; it resolves to the
  newest runtime carrying that device.
- `MQ_ONLY=AppearanceTests/testAppAtAccessibilityTextSize` — narrow a run to one test.

`testFreshInstallRevealsNothing` is the one that matters most: it launches a clean
install with no environment set and asserts the address field is empty and the app
names no server. Point the rest at a *development* instance — the household's real
database is not a fixture. `Tools/seed_dev_server.py` fills a local SQLite file with
invented shows, films and books, writing directly to the database with no network calls.
