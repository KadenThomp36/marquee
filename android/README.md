# Marquee for Android

A native Kotlin + Jetpack Compose client for Marquee, the self-hosted household media
tracker. It's the same product as the web app and the iOS app: the Midnight Marquee look
(near-black grounds, brass amber, Limelight over Archivo, poster art given room), built
from Material 3 components dressed in Marquee's own palette and type.

It's a **companion to your own server**. There's no Marquee service, no account to sign
up for, and no server address anywhere in this repository. On first launch the app asks
where your Marquee lives. You type the address, then claim a pairing code from the web
app's Settings › Devices or sign in with your password.

## Requirements

- Android 10 (API 29) or later. The app compiles against API 37.2 and targets API 36.
- A Marquee server on build `20260727a` or newer, which added the token and pairing
  endpoints. Book requests, Folio and the newer request details need the builds named
  in `CHANGELOG.md`; on an older server those parts just don't appear.
- To build: JDK 21 (Android Studio's bundled one is fine), and the Android SDK with
  `platforms;android-37.2` and build-tools 36.1. The Gradle wrapper downloads Gradle 9.9.2.

## Build and run

```sh
cd android
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties   # once; gitignored
./gradlew :app:assembleDebug
adb -s <emulator-serial> install -r app/build/outputs/apk/debug/app-debug.apk
```

Always pass `-s <serial>` when more than one device is attached: `installDebug` installs
on **every** connected device.

The debug build (`dev.kadenthompson.marquee.debug`) installs next to a release build and
allows plain `http://`, so it can pair with a development server (from the emulator,
your Mac's `localhost:8099` is `http://10.0.2.2:8099`). Release builds allow HTTPS only.

### Release APK

```sh
./gradlew :app:assembleRelease
# → app/build/outputs/apk/release/app-release.apk  (R8-minified, about 5 MB)
```

Without a keystore, the release build is signed with the debug key, which is fine for
sideloading onto your own devices. To sign with your own key, put this in
`~/.gradle/gradle.properties` (never in the repo):

```properties
marquee.keystore=/path/to/marquee.jks
marquee.keystore.password=…
marquee.key.alias=marquee
marquee.key.password=…
```

## Pairing

1. Type the server address. A bare host is tried over `https://` first, then `http://`.
   Only an address that answers `/api/build` like Marquee does is accepted.
2. Choose **Use a pairing code** and type the six digits from the web app's
   Settings › Devices › Pair a new device (it pairs as soon as the sixth digit lands), or
   choose **Sign in with your password**.
3. Name the device, so you know which one to unpair later.

The session token is sent as `Authorization: Bearer <token>`, the same way iOS sends it.
The address and token are sealed together with an AES-GCM key held in the **Android
Keystore** and stored in DataStore. They're excluded from cloud backup and device
transfer, and never logged. **Unpair** revokes the token on the server first, then
forgets everything locally, cached screens included.

## Privacy

There are no analytics, no crash reporter and no third-party SDKs. The app talks to
exactly one host, the one you paired it with, plus the image CDNs that host's API points
at. It never authenticates to TMDB, IMDb, Plex, Overseerr, Hardcover, AniList or
Shelfmark: your server holds those keys.

## Structure

```
app/src/main/java/dev/kadenthompson/marquee/
  MainActivity.kt, MarqueeApp.kt, RootView.kt   entry, deep links, phase switch, fanfare host
  net/        MarqueeClient (OkHttp, Bearer), ServerAddress (resolve + pair/login),
              Vault (Keystore AES-GCM + DataStore), Json (lenient decoding), Body
  model/      kotlinx.serialization mirrors of ios/Shared/Models — every field
              nullable or defaulted; Int/Double/Bool decode leniently
  session/    Session (pairing state, /api/me, celebrations, request configs),
              Remote + ScreenCache (stale-while-revalidate, memory + disk), Prefs
  design/     Theme (palette, dark + light), Type (Limelight, variable Archivo),
              Components, Format (MQTime, LibraryFormat), Fold (FoldSpread / TwoPane)
  nav/        Routes (type-safe), Navigator (deep links), Shell (bar / rail, tab stacks)
  features/   next, show, detail (episode, film, person, shared pieces), library,
              reading (shelf, detail, stats, browse, book requests, progress sheet),
              requests (Overseerr), browse (upcoming, search), you (profile, stats,
              lists, history, inbox, settings, Folio), recap, celebration, pairing
```

Screens follow the iOS app one for one. Each screen fetches with `rememberRemote`. It
shows the last good copy at once and revalidates, and every write patches what's on
screen with `Remote.mutate`.

### Foldables and tablets

On wide windows (600 dp and up) the bottom bar becomes a navigation rail. Detail pages
(show, film, book, book stats, reading stats, profile) use `FoldSpread`, which ports the
iOS `FoldSpread`. When WindowManager reports a vertical hinge, the page becomes two
facing columns with the gutter on the crease. Without a hinge, a window of at least
760 dp splits near the middle. Book requests and the Year in Review use `TwoPane` (two
slides a spread). This was checked on a Pixel 9 Pro Fold emulator.

### Deep links

`marquee://show/1396`, `marquee://show/1396/e/5/14`, `marquee://movie/27205`,
`marquee://book/12`, `marquee://book/12/stats`, `marquee://manga/7`,
`marquee://books/series/<name>`, `marquee://books/author/<name>`, `marquee://u/<user>`,
`marquee://list/3`, `marquee://lists`, `marquee://recap/2025`, `marquee://history`,
`marquee://inbox`, `marquee://settings`, `marquee://book-requests`,
`marquee://search/<query>`. These mirror the web client's hash routes and
`Navigator.route(fromLink:)`; notification links use the same parser. Debug builds also
have `marquee://debug/requests`, a gallery of every request state built from sample data.

## Development notes

- The scratch dev database's poster URLs point at `127.0.0.1:8010/static/devart/…`, and
  nothing serves them. For visual QA, serve stand-in art on the Mac's port 8010 and
  `adb -s <serial> reverse tcp:8010 tcp:8010`.
- Never test book requests or Overseerr against a real server: requests download real
  files. Use the debug request gallery, or fake `book_requests` rows on a scratch
  database (states `pick`, `done`, `failed` or `cancelled` only).
