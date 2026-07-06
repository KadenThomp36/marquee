# Marquee

Self-hosted household media tracker (TV / movies / anime). A TV-Time replacement
for Kaden's household, running in Proxmox **LXC CT 130** at `192.168.10.67:8010`
(public via Tailscale Funnel at `https://marquee.tail2c61c0.ts.net`).

## Stack
- **Backend:** single-file FastAPI + stdlib `sqlite3` (WAL) — `main.py`
- **Frontend:** vanilla-JS SPA (hash routing, no framework) — `static/app.js` + `static/app.css`
- **Serving:** uvicorn on port 8010 via systemd unit `marquee`
- **PWA:** service worker at `static/sw.js` (network-first HTML, SWR for `?v=` assets)

## Deploy (production, done by the maintainer only)
Files are pushed to `/opt/marquee` on CT 130 and the service restarted:
```
pct push 130 main.py /opt/marquee/main.py
pct push 130 static/app.js /opt/marquee/static/app.js   # etc.
pct exec 130 -- systemctl restart marquee
```
Secrets (TMDB/Overseerr/Plex tokens, VAPID keys) live in the DB `settings` table on
CT 130 — **never** in code. The live DB is production household data; never reset it.

## Build versioning
`BUILD` is duplicated in `main.py`, `static/app.js`, and `static/index.html` (`?v=`).
Bump all three on any frontend change so PWA clients auto-refresh.

See `AGENT_BRIEF.md` for how contributor agents should work in this repo.
