# Marquee

Self-hosted household media tracker (TV / movies / anime). A TV-Time replacement
for Kaden's household, running in a Proxmox LXC
(published via Tailscale Funnel).

## Stack
- **Backend:** single-file FastAPI + stdlib `sqlite3` (WAL) — `main.py`
- **Frontend:** vanilla-JS SPA (hash routing, no framework) — `static/app.js` + `static/app.css`
- **Serving:** uvicorn on port 8010 via systemd unit `marquee`
- **PWA:** service worker at `static/sw.js` (network-first HTML, SWR for `?v=` assets)

## Deploy (production, done by the maintainer only)
Files are pushed to `/opt/marquee` on the container and the service restarted:
```
pct push <ct-id> main.py /opt/marquee/main.py
pct push <ct-id> static/app.js /opt/marquee/static/app.js   # etc.
pct exec <ct-id> -- systemctl restart marquee
```
Secrets (TMDB/Overseerr/Plex tokens, VAPID keys) live in the DB `settings` table on the container
— **never** in code. The live DB is production household data; never reset it.

## Build versioning
`BUILD` is duplicated in `main.py`, `static/app.js`, and `static/index.html` (`?v=`).
Bump all three on any frontend change so PWA clients auto-refresh.

See `AGENT_BRIEF.md` for how contributor agents should work in this repo.
