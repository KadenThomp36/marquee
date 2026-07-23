# Marquee — Contributor Agent Brief

You are one of several agents each building **one feature** on Marquee in your own
git worktree + branch, opening your own PR. Read this whole file before touching code.
Your specific task + branch + worktree path are in your spawn prompt. This file is the
shared context.

Marquee is a from-scratch, self-hosted household **media tracker** (TV / movies / anime) —
a polished TV-Time replacement. It is a **live app with 5 real users and real watch
history**. Quality bar is high: this is the maintainer's pride project and every screen
is expected to feel designed, not generated.

---

## 0. Hard rules (do not violate)

1. **NEVER touch the live server.** Do not `pct exec` into the production container, do not read/write `/opt/marquee`,
   do not connect to the production host, do not touch any `.db`. The maintainer deploys.
   You work **only inside your worktree** on the host filesystem.
2. **Stay in your lane.** Only edit the files/functions your task owns (listed in your
   spawn prompt). Touching another agent's area causes merge conflicts. When two features
   must meet (e.g. a section on the profile), use the **integration contract** in your
   spawn prompt — expose a function, don't edit the other agent's route.
3. **Run `/frontend-design:frontend-design`** (the Skill tool, skill name
   `frontend-design:frontend-design`) and apply it to any UI you build. If the skill isn't
   in your available list, read it at
   `/root/.claude/plugins/cache/claude-plugins-official/frontend-design/` and apply it.
4. **Bump `BUILD` in all three places** if you change frontend (`main.py`, `static/app.js`,
   `static/index.html` `?v=`). Use `20260706i` (or the next letter if taken). The client
   auto-refreshes PWA caches on `BUILD` change. Coordinate is fine — the maintainer
   reconciles at merge; just don't leave them mismatched within your own branch.
5. **Match the existing code.** Single-file backend, vanilla-JS SPA, no new dependencies,
   no build step, no framework. Read the neighbours before writing.

---

## 1. Stack & files

- **Backend:** `main.py` — one file, FastAPI + stdlib `sqlite3` (WAL). ~2640 lines.
- **Frontend:** `static/app.js` (~2240 lines) + `static/app.css` (~1040 lines), vanilla JS,
  **hash routing**, no framework. `static/index.html` is the shell.
- **Serving:** uvicorn, port 8010, systemd unit `marquee` (on the live box; not your concern).
- **PWA:** `static/sw.js` (network-first HTML, stale-while-revalidate for `?v=` assets).

## 2. Backend conventions (`main.py`)

- **Tables** are created at the top with `CREATE TABLE IF NOT EXISTS` (see lines ~48–92).
  Existing: `users, sessions, shows, episodes, follows, watches, movies, movie_states,
  settings, lists, list_items, reviews, review_replies, notifications, notif_prefs,
  notif_sent, push_subscriptions`.
- **Adding a column** to an existing table → append to the idempotent ALTER loop near
  line ~2617:
  ```python
  for stmt in ("ALTER TABLE lists ADD COLUMN visibility TEXT DEFAULT 'private'", ...):
      try: con.execute(stmt)
      except sqlite3.OperationalError: pass
  ```
  **Adding a new table** → add a `CREATE TABLE IF NOT EXISTS` next to the others. Both are
  safe on the live DB (idempotent). Never write data-destructive migrations.
- **Endpoints:** `@app.get("/api/...")` / `@app.post(...)`. Auth via
  `user=Depends(current_user)` (returns the row; has `user["id"]`, `user["username"]`,
  `user["is_admin"]`). Admin-only: `Depends(admin_user)`.
- **DB access:** `with db() as con:` (a context manager returning a `sqlite3.Connection`
  with `row_factory=sqlite3.Row`). Look at an existing endpoint (e.g. `stats()` ~1747,
  `get_lists()` ~420, `get_profile()` ~350) and copy the shape exactly.
- **Settings/secrets** (TMDB v4 token, Overseerr, Plex, VAPID) live in the `settings`
  table, read via `setting(con, "key")`. Never hardcode. TMDB helper functions already
  exist — grep `tmdb` before adding a new external call.

## 3. Frontend conventions (`static/app.js`)

- **Router:** `parseHash()` maps `#/foo` → `routes.foo()`. Define a screen as
  `routes.name = async () => { ... view.innerHTML = ` ... `; }`. `view` is `#view`.
- **Helpers you must reuse (do not reinvent):**
  - `api(path, {method, body})` → fetch JSON from `/api/...` (auto JSON, throws on !ok).
  - `cached(path)` → `{stale, refresh(guardFn, cb)}` — stale-while-revalidate render pattern
    (see `routes.stats` ~2039 for the idiom).
  - `sheet(html, {cls})` → bottom-sheet/modal. `toast(msg)` → transient toast.
  - `esc(str)` → HTML-escape (ALWAYS escape user/text content).
  - `I` → icon set (object of inline-SVG strings, e.g. `I.chevR`, `I.edit`, `I.eye`).
  - `skRows(n)` / skeleton classes for loading states.
- **Navigation:** links are `<a href="#/route">`. Active state keyed by `data-r`.

## 4. Design system — the Marquee identity ("modern dark cinema")

Defined in `static/app.css :root` (read it). Use the tokens; never hardcode hex.
- **Palette:** `--bg:#0f0d0a` `--panel:#17140f` `--panel-2:#1f1a13` `--line/-2` borders;
  ink `--ink:#f2ecdf` `--ink-2:#b3a88f` `--mut:#7c7360`; **accent amber** `--amber:#f0b544`
  `--amber-2:#ffd98a` `--amber-soft` (tint); one secondary `--velvet:#b0404f` (used sparingly,
  e.g. notification dot).
- **Type:** display `--disp:'Limelight'` (used ONLY for the wordmark & big moments — it's an
  all-caps decorative face, do not set body copy in it); body `--body:'Archivo'`. Both are
  local `@font-face` woff2 in `static/fonts/` — no new webfonts (CSP/offline).
- **Shape:** `--r:16px` cards, `--r-s:11px`; `--shadow` for lift. Rounded, soft, warm-dark.
- **Feel:** cinematic, warm near-black grounds, amber as the single spend of boldness,
  generous spacing, real dataviz (SVG). Mobile-first PWA (bottom tab bar under 700px;
  desktop nav above). **Avoid the generic-AI look** (no cream+terracotta, no acid-green
  pop, no purple gradient, no emoji section headers, no everything-centered). Match what's
  already there — open the app's existing screens (home/show/stats) as your reference.
- **Numbers/charts:** `font-variant-numeric: tabular-nums`; give charts an axis/grid, an
  area fill, an emphasized endpoint. Existing stat charts live in `renderStats()` (~1937)
  and `.chart` CSS — study them (the maintainer already flagged the current stats as
  "ugly and hard to read", so raise the bar).

## 5. Testing (best-effort — the maintainer does final integration on deploy)

- **Always** run syntax checks before committing:
  `python3 -m py_compile main.py` and `node --check static/app.js`.
- **Frontend render (preferred if feasible):** create a venv, `pip install fastapi uvicorn
  httpx pywebpush cryptography`, run `uvicorn main:app --port 8099` against a **throwaway**
  local sqlite (a fresh empty DB is created automatically; it is NOT the live DB). Register
  a test account via the UI or seed a few fake rows into the local DB to exercise your
  screen, then screenshot with Playwright (`~/.claude` may have it; else
  `pip install playwright && playwright install chromium`). External calls (TMDB) will fail
  without a token — seed fake data or stub. If network/deps are unavailable, fall back to a
  standalone static HTML mock of your component styled with the real tokens, Playwright it,
  and note in the PR that live integration is pending the maintainer's deploy.
- Do **not** treat inability to fully run the app as a blocker — correct, convention-matching
  code + a genuine `/frontend-design` pass + syntax-clean is the deliverable.

## 6. Delivery workflow (do this at the end)

This repo is **local only** (no GitHub remote). Your branch + worktree IS your "PR": the
orchestrator reviews your branch diff, merges it, and deploys. So:

```bash
cd <your worktree>
python3 -m py_compile main.py && node --check static/app.js   # must pass
git add -A
git commit -m "<clear, descriptive message>"
# do NOT push (no remote); do NOT merge to main yourself. Just commit on your branch.
git log --oneline -1
```
Then your **final message back to the orchestrator** (this is the review handoff — keep it
tight but complete) must include:
- **Branch name** and one-line summary.
- **What changed**: files touched + notable new functions / endpoints / tables / columns.
- **Integration contract** you exposed or rely on (e.g. `window.renderProfileLists`).
- **Screenshots** (paths) if you produced any, or one line on why not.
- **Deploy/verify notes**: anything the maintainer must know (new deps? BUILD bumped? a
  migration that runs on first boot? a manual step?).
- **Known gaps / TODO** you didn't finish.
