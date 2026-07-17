#!/usr/bin/env python3
"""Marquee — self-hosted episode tracker (TV Time style) for the Thompson homelab."""
import base64
import hashlib
import json
import logging
import os
import re
import secrets
import sqlite3
import threading
import time
import zipfile
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
from io import BytesIO

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, UploadFile
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

log = logging.getLogger("marquee")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

try:   # web push is optional — degrade to in-app-only if the libs aren't present
    from pywebpush import webpush, WebPushException
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import serialization as _cser
    PUSH_OK = True
except ImportError:
    PUSH_OK = False
VAPID_SUB = "mailto:kadenthomp36@gmail.com"

BUILD = "20260717c"   # bump on every frontend deploy; clients auto-refresh when it changes
DATA = os.environ.get("MARQUEE_DATA", "/opt/marquee/data")
STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
DB_PATH = os.path.join(DATA, "marquee.db")
os.makedirs(DATA, exist_ok=True)

STALE_DAYS = 30          # TV Time-ish: no watch in a month -> "haven't watched for a while"
SESSION_DAYS = 365

# ---------------------------------------------------------------- db

SCHEMA = """
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY, username TEXT UNIQUE NOT NULL, pass TEXT NOT NULL,
  is_admin INTEGER DEFAULT 0, plex_username TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY, user_id INTEGER, created_at TEXT);
CREATE TABLE IF NOT EXISTS shows(
  id INTEGER PRIMARY KEY, title TEXT, poster TEXT, backdrop TEXT, year INTEGER,
  status TEXT, genres TEXT, avg_runtime INTEGER, last_refreshed TEXT);
CREATE TABLE IF NOT EXISTS episodes(
  show_id INTEGER, season INTEGER, number INTEGER, title TEXT, air_date TEXT, runtime INTEGER,
  overview TEXT, still TEXT,
  PRIMARY KEY(show_id, season, number));
CREATE TABLE IF NOT EXISTS follows(
  user_id INTEGER, show_id INTEGER, added_at TEXT, archived INTEGER DEFAULT 0, rating INTEGER,
  PRIMARY KEY(user_id, show_id));
CREATE TABLE IF NOT EXISTS watches(
  user_id INTEGER, show_id INTEGER, season INTEGER, number INTEGER, watched_at TEXT,
  PRIMARY KEY(user_id, show_id, season, number));
CREATE TABLE IF NOT EXISTS movies(
  id INTEGER PRIMARY KEY, title TEXT, poster TEXT, year INTEGER,
  release_date TEXT, runtime INTEGER, genres TEXT);
CREATE TABLE IF NOT EXISTS movie_states(
  user_id INTEGER, movie_id INTEGER, state TEXT, watched_at TEXT, rating INTEGER,
  PRIMARY KEY(user_id, movie_id));
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS lists(
  id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT, is_default INTEGER DEFAULT 0, created_at TEXT);
CREATE TABLE IF NOT EXISTS list_items(
  list_id INTEGER, item_type TEXT, item_id INTEGER, added_at TEXT,
  PRIMARY KEY(list_id, item_type, item_id));
CREATE TABLE IF NOT EXISTS list_shares(
  list_id INTEGER, user_id INTEGER, PRIMARY KEY(list_id, user_id));
CREATE TABLE IF NOT EXISTS reviews(
  id INTEGER PRIMARY KEY, user_id INTEGER, item_type TEXT, item_id INTEGER,
  rating INTEGER, body TEXT, created_at TEXT, updated_at TEXT,
  UNIQUE(user_id, item_type, item_id));
CREATE TABLE IF NOT EXISTS review_replies(
  id INTEGER PRIMARY KEY, review_id INTEGER, user_id INTEGER, body TEXT, created_at TEXT);
CREATE INDEX IF NOT EXISTS idx_replies_review ON review_replies(review_id);
CREATE TABLE IF NOT EXISTS notifications(
  id INTEGER PRIMARY KEY, user_id INTEGER, type TEXT, title TEXT, body TEXT,
  link TEXT, created_at TEXT, read_at TEXT);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, id);
CREATE TABLE IF NOT EXISTS notif_prefs(
  user_id INTEGER, type TEXT, enabled INTEGER DEFAULT 0, value TEXT, PRIMARY KEY(user_id, type));
CREATE TABLE IF NOT EXISTS notif_sent(
  user_id INTEGER, dedup TEXT, created_at TEXT, PRIMARY KEY(user_id, dedup));
CREATE TABLE IF NOT EXISTS push_subscriptions(
  id INTEGER PRIMARY KEY, user_id INTEGER, endpoint TEXT UNIQUE, p256dh TEXT, auth TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS favorites(
  user_id INTEGER, item_type TEXT, item_id INTEGER, position INTEGER, created_at TEXT,
  PRIMARY KEY(user_id, item_type, item_id));
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id, position);
CREATE TABLE IF NOT EXISTS recap_seen(
  user_id INTEGER, year INTEGER, seen_at TEXT, PRIMARY KEY(user_id, year));
CREATE INDEX IF NOT EXISTS idx_push_user ON push_subscriptions(user_id);
CREATE TABLE IF NOT EXISTS watch_providers(
  item_type TEXT, item_id INTEGER, region TEXT DEFAULT 'US',
  data TEXT, fetched_at TEXT, PRIMARY KEY(item_type, item_id, region));
CREATE INDEX IF NOT EXISTS idx_watches_user ON watches(user_id, watched_at);
CREATE INDEX IF NOT EXISTS idx_eps_show ON episodes(show_id, air_date);
CREATE INDEX IF NOT EXISTS idx_reviews_item ON reviews(item_type, item_id);
CREATE INDEX IF NOT EXISTS idx_listitems ON list_items(list_id);
"""


def ensure_default_list(con, uid):
    r = con.execute("SELECT id FROM lists WHERE user_id=? AND is_default=1", (uid,)).fetchone()
    if r:
        return r["id"]
    cur = con.execute("INSERT INTO lists(user_id,name,is_default,created_at) VALUES(?,?,1,?)",
                      (uid, "Want to Watch", datetime.utcnow().isoformat()))
    return cur.lastrowid


@contextmanager
def db():
    con = sqlite3.connect(DB_PATH, timeout=30)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    try:
        yield con
        con.commit()
    finally:
        con.close()


def setting(con, key, default=None):
    r = con.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return r["value"] if r else default


def hash_pw(pw, salt=None):
    salt = salt or secrets.token_hex(8)
    h = hashlib.scrypt(pw.encode(), salt=salt.encode(), n=16384, r=8, p=1).hex()
    return f"{salt}${h}"


def check_pw(pw, stored):
    salt, _ = stored.split("$", 1)
    return secrets.compare_digest(hash_pw(pw, salt), stored)


# ---------------------------------------------------------------- tmdb

TMDB = "https://api.themoviedb.org/3"
IMG = "https://image.tmdb.org/t/p"
_tmdb_lock = threading.Lock()


def tmdb(path, **params):
    with db() as con:
        token = setting(con, "tmdb_token") or os.environ.get("TMDB_TOKEN", "")
    with _tmdb_lock:
        time.sleep(0.02)
    for attempt in range(4):
        try:
            r = httpx.get(f"{TMDB}{path}", params=params, timeout=30,
                          headers={"Authorization": f"Bearer {token}"})
            if r.status_code == 404:
                return None
            if r.status_code == 429:
                time.sleep(2 + attempt * 2)
                continue
            r.raise_for_status()
            return r.json()
        except httpx.HTTPError:
            if attempt == 3:
                raise
            time.sleep(1 + attempt)
    return None


def img(path, size="w342"):
    return f"{IMG}/{size}{path}" if path else None


def upsert_show(con, tmdb_id, fetch_episodes=True):
    """Fetch a show + all episodes from TMDB into the catalog."""
    d = tmdb(f"/tv/{tmdb_id}", append_to_response="credits,content_ratings,external_ids")
    if not d:
        return None
    ratings = {c["iso_3166_1"]: c["rating"] for c in
               (d.get("content_ratings") or {}).get("results", []) if c.get("rating")}
    details = {
        "overview": d.get("overview"), "tagline": d.get("tagline"),
        "vote": round(d.get("vote_average") or 0, 1), "votes": d.get("vote_count"),
        "first_air": d.get("first_air_date"), "last_air": d.get("last_air_date"),
        "networks": [n["name"] for n in (d.get("networks") or [])][:3],
        "created_by": [c["name"] for c in (d.get("created_by") or [])][:4],
        "content_rating": ratings.get("US") or next(iter(ratings.values()), None),
        "imdb_id": (d.get("external_ids") or {}).get("imdb_id"),
        "origin": ",".join(d.get("origin_country") or []),
        "language": d.get("original_language"),
        "n_seasons": d.get("number_of_seasons"), "n_episodes": d.get("number_of_episodes"),
        "cast": [{"id": c["id"], "name": c["name"], "character": c.get("character"),
                  "img": img(c.get("profile_path"), "w185")}
                 for c in ((d.get("credits") or {}).get("cast") or [])[:14]],
        "season_names": {str(s["season_number"]): s["name"] for s in d.get("seasons", [])
                         if s.get("name") and s["name"] != f"Season {s['season_number']}"},
        "season_posters": {str(s["season_number"]): img(s.get("poster_path")) for s in d.get("seasons", [])
                           if s.get("poster_path")},
    }
    con.execute("""INSERT INTO shows(id,title,poster,backdrop,year,status,genres,avg_runtime,last_refreshed,details)
        VALUES(?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET title=excluded.title, poster=excluded.poster,
          backdrop=excluded.backdrop, year=excluded.year, status=excluded.status,
          genres=excluded.genres, avg_runtime=excluded.avg_runtime,
          last_refreshed=excluded.last_refreshed, details=excluded.details""",
        (tmdb_id, d.get("name"), img(d.get("poster_path")), img(d.get("backdrop_path"), "w780"),
         int(d["first_air_date"][:4]) if d.get("first_air_date") else None,
         d.get("status"), ",".join(g["name"] for g in d.get("genres", [])),
         (d.get("episode_run_time") or [30])[0] if d.get("episode_run_time") else 30,
         datetime.utcnow().isoformat(), json.dumps(details)))
    if fetch_episodes:
        for s in d.get("seasons", []):
            sd = tmdb(f"/tv/{tmdb_id}/season/{s['season_number']}")
            if not sd:
                continue
            for e in sd.get("episodes", []):
                # canonical TMDB data always wins; a matching custom placeholder
                # is converted to a tmdb row (watches keyed by number are unaffected)
                con.execute("""INSERT INTO episodes(show_id,season,number,title,air_date,runtime,overview,still,rating,source)
                    VALUES(?,?,?,?,?,?,?,?,?,'tmdb')
                    ON CONFLICT(show_id,season,number) DO UPDATE SET
                      title=excluded.title, air_date=excluded.air_date, runtime=excluded.runtime,
                      overview=excluded.overview, still=excluded.still, rating=excluded.rating, source='tmdb'""",
                    (tmdb_id, e["season_number"], e["episode_number"], e.get("name"),
                     e.get("air_date"), e.get("runtime"), e.get("overview"),
                     img(e.get("still_path"), "w500"), round(e.get("vote_average") or 0, 1) or None))
    return d


def movie_details_json(d):
    """Compact JSON of the richer bits we keep for stats (studios/countries/people)."""
    credits = d.get("credits") or {}
    crew = credits.get("crew") or []
    return json.dumps({
        "companies": [c["name"] for c in (d.get("production_companies") or [])][:4],
        "countries": [c["iso_3166_1"] for c in (d.get("production_countries") or []) if c.get("iso_3166_1")],
        "directors": [c["name"] for c in crew if c.get("job") == "Director"][:3],
        "cast": [{"id": c["id"], "name": c["name"], "img": img(c.get("profile_path"), "w185")}
                 for c in (credits.get("cast") or [])[:10]],
    })


def upsert_movie(con, tmdb_id):
    d = tmdb(f"/movie/{tmdb_id}", append_to_response="credits")
    if not d:
        return None
    con.execute("""INSERT INTO movies(id,title,poster,year,release_date,runtime,genres,details)
        VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET title=excluded.title, poster=excluded.poster,
          year=excluded.year, release_date=excluded.release_date, runtime=excluded.runtime,
          genres=excluded.genres, details=excluded.details""",
        (tmdb_id, d.get("title"), img(d.get("poster_path")),
         int(d["release_date"][:4]) if d.get("release_date") else None,
         d.get("release_date"), d.get("runtime"), ",".join(g["name"] for g in d.get("genres", [])),
         movie_details_json(d)))
    return d


def backfill_movie_details(con, ids, cap=8):
    """Populate movies.details for up to `cap` already-watched movies that lack it.
    Best-effort + bounded so the advanced-stats endpoint stays responsive; studios /
    movie-people / movie-countries therefore fill in progressively over repeat visits."""
    if not (setting(con, "tmdb_token") or os.environ.get("TMDB_TOKEN")):
        return
    todo = [i for i in ids if con.execute(
        "SELECT 1 FROM movies WHERE id=? AND details IS NULL", (i,)).fetchone()]
    for mid in todo[:cap]:
        try:
            d = tmdb(f"/movie/{mid}", append_to_response="credits")
            if d:
                con.execute("UPDATE movies SET details=? WHERE id=?", (movie_details_json(d), mid))
        except Exception:
            pass


# ---------------------------------------------------------------- app + auth

app = FastAPI(title="Marquee", docs_url=None, redoc_url=None)
app.add_middleware(GZipMiddleware, minimum_size=500)


@app.middleware("http")
async def no_cache_assets(request: Request, call_next):
    resp = await call_next(request)
    p = request.url.path
    if p.endswith((".js", ".css")) or p == "/" or p.endswith(".html"):
        resp.headers["Cache-Control"] = "no-cache, must-revalidate"
    return resp


def current_user(request: Request):
    tok = request.cookies.get("sid")
    if not tok:
        raise HTTPException(401, "not logged in")
    with db() as con:
        r = con.execute("""SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id
                           WHERE s.token=?""", (tok,)).fetchone()
        if not r:
            raise HTTPException(401, "session expired")
        return dict(r)


def admin_user(user=Depends(current_user)):
    if not user["is_admin"]:
        raise HTTPException(403, "admin only")
    return user


@app.post("/api/login")
async def login(request: Request, response: Response):
    body = await request.json()
    with db() as con:
        u = con.execute("SELECT * FROM users WHERE username=? COLLATE NOCASE",
                        (body.get("username", "").strip(),)).fetchone()
        if not u or not check_pw(body.get("password", ""), u["pass"]):
            raise HTTPException(401, "wrong username or password")
        tok = secrets.token_urlsafe(32)
        con.execute("INSERT INTO sessions(token,user_id,created_at) VALUES(?,?,?)",
                    (tok, u["id"], datetime.utcnow().isoformat()))
    response.set_cookie("sid", tok, max_age=86400 * SESSION_DAYS, httponly=True, samesite="lax")
    return {"username": u["username"], "is_admin": bool(u["is_admin"])}


@app.post("/api/logout")
def logout(request: Request, response: Response):
    tok = request.cookies.get("sid")
    if tok:
        with db() as con:
            con.execute("DELETE FROM sessions WHERE token=?", (tok,))
    response.delete_cookie("sid")
    return {"ok": True}


@app.get("/api/signup_open")
def signup_open():
    with db() as con:
        closed = setting(con, "registration_closed") == "1"
        first = con.execute("SELECT COUNT(*) c FROM users").fetchone()["c"] == 0
    return {"open": first or not closed}


@app.post("/api/register")
async def register(request: Request, response: Response):
    body = await request.json()
    username = (body.get("username") or "").strip()
    password = body.get("password") or ""
    if len(username) < 2 or len(password) < 4:
        raise HTTPException(400, "username (2+) and password (4+) required")
    with db() as con:
        first = con.execute("SELECT COUNT(*) c FROM users").fetchone()["c"] == 0
        if not first and setting(con, "registration_closed") == "1":
            raise HTTPException(403, "sign-ups are closed — ask the owner for an account")
        if con.execute("SELECT 1 FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone():
            raise HTTPException(409, "that username is taken")
        cur = con.execute("""INSERT INTO users(username,pass,is_admin,created_at)
            VALUES(?,?,?,?)""", (username, hash_pw(password), 1 if first else 0,
                                 datetime.utcnow().isoformat()))
        uid = cur.lastrowid
        ensure_default_list(con, uid)
        tok = secrets.token_urlsafe(32)
        con.execute("INSERT INTO sessions(token,user_id,created_at) VALUES(?,?,?)",
                    (tok, uid, datetime.utcnow().isoformat()))
    response.set_cookie("sid", tok, max_age=86400 * SESSION_DAYS, httponly=True, samesite="lax")
    return {"username": username, "is_admin": first}


def user_public(u):
    return {"id": u["id"], "username": u["username"],
            "display_name": (u["display_name"] if "display_name" in u.keys() else None) or u["username"],
            "avatar": (u["avatar"] if "avatar" in u.keys() else None),
            "banner": (u["banner"] if "banner" in u.keys() else None)}


@app.get("/api/me")
def me(user=Depends(current_user)):
    with db() as con:
        u = con.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone()
    return {**user_public(u), "is_admin": bool(user["is_admin"])}


def headline_counts(con, uid):
    """Cheap identity numbers for the profile hero (no full stats needed)."""
    eps = con.execute("SELECT COUNT(*) c FROM watches WHERE user_id=?", (uid,)).fetchone()["c"]
    shows = con.execute("SELECT COUNT(*) c FROM follows WHERE user_id=?", (uid,)).fetchone()["c"]
    movs = con.execute("SELECT COUNT(*) c FROM movie_states WHERE user_id=? AND state='watched'",
                       (uid,)).fetchone()["c"]
    tvm = con.execute("""SELECT COALESCE(SUM(COALESCE(e.runtime, s.avg_runtime, 30)),0) m
        FROM watches w JOIN shows s ON s.id=w.show_id
        LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
        WHERE w.user_id=?""", (uid,)).fetchone()["m"]
    mvm = con.execute("""SELECT COALESCE(SUM(COALESCE(m.runtime,110)),0) m FROM movie_states ms
        JOIN movies m ON m.id=ms.movie_id WHERE ms.user_id=? AND ms.state='watched'""",
        (uid,)).fetchone()["m"]
    return {"episodes": eps, "shows": shows, "movies": movs, "hours": round((tvm + mvm) / 60)}


def fav_row(con, r):
    tbl = "shows" if r["item_type"] == "show" else "movies"
    s = con.execute(f"SELECT id,title,poster,year FROM {tbl} WHERE id=?", (r["item_id"],)).fetchone()
    if not s:
        return None
    return {"type": r["item_type"], "id": s["id"], "title": s["title"],
            "poster": s["poster"], "year": s["year"], "position": r["position"]}


def get_favorites(con, uid):
    rows = con.execute("""SELECT item_type,item_id,position FROM favorites
        WHERE user_id=? ORDER BY position, created_at""", (uid,)).fetchall()
    return [x for x in (fav_row(con, r) for r in rows) if x]


def profile_payload(con, u, viewer_id):
    is_me = u["id"] == viewer_id
    cy = datetime.now().year
    recap_soon = False
    if is_me and not recap_year_unlocked(cy):
        recap_soon = bool(
            con.execute("SELECT 1 FROM watches WHERE user_id=? AND substr(watched_at,1,4)=? LIMIT 1",
                        (u["id"], str(cy))).fetchone()
            or con.execute("SELECT 1 FROM movie_states WHERE user_id=? AND state='watched' "
                           "AND substr(watched_at,1,4)=? LIMIT 1", (u["id"], str(cy))).fetchone())
    return {**user_public(u), "is_admin": bool(u["is_admin"]),
            "member_since": (u["created_at"] if "created_at" in u.keys() else None),
            "is_me": is_me,
            "headline": headline_counts(con, u["id"]),
            "favorites": get_favorites(con, u["id"]),
            "recap_years": available_recap_years(con, u["id"]),
            "recap_soon": recap_soon, "recap_year": cy}


def resolve_member(con, username):
    u = con.execute("SELECT * FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone()
    if not u:
        raise HTTPException(404, "no such member")
    return u


@app.get("/api/profile")
def get_profile(user=Depends(current_user)):
    with db() as con:
        u = con.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone()
        return profile_payload(con, u, user["id"])


@app.get("/api/members")
def members(user=Depends(current_user)):
    with db() as con:
        rows = con.execute("""SELECT id,username,display_name,avatar,created_at FROM users
            ORDER BY created_at""").fetchall()
    return {"members": [{"id": r["id"], "username": r["username"],
                         "display_name": r["display_name"] or r["username"],
                         "avatar": r["avatar"], "is_me": r["id"] == user["id"]} for r in rows]}


@app.get("/api/profile/{username}")
def get_profile_public(username: str, user=Depends(current_user)):
    with db() as con:
        u = resolve_member(con, username)
        return profile_payload(con, u, user["id"])


@app.get("/api/favorites")
def favorites_list(user=Depends(current_user)):
    with db() as con:
        return {"favorites": get_favorites(con, user["id"])}


@app.post("/api/favorites")
async def favorites_add(request: Request, user=Depends(current_user)):
    body = await request.json()
    it = body.get("item_type")
    if it not in ("show", "movie"):
        raise HTTPException(400, "item_type must be show or movie")
    iid = int(body.get("item_id"))
    with db() as con:
        if it == "show" and not con.execute("SELECT 1 FROM shows WHERE id=?", (iid,)).fetchone():
            if not upsert_show(con, iid, fetch_episodes=False):
                raise HTTPException(404, "not found on TMDB")
        if it == "movie" and not con.execute("SELECT 1 FROM movies WHERE id=?", (iid,)).fetchone():
            if not upsert_movie(con, iid):
                raise HTTPException(404, "not found on TMDB")
        n = con.execute("SELECT COALESCE(MAX(position),-1)+1 p FROM favorites WHERE user_id=?",
                        (user["id"],)).fetchone()["p"]
        con.execute("""INSERT OR IGNORE INTO favorites(user_id,item_type,item_id,position,created_at)
            VALUES(?,?,?,?,?)""", (user["id"], it, iid, n, datetime.utcnow().isoformat()))
        return {"favorites": get_favorites(con, user["id"])}


@app.delete("/api/favorites/{item_type}/{item_id}")
def favorites_remove(item_type: str, item_id: int, user=Depends(current_user)):
    with db() as con:
        con.execute("DELETE FROM favorites WHERE user_id=? AND item_type=? AND item_id=?",
                    (user["id"], item_type, item_id))
        return {"favorites": get_favorites(con, user["id"])}


@app.post("/api/favorites/reorder")
async def favorites_reorder(request: Request, user=Depends(current_user)):
    body = await request.json()
    for pos, pair in enumerate(body.get("order") or []):
        with db() as con:
            con.execute("""UPDATE favorites SET position=? WHERE user_id=? AND item_type=? AND item_id=?""",
                        (pos, user["id"], pair[0], int(pair[1])))
    with db() as con:
        return {"favorites": get_favorites(con, user["id"])}


@app.post("/api/profile")
async def update_profile(request: Request, user=Depends(current_user)):
    body = await request.json()
    with db() as con:
        if body.get("display_name") is not None:
            con.execute("UPDATE users SET display_name=? WHERE id=?",
                        (body["display_name"].strip() or None, user["id"]))
        if body.get("username"):
            un = body["username"].strip()
            if con.execute("SELECT 1 FROM users WHERE username=? COLLATE NOCASE AND id<>?",
                           (un, user["id"])).fetchone():
                raise HTTPException(409, "that username is taken")
            con.execute("UPDATE users SET username=? WHERE id=?", (un, user["id"]))
        if body.get("password"):
            if len(body["password"]) < 4:
                raise HTTPException(400, "password too short")
            con.execute("UPDATE users SET pass=? WHERE id=?",
                        (hash_pw(body["password"]), user["id"]))
    return {"ok": True}


@app.post("/api/profile/avatar")
async def upload_avatar(file: UploadFile, user=Depends(current_user)):
    data = await file.read()
    if len(data) > 3_000_000:
        raise HTTPException(413, "image too large (max 3MB)")
    ext = ".png"
    if file.content_type == "image/jpeg":
        ext = ".jpg"
    elif file.content_type == "image/webp":
        ext = ".webp"
    elif file.content_type not in ("image/png",):
        raise HTTPException(400, "png, jpg or webp only")
    fn = f"u{user['id']}{ext}"
    with open(os.path.join(DATA, "avatars", fn), "wb") as f:
        f.write(data)
    url = f"/avatars/{fn}?v={int(time.time())}"
    with db() as con:
        con.execute("UPDATE users SET avatar=? WHERE id=?", (url, user["id"]))
    return {"avatar": url}


@app.get("/avatars/{fn}")
def serve_avatar(fn: str):
    path = os.path.join(DATA, "avatars", os.path.basename(fn))
    if not os.path.exists(path):
        raise HTTPException(404)
    return FileResponse(path, headers={"Cache-Control": "public, max-age=3600"})


# ---- profile banner (custom upload OR a curated widescreen still from a watched show) ----

@app.get("/api/profile/banner/options")
def banner_options(user=Depends(current_user)):
    """Curated 16:9 backdrops drawn from the shows this user actually watches,
    most-watched first — the pick-a-banner grid."""
    with db() as con:
        rows = con.execute("""SELECT s.title, s.backdrop, COUNT(*) n
            FROM watches w JOIN shows s ON s.id=w.show_id
            WHERE w.user_id=? AND s.backdrop IS NOT NULL AND s.backdrop!=''
            GROUP BY s.id ORDER BY n DESC, s.title LIMIT 40""", (user["id"],)).fetchall()
    seen, out = set(), []
    for r in rows:
        if r["backdrop"] in seen:
            continue
        seen.add(r["backdrop"])
        out.append({"title": r["title"], "backdrop": r["backdrop"]})
    return {"options": out}


@app.post("/api/profile/banner")
async def set_banner(request: Request, user=Depends(current_user)):
    """Set the banner to a curated image URL, or clear it. Custom uploads use
    /api/profile/banner/upload."""
    body = await request.json()
    if body.get("clear"):
        banner = None
    else:
        url = (body.get("url") or "").strip()
        if not url.startswith("https://image.tmdb.org/"):
            raise HTTPException(400, "banner must be a TMDB image url")
        banner = url
    with db() as con:
        con.execute("UPDATE users SET banner=? WHERE id=?", (banner, user["id"]))
    return {"banner": banner}


@app.post("/api/profile/banner/upload")
async def upload_banner(file: UploadFile, user=Depends(current_user)):
    data = await file.read()
    if len(data) > 6_000_000:
        raise HTTPException(413, "image too large (max 6MB)")
    ext = {"image/jpeg": ".jpg", "image/webp": ".webp", "image/png": ".png"}.get(file.content_type)
    if not ext:
        raise HTTPException(400, "png, jpg or webp only")
    fn = f"b{user['id']}{ext}"
    with open(os.path.join(DATA, "banners", fn), "wb") as f:
        f.write(data)
    url = f"/banners/{fn}?v={int(time.time())}"
    with db() as con:
        con.execute("UPDATE users SET banner=? WHERE id=?", (url, user["id"]))
    return {"banner": url}


@app.get("/banners/{fn}")
def serve_banner(fn: str):
    path = os.path.join(DATA, "banners", os.path.basename(fn))
    if not os.path.exists(path):
        raise HTTPException(404)
    return FileResponse(path, headers={"Cache-Control": "public, max-age=3600"})


# ---------------------------------------------------------------- lists

def list_item_row(con, it, uid=None):
    """One list item. When uid is given, include the viewer's watch progress + dates so
    the list can show progress bars, an 'ended' badge, and offer watch-based sorting."""
    if it["item_type"] == "show":
        s = con.execute("SELECT id,title,poster,year,status FROM shows WHERE id=?", (it["item_id"],)).fetchone()
        if not s:
            return None
        row = {"type": "show", "id": s["id"], "title": s["title"], "poster": s["poster"],
               "year": s["year"], "added_at": it["added_at"],
               "ended": (s["status"] or "").lower() in ("ended", "canceled", "cancelled")}
        if uid is not None:
            row["total"] = con.execute(
                "SELECT COUNT(*) c FROM episodes WHERE show_id=? AND season>0", (s["id"],)).fetchone()["c"]
            w = con.execute("""SELECT COUNT(*) c, MIN(watched_at) f, MAX(watched_at) l
                FROM watches WHERE user_id=? AND show_id=?""", (uid, s["id"])).fetchone()
            f = con.execute("SELECT archived FROM follows WHERE user_id=? AND show_id=?",
                            (uid, s["id"])).fetchone()
            row.update({"watched": w["c"], "first_watched": w["f"], "last_watched": w["l"],
                        "archived": bool(f and f["archived"])})
        return row
    s = con.execute("SELECT id,title,poster,year FROM movies WHERE id=?", (it["item_id"],)).fetchone()
    if not s:
        return None
    row = {"type": "movie", "id": s["id"], "title": s["title"], "poster": s["poster"],
           "year": s["year"], "added_at": it["added_at"]}
    if uid is not None:
        st = con.execute("SELECT state, watched_at FROM movie_states WHERE user_id=? AND movie_id=?",
                         (uid, s["id"])).fetchone()
        seen = bool(st and st["state"] == "watched")
        row.update({"total": 1, "watched": 1 if seen else 0,
                    "first_watched": st["watched_at"] if seen else None,
                    "last_watched": st["watched_at"] if seen else None})
    return row


def list_visibility(row):
    """Read the (optionally-not-yet-migrated) visibility column, defaulting to private."""
    return (row["visibility"] if "visibility" in row.keys() else None) or "private"


def norm_vis(v):
    """Clamp a requested visibility to a known value. 'collab' = jointly-editable."""
    return v if v in ("private", "public", "collab") else "private"


# lists that other household members are allowed to *see*
SHARED_VIS = ("public", "collab")

# a shared list with no list_shares rows is shared with the whole household;
# with rows, only the listed members (plus the owner) may see it
AUDIENCE_SQL = """(NOT EXISTS(SELECT 1 FROM list_shares s WHERE s.list_id=l.id)
                   OR EXISTS(SELECT 1 FROM list_shares s WHERE s.list_id=l.id AND s.user_id=?))"""


def list_audience_ok(con, list_id, uid):
    """May uid see this shared list? Yes when it's household-wide (no explicit
    audience) or uid is on its share list."""
    rows = con.execute("SELECT user_id FROM list_shares WHERE list_id=?", (list_id,)).fetchall()
    return not rows or uid in {r["user_id"] for r in rows}


def set_list_shares(con, list_id, owner_id, shared_with):
    """Replace a list's explicit audience. None = leave untouched; [] = everyone."""
    if shared_with is None:
        return
    valid = {r["id"] for r in con.execute("SELECT id FROM users").fetchall()}
    ids = ({int(x) for x in shared_with} & valid) - {owner_id}
    con.execute("DELETE FROM list_shares WHERE list_id=?", (list_id,))
    con.executemany("INSERT INTO list_shares(list_id,user_id) VALUES(?,?)",
                    [(list_id, i) for i in sorted(ids)])


def list_card(con, r):
    """One list-card summary (name, count, up-to-4 cover posters, visibility) from a
    lists row that carries an `n` item-count column."""
    covers = con.execute("""SELECT item_type, item_id FROM list_items
        WHERE list_id=? ORDER BY added_at DESC LIMIT 4""", (r["id"],)).fetchall()
    posters = []
    for c in covers:
        tbl = "shows" if c["item_type"] == "show" else "movies"
        p = con.execute(f"SELECT poster FROM {tbl} WHERE id=?", (c["item_id"],)).fetchone()
        if p and p["poster"]:
            posters.append(p["poster"])
    return {"id": r["id"], "name": r["name"], "is_default": bool(r["is_default"]),
            "count": r["n"], "posters": posters, "visibility": list_visibility(r)}


def list_cards(con, uid, viewer=None):
    """One user's list cards. A different viewer only sees shared lists whose
    audience includes them."""
    q = ("""SELECT l.*, (SELECT COUNT(*) FROM list_items li WHERE li.list_id=l.id) n
            FROM lists l WHERE l.user_id=?""")
    args = [uid]
    if viewer is not None and viewer != uid:
        q += f" AND l.visibility IN ('public','collab') AND {AUDIENCE_SQL}"
        args.append(viewer)
    q += " ORDER BY l.is_default DESC, l.created_at"
    return [list_card(con, r) for r in con.execute(q, args).fetchall()]


def shared_list_cards(con, uid):
    """Other members' collab lists (whose audience includes uid) — jointly
    editable, so they appear in everyone's Lists tab."""
    rows = con.execute(f"""SELECT l.*, (SELECT COUNT(*) FROM list_items li WHERE li.list_id=l.id) n,
            (SELECT COALESCE(display_name, username) FROM users u WHERE u.id=l.user_id) owner
            FROM lists l WHERE l.user_id!=? AND l.visibility='collab' AND {AUDIENCE_SQL}
            ORDER BY l.created_at""", (uid, uid)).fetchall()
    return [dict(list_card(con, r), owner=r["owner"]) for r in rows]


@app.get("/api/lists")
def get_lists(user=Depends(current_user)):
    uid = user["id"]
    with db() as con:
        ensure_default_list(con, uid)
        out = list_cards(con, uid)
        shared = shared_list_cards(con, uid)
    return {"lists": out, "shared": shared}


@app.get("/api/user/{username}/lists")
def user_lists(username: str, user=Depends(current_user)):
    """A user's lists for their profile — all of them if it's you, else only the public ones."""
    with db() as con:
        u = con.execute("SELECT * FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone()
        if not u:
            raise HTTPException(404, "no such user")
        is_me = u["id"] == user["id"]
        if is_me:
            ensure_default_list(con, u["id"])
        out = list_cards(con, u["id"], viewer=user["id"])
    return {"user": user_public(u), "is_me": is_me, "lists": out}


@app.post("/api/lists")
async def create_list(request: Request, user=Depends(current_user)):
    body = await request.json()
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(400, "name required")
    visibility = norm_vis(body.get("visibility"))
    with db() as con:
        cur = con.execute("INSERT INTO lists(user_id,name,visibility,created_at) VALUES(?,?,?,?)",
                          (user["id"], name, visibility, datetime.utcnow().isoformat()))
        set_list_shares(con, cur.lastrowid, user["id"], body.get("shared_with"))
    return {"id": cur.lastrowid, "name": name, "visibility": visibility}


@app.post("/api/list/{list_id}/visibility")
async def set_list_visibility(list_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    visibility = norm_vis(body.get("visibility"))
    with db() as con:
        if not con.execute("SELECT 1 FROM lists WHERE id=? AND user_id=?",
                           (list_id, user["id"])).fetchone():
            raise HTTPException(404)
        con.execute("UPDATE lists SET visibility=? WHERE id=?", (visibility, list_id))
        set_list_shares(con, list_id, user["id"], body.get("shared_with"))
        shared = [r["user_id"] for r in con.execute(
            "SELECT user_id FROM list_shares WHERE list_id=?", (list_id,)).fetchall()]
    return {"ok": True, "visibility": visibility, "shared_with": shared}


@app.delete("/api/list/{list_id}")
def delete_list(list_id: int, user=Depends(current_user)):
    with db() as con:
        r = con.execute("SELECT is_default FROM lists WHERE id=? AND user_id=?",
                        (list_id, user["id"])).fetchone()
        if not r:
            raise HTTPException(404)
        if r["is_default"]:
            raise HTTPException(400, "can't delete the default list")
        con.execute("DELETE FROM list_items WHERE list_id=?", (list_id,))
        con.execute("DELETE FROM list_shares WHERE list_id=?", (list_id,))
        con.execute("DELETE FROM lists WHERE id=?", (list_id,))
    return {"ok": True}


@app.get("/api/list/{list_id}")
def get_list(list_id: int, user=Depends(current_user)):
    with db() as con:
        l = con.execute("SELECT * FROM lists WHERE id=?", (list_id,)).fetchone()
        if not l:
            raise HTTPException(404)
        visibility = list_visibility(l)
        is_owner = l["user_id"] == user["id"]
        # owner sees any of their lists; others may see shared (public/collab) ones
        # whose audience includes them (404 hides the rest)
        if not is_owner and (visibility not in SHARED_VIS
                             or not list_audience_ok(con, list_id, user["id"])):
            raise HTTPException(404)
        owner = con.execute("SELECT * FROM users WHERE id=?", (l["user_id"],)).fetchone()
        items = con.execute("SELECT * FROM list_items WHERE list_id=? ORDER BY added_at DESC",
                            (list_id,)).fetchall()
        out = [x for x in (list_item_row(con, it, user["id"]) for it in items) if x]
        shared_with = ([r["user_id"] for r in con.execute(
            "SELECT user_id FROM list_shares WHERE list_id=?", (list_id,)).fetchall()]
            if is_owner else None)
    # collab lists: any member in the audience can add/remove; only the owner can rename/delete/reshare
    can_edit = is_owner or visibility == "collab"
    return {"id": l["id"], "name": l["name"], "is_default": bool(l["is_default"]),
            "visibility": visibility, "is_owner": is_owner, "can_edit": can_edit,
            "shared_with": shared_with, "owner": user_public(owner), "items": out}


@app.post("/api/list/{list_id}/item")
async def list_item_toggle(list_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    it_type, it_id = body["item_type"], int(body["item_id"])
    with db() as con:
        l = con.execute("SELECT user_id, visibility FROM lists WHERE id=?", (list_id,)).fetchone()
        if not l:
            raise HTTPException(404)
        # owner always; on a collab list any member in its audience may add/remove
        if l["user_id"] != user["id"] and (list_visibility(l) != "collab"
                                           or not list_audience_ok(con, list_id, user["id"])):
            raise HTTPException(403, "not allowed to edit this list")
        if body.get("remove"):
            con.execute("DELETE FROM list_items WHERE list_id=? AND item_type=? AND item_id=?",
                        (list_id, it_type, it_id))
        else:
            if it_type == "show" and not con.execute("SELECT 1 FROM shows WHERE id=?", (it_id,)).fetchone():
                upsert_show(con, it_id)
            elif it_type == "movie" and not con.execute("SELECT 1 FROM movies WHERE id=?", (it_id,)).fetchone():
                upsert_movie(con, it_id)
            con.execute("""INSERT OR IGNORE INTO list_items(list_id,item_type,item_id,added_at)
                VALUES(?,?,?,?)""", (list_id, it_type, it_id, datetime.utcnow().isoformat()))
    return {"ok": True}


@app.get("/api/item/{item_type}/{item_id}/lists")
def item_lists(item_type: str, item_id: int, user=Depends(current_user)):
    """Which of my lists contain this item (for the add-to-list menu)."""
    with db() as con:
        ensure_default_list(con, user["id"])
        rows = con.execute(f"""SELECT l.id, l.name, l.is_default, l.user_id, l.visibility,
            (SELECT 1 FROM list_items li WHERE li.list_id=l.id AND li.item_type=? AND li.item_id=?) has,
            (SELECT COALESCE(display_name, username) FROM users u WHERE u.id=l.user_id) owner
            FROM lists l WHERE l.user_id=? OR (l.visibility='collab' AND {AUDIENCE_SQL})
            ORDER BY (l.user_id!=?), l.is_default DESC, l.created_at""",
            (item_type, item_id, user["id"], user["id"], user["id"])).fetchall()
    out = []
    for r in rows:
        mine = r["user_id"] == user["id"]
        out.append({"id": r["id"], "name": r["name"], "is_default": bool(r["is_default"]),
                    "has": bool(r["has"]), "collab": not mine,
                    "owner": None if mine else r["owner"]})
    return {"lists": out}


# ---------------------------------------------------------------- external community reviews

_trakt_id_cache = {}
_ext_cache = {}


def trakt_get(path, **params):
    with db() as con:
        cid = setting(con, "trakt_client_id")
    if not cid:
        return None
    try:
        r = httpx.get(f"https://api.trakt.tv{path}", params=params,
                      headers={"trakt-api-version": "2", "trakt-api-key": cid,
                               "User-Agent": "marquee/1.0"}, timeout=15)
        if r.status_code != 200:
            return None
        return r.json()
    except httpx.HTTPError:
        return None


def trakt_id_for(tmdb_id, kind):
    key = (tmdb_id, kind)
    if key in _trakt_id_cache:
        return _trakt_id_cache[key]
    res = trakt_get(f"/search/tmdb/{tmdb_id}", type="show" if kind == "tv" else "movie")
    tid = None
    if res:
        node = res[0].get("show" if kind == "tv" else "movie", {})
        tid = node.get("ids", {}).get("trakt")
    _trakt_id_cache[key] = tid
    return tid


def trakt_comments(url_path, limit):
    out = []
    seen = set()
    for sort in ("likes", "newest"):
        cs = trakt_get(f"{url_path}/{sort}", limit=limit, extended="full") or []
        for c in cs:
            cid = c.get("id")
            if cid in seen or not c.get("comment") or c.get("spoiler"):
                continue
            seen.add(cid)
            out.append({"source": "Trakt", "author": c["user"]["username"],
                        "rating": c.get("user_rating"), "likes": c.get("likes", 0),
                        "body": c["comment"][:1400], "date": (c.get("created_at") or "")[:10]})
    return out


def show_is_anime(show_id):
    with db() as con:
        r = con.execute("SELECT genres, details FROM shows WHERE id=?", (show_id,)).fetchone()
    if not r:
        return None
    genres = (r["genres"] or "")
    origin = ""
    try:
        origin = (json.loads(r["details"] or "{}") or {}).get("origin", "")
    except (json.JSONDecodeError, TypeError):
        pass
    is_anime = "Animation" in genres and ("JP" in origin or not origin)
    with db() as con:
        title = con.execute("SELECT title FROM shows WHERE id=?", (show_id,)).fetchone()
    return (title["title"] if title else None) if is_anime else None


def mal_reviews(title):
    """MyAnimeList reviews via the free Jikan API — graceful on outage/rate-limit."""
    if not title:
        return []
    try:
        s = httpx.get("https://api.jikan.moe/v4/anime",
                      params={"q": title, "limit": 1, "sfw": "true"}, timeout=6)
        if s.status_code != 200 or not s.json().get("data"):
            return []
        mid = s.json()["data"][0]["mal_id"]
        rv = httpx.get(f"https://api.jikan.moe/v4/anime/{mid}/reviews", timeout=6)
        if rv.status_code != 200:
            return []
        out = []
        for r in (rv.json().get("data") or [])[:6]:
            out.append({"source": "MyAnimeList", "author": (r.get("user") or {}).get("username"),
                        "rating": r.get("score"), "likes": (r.get("reactions") or {}).get("overall", 0),
                        "body": (r.get("review") or "")[:1400], "date": (r.get("date") or "")[:10]})
        return out
    except httpx.HTTPError:
        return []


@app.get("/api/external_reviews/{item_type}/{item_id}")
def external_reviews(item_type: str, item_id: int, user=Depends(current_user)):
    ck = f"{item_type}:{item_id}"
    hit = _ext_cache.get(ck)
    if hit and time.time() - hit[0] < 43200:
        return hit[1]
    out = []
    if item_type == "episode":
        show_id = item_id // 1000000
        season = (item_id % 1000000) // 1000
        number = item_id % 1000
        tid = trakt_id_for(show_id, "tv")
        if tid:
            out += trakt_comments(f"/shows/{tid}/seasons/{season}/episodes/{number}/comments", 25)
    else:
        kind = "tv" if item_type == "show" else "movie"
        tid = trakt_id_for(item_id, kind)
        if tid:
            out += trakt_comments(f"/{'shows' if kind == 'tv' else 'movies'}/{tid}/comments", 25)
        tmdb_r = tmdb(f"/{kind}/{item_id}/reviews") or {}
        for r in (tmdb_r.get("results") or [])[:10]:
            out.append({"source": "TMDB", "author": r.get("author"),
                        "rating": (r.get("author_details") or {}).get("rating"), "likes": 0,
                        "body": (r.get("content") or "")[:1400], "date": (r.get("created_at") or "")[:10]})
        if kind == "tv":
            out += mal_reviews(show_is_anime(item_id))
    out.sort(key=lambda x: x.get("likes", 0), reverse=True)
    data = {"reviews": out[:40]}
    _ext_cache[ck] = (time.time(), data)
    return data


# ---------------------------------------------------------------- reviews (shared)

def _person(row):
    return {"username": row["username"],
            "display_name": row["display_name"] or row["username"], "avatar": row["avatar"]}


@app.get("/api/reviews/{item_type}/{item_id}")
def get_reviews(item_type: str, item_id: int, user=Depends(current_user)):
    with db() as con:
        rows = con.execute("""SELECT r.*, u.username, u.display_name, u.avatar
            FROM reviews r JOIN users u ON u.id=r.user_id
            WHERE r.item_type=? AND r.item_id=? ORDER BY r.updated_at DESC""",
            (item_type, item_id)).fetchall()
        replies_by = {}
        ids = [r["id"] for r in rows]
        if ids:
            ph = ",".join("?" * len(ids))
            for x in con.execute(f"""SELECT rr.*, u.username, u.display_name, u.avatar
                FROM review_replies rr JOIN users u ON u.id=rr.user_id
                WHERE rr.review_id IN ({ph}) ORDER BY rr.created_at ASC""", ids).fetchall():
                replies_by.setdefault(x["review_id"], []).append(
                    {"id": x["id"], "body": x["body"], "created_at": x["created_at"],
                     "mine": x["user_id"] == user["id"], "author": _person(x)})
    reviews = [{"id": r["id"], "rating": r["rating"], "body": r["body"],
                "created_at": r["created_at"], "updated_at": r["updated_at"],
                "mine": r["user_id"] == user["id"], "author": _person(r),
                "replies": replies_by.get(r["id"], [])} for r in rows]
    return {"reviews": reviews}


@app.post("/api/reviews/{item_type}/{item_id}")
async def post_review(item_type: str, item_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    rating = body.get("rating")
    text = (body.get("body") or "").strip()
    if not text and not rating:
        raise HTTPException(400, "a rating or some words, please")
    now = datetime.utcnow().isoformat()
    with db() as con:
        is_new = not con.execute("SELECT 1 FROM reviews WHERE user_id=? AND item_type=? AND item_id=?",
                                 (user["id"], item_type, item_id)).fetchone()
        con.execute("""INSERT INTO reviews(user_id,item_type,item_id,rating,body,created_at,updated_at)
            VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(user_id,item_type,item_id) DO UPDATE SET
              rating=excluded.rating, body=excluded.body, updated_at=excluded.updated_at""",
            (user["id"], item_type, item_id, rating, text, now, now))
    if is_new:
        notify_new_review(item_type, item_id, user)
    return {"ok": True}


@app.delete("/api/review/{review_id}")
def delete_review(review_id: int, user=Depends(current_user)):
    with db() as con:
        con.execute("DELETE FROM reviews WHERE id=? AND user_id=?", (review_id, user["id"]))
        con.execute("DELETE FROM review_replies WHERE review_id=?", (review_id,))
    return {"ok": True}


@app.post("/api/review/{review_id}/reply")
async def post_reply(review_id: int, request: Request, user=Depends(current_user)):
    text = ((await request.json()).get("body") or "").strip()
    if not text:
        raise HTTPException(400, "write something")
    now = datetime.utcnow().isoformat()
    with db() as con:
        rv = con.execute("SELECT user_id, item_type, item_id FROM reviews WHERE id=?",
                         (review_id,)).fetchone()
        if not rv:
            raise HTTPException(404, "no such review")
        con.execute("INSERT INTO review_replies(review_id,user_id,body,created_at) VALUES(?,?,?,?)",
                    (review_id, user["id"], text, now))
    # notify the review author (and prior repliers) that someone replied — #21
    notify_reply(review_id, rv, user)
    return {"ok": True}


@app.delete("/api/reply/{reply_id}")
def delete_reply(reply_id: int, user=Depends(current_user)):
    with db() as con:
        con.execute("DELETE FROM review_replies WHERE id=? AND user_id=?", (reply_id, user["id"]))
    return {"ok": True}


# ---------------------------------------------------------------- notifications
def fmt_when(iso):
    try:
        return datetime.strptime(iso[:10], "%Y-%m-%d").strftime("%b %-d")
    except (ValueError, TypeError):
        return iso or ""


# (type, human label, help text, default value). All prefs default OFF per user.
NOTIF_TYPES = [
    ("reply",      "Replies to your reviews",      "When someone replies to a review or comment you wrote.", None),
    ("comment",    "New reviews on your watches",  "When someone reviews a show, movie or episode you've watched.", None),
    ("airing",     "New episode airing soon",      "Get a heads-up before a new episode of a show you follow — pick your timing below.", "1"),
    ("new_season", "A followed show returns",      "A new season of a show you follow gets a premiere date.", None),
    ("available",  "Your request is ready",        "A title you requested finishes downloading and is on Plex.", None),
    ("plex",       "Auto-tracked from Plex",       "Marquee marks something watched because you played it in Plex.", None),
]
NOTIF_DEFAULT = {t: dv for t, _, _, dv in NOTIF_TYPES}


def notif_pref(con, user_id, ntype):
    row = con.execute("SELECT enabled, value FROM notif_prefs WHERE user_id=? AND type=?",
                      (user_id, ntype)).fetchone()
    if not row:
        return (False, NOTIF_DEFAULT.get(ntype))
    return (bool(row["enabled"]), row["value"] if row["value"] is not None else NOTIF_DEFAULT.get(ntype))


def push_notif(con, user_id, ntype, title, body, link, dedup=None, seed=False):
    """Insert a notification if the user has this type enabled (and it's not a dupe).
    seed=True records the dedup marker WITHOUT notifying — used when a scan-based type is
    first enabled, so it never backfills alerts for items that already match."""
    if seed:
        if dedup:
            con.execute("INSERT OR IGNORE INTO notif_sent(user_id,dedup,created_at) VALUES(?,?,?)",
                        (user_id, dedup, datetime.utcnow().isoformat()))
        return False
    en, _ = notif_pref(con, user_id, ntype)
    if not en:
        return False
    if dedup and con.execute("SELECT 1 FROM notif_sent WHERE user_id=? AND dedup=?",
                             (user_id, dedup)).fetchone():
        return False
    now = datetime.utcnow().isoformat()
    con.execute("INSERT INTO notifications(user_id,type,title,body,link,created_at) VALUES(?,?,?,?,?,?)",
                (user_id, ntype, title, body, link, now))
    if dedup:
        con.execute("INSERT OR IGNORE INTO notif_sent(user_id,dedup,created_at) VALUES(?,?,?)",
                    (user_id, dedup, now))
    # also fire an OS-level push (non-blocking) to the user's installed devices
    threading.Thread(target=deliver_push, args=(user_id, title, body, link), daemon=True).start()
    return True


def review_link(item_type, item_id):
    if item_type == "episode":
        return f"show/{item_id // 1000000}/e/{(item_id % 1000000) // 1000}/{item_id % 1000}"
    return f"{'movie' if item_type == 'movie' else 'show'}/{item_id}"


def _actor_name(actor):
    return actor.get("display_name") or actor.get("username") or "Someone"


def notify_reply(review_id, rv, actor):
    """Someone replied — notify the review author and anyone else in the thread."""
    with db() as con:
        recips = set()
        if rv["user_id"] != actor["id"]:
            recips.add(rv["user_id"])
        for x in con.execute("SELECT DISTINCT user_id FROM review_replies WHERE review_id=?",
                             (review_id,)).fetchall():
            if x["user_id"] != actor["id"]:
                recips.add(x["user_id"])
        link, title = review_link(rv["item_type"], rv["item_id"]), f"{_actor_name(actor)} replied to a review"
        for uid in recips:
            push_notif(con, uid, "reply", title, "", link)


def notify_new_review(item_type, item_id, actor):
    """A new review was posted — notify others who have watched that item."""
    with db() as con:
        if item_type == "movie":
            rows = con.execute("SELECT DISTINCT user_id FROM movie_states WHERE movie_id=? AND state='watched'",
                               (item_id,)).fetchall()
        elif item_type == "episode":
            sh, se, nu = item_id // 1000000, (item_id % 1000000) // 1000, item_id % 1000
            rows = con.execute("SELECT DISTINCT user_id FROM watches WHERE show_id=? AND season=? AND number=?",
                               (sh, se, nu)).fetchall()
        else:
            rows = con.execute("SELECT DISTINCT user_id FROM watches WHERE show_id=?", (item_id,)).fetchall()
        link, title = review_link(item_type, item_id), f"{_actor_name(actor)} reviewed something you watched"
        for r in rows:
            if r["user_id"] != actor["id"]:
                push_notif(con, r["user_id"], "comment", title, "", link)


def notify_auto_tracked(con, new_watches):
    """Tell a user Marquee auto-marked things watched from Plex (grouped per show/movie)."""
    eps, movies = {}, []
    for uid, mtype, tid, s, n in new_watches:
        if mtype == "episode":
            eps.setdefault((uid, tid), []).append((s, n))
        else:
            movies.append((uid, tid))
    for (uid, show), lst in eps.items():
        row = con.execute("SELECT title FROM shows WHERE id=?", (show,)).fetchone()
        name = row["title"] if row else "a show"
        if len(lst) == 1:
            s, n = lst[0]
            push_notif(con, uid, "plex", f"Marked {name} S{s}E{n} watched — from Plex", "",
                       f"show/{show}/e/{s}/{n}")
        else:
            push_notif(con, uid, "plex", f"Marked {len(lst)} episodes of {name} watched — from Plex",
                       "", f"show/{show}")
    for uid, mid in movies:
        row = con.execute("SELECT title FROM movies WHERE id=?", (mid,)).fetchone()
        push_notif(con, uid, "plex", f"Marked {row['title'] if row else 'a movie'} watched — from Plex",
                   "", f"movie/{mid}")


def scan_airing(con):
    today_s = date.today().isoformat()
    soon = (date.today() + timedelta(days=14)).isoformat()   # premiere look-ahead window
    for f in con.execute("SELECT user_id, show_id FROM follows WHERE archived=0").fetchall():
        uid = f["user_id"]
        en, val = notif_pref(con, uid, "airing")
        ns_en, _ = notif_pref(con, uid, "new_season")
        if not en and not ns_en:
            continue
        sh = con.execute("SELECT title FROM shows WHERE id=?", (f["show_id"],)).fetchone()
        sname = sh["title"] if sh else "A show"
        if en:
            # `val` is a comma-separated set of lead times in days (0 = "when it airs")
            leads = {max(0, int(x)) for x in str(val or "1").split(",")
                     if x.strip().lstrip("-").isdigit()} or {1}
            for d in sorted(leads):
                target = (date.today() + timedelta(days=d)).isoformat()
                for e in con.execute("""SELECT season, number, title FROM episodes
                    WHERE show_id=? AND air_date=? AND season>0 ORDER BY season, number""",
                    (f["show_id"], target)).fetchall():
                    when = "today" if d == 0 else ("tomorrow" if d == 1 else f"in {d} days")
                    push_notif(con, uid, "airing", f"{sname} — S{e['season']}E{e['number']} airs {when}",
                               e["title"] or "", f"show/{f['show_id']}/e/{e['season']}/{e['number']}",
                               dedup=f"airing:{f['show_id']}:{e['season']}:{e['number']}:{d}")
        if ns_en:
            for e in con.execute("""SELECT season, air_date FROM episodes
                WHERE show_id=? AND number=1 AND season>1 AND air_date>=? AND air_date<=?
                ORDER BY air_date""", (f["show_id"], today_s, soon)).fetchall():
                push_notif(con, uid, "new_season", f"{sname} — Season {e['season']} premieres {fmt_when(e['air_date'])}",
                           "", f"show/{f['show_id']}", dedup=f"newseason:{f['show_id']}:{e['season']}")


def scan_available(con, seed=False, only_user=None):
    url, key = overseerr_cfg(con)
    if not url or not key:
        return
    umap = {r["plex_username"]: r["id"] for r in
            con.execute("SELECT id, plex_username FROM users WHERE plex_username IS NOT NULL").fetchall()}
    if not umap:
        return
    try:
        r = httpx.get(f"{url}/api/v1/request", params={"take": 100, "filter": "available", "sort": "modified"},
                      headers={"X-Api-Key": key}, timeout=15)
        r.raise_for_status()
        results = r.json().get("results", [])
    except httpx.HTTPError:
        return
    for req in results:
        m = req.get("media") or {}
        if m.get("status") != 5:
            continue
        uid = umap.get((req.get("requestedBy") or {}).get("plexUsername"))
        tmdb, mt = m.get("tmdbId"), m.get("mediaType")
        if not uid or not tmdb or (only_user and uid != only_user):
            continue
        table = "shows" if mt == "tv" else "movies"
        row = con.execute(f"SELECT title FROM {table} WHERE id=?", (tmdb,)).fetchone()
        name = row["title"] if row else "Your request"
        push_notif(con, uid, "available", f"{name} is ready to watch on Plex", "",
                   f"{'show' if mt == 'tv' else 'movie'}/{tmdb}", dedup=f"available:{mt}:{tmdb}", seed=seed)


def notif_scan():
    with db() as con:
        scan_airing(con)
        scan_available(con)


def notif_loop():
    time.sleep(150)
    while True:
        try:
            notif_scan()
        except Exception:  # noqa: BLE001
            log.exception("notif_scan failed")
        time.sleep(1800)   # every 30 minutes


@app.get("/api/notifications")
def list_notifications(user=Depends(current_user)):
    with db() as con:
        rows = con.execute("SELECT * FROM notifications WHERE user_id=? ORDER BY id DESC LIMIT 60",
                           (user["id"],)).fetchall()
        unread = con.execute("SELECT COUNT(*) c FROM notifications WHERE user_id=? AND read_at IS NULL",
                            (user["id"],)).fetchone()["c"]
    return {"unread": unread, "items": [
        {"id": r["id"], "type": r["type"], "title": r["title"], "body": r["body"],
         "link": r["link"], "created_at": r["created_at"], "read": r["read_at"] is not None} for r in rows]}


@app.post("/api/notifications/read")
async def mark_notifications_read(request: Request, user=Depends(current_user)):
    nid = (await request.json()).get("id")
    now = datetime.utcnow().isoformat()
    with db() as con:
        if nid:
            con.execute("UPDATE notifications SET read_at=? WHERE id=? AND user_id=? AND read_at IS NULL",
                        (now, nid, user["id"]))
        else:
            con.execute("UPDATE notifications SET read_at=? WHERE user_id=? AND read_at IS NULL",
                        (now, user["id"]))
    return {"ok": True}


@app.get("/api/notifications/prefs")
def get_notif_prefs(user=Depends(current_user)):
    with db() as con:
        have = {r["type"]: r for r in
                con.execute("SELECT * FROM notif_prefs WHERE user_id=?", (user["id"],)).fetchall()}
    return {"prefs": [{"type": t, "label": label, "help": help_, "has_days": t == "airing",
                       "enabled": bool(have[t]["enabled"]) if t in have else False,
                       "value": (have[t]["value"] if t in have and have[t]["value"] is not None else dv)}
                      for t, label, help_, dv in NOTIF_TYPES]}


@app.post("/api/notifications/prefs")
async def set_notif_prefs(request: Request, user=Depends(current_user)):
    body = await request.json()
    t = body.get("type")
    if t not in NOTIF_DEFAULT:
        raise HTTPException(400, "unknown type")
    val, enabled = body.get("value"), bool(body.get("enabled"))
    with db() as con:
        con.execute("""INSERT INTO notif_prefs(user_id,type,enabled,value) VALUES(?,?,?,?)
            ON CONFLICT(user_id,type) DO UPDATE SET enabled=excluded.enabled, value=excluded.value""",
            (user["id"], t, 1 if enabled else 0, str(val) if val is not None else None))
    # never backfill: when "request ready" is turned on, baseline everything already available
    # so only titles that become available AFTER this fire an alert
    if enabled and t == "available":
        threading.Thread(target=_seed_available, args=(user["id"],), daemon=True).start()
    return {"ok": True}


def _seed_available(user_id):
    try:
        with db() as con:
            scan_available(con, seed=True, only_user=user_id)
    except Exception:  # noqa: BLE001
        log.exception("seed_available failed")


@app.post("/api/notifications/scan")
def trigger_notif_scan(_=Depends(admin_user)):
    notif_scan()
    return {"ok": True}


@app.post("/api/plex/poll")
def trigger_plex_poll(_=Depends(admin_user)):
    return {"result": plex_poll_once()}


# ---- web push (VAPID) — real OS-level notifications for installed PWAs ----
def ensure_vapid():
    if not PUSH_OK:
        return
    with db() as con:
        pub, pem = setting(con, "vapid_public"), setting(con, "vapid_private_pem")
    if not (pub and pem):
        priv = ec.generate_private_key(ec.SECP256R1())
        pem = priv.private_bytes(_cser.Encoding.PEM, _cser.PrivateFormat.PKCS8,
                                 _cser.NoEncryption()).decode()
        pub = base64.urlsafe_b64encode(priv.public_key().public_bytes(
            _cser.Encoding.X962, _cser.PublicFormat.UncompressedPoint)).rstrip(b"=").decode()
        with db() as con:
            con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('vapid_public',?)", (pub,))
            con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('vapid_private_pem',?)", (pem,))
        log.info("generated VAPID keypair for web push")
    path = os.path.join(DATA, "vapid_private.pem")
    if not os.path.exists(path):
        with open(path, "w") as f:
            f.write(pem)
        os.chmod(path, 0o600)


def deliver_push(user_id, title, body, link):
    """Send an OS-level web push to all of a user's devices; prune expired subscriptions."""
    if not PUSH_OK:
        return
    with db() as con:
        subs = con.execute("SELECT * FROM push_subscriptions WHERE user_id=?", (user_id,)).fetchall()
    if not subs:
        return
    payload = json.dumps({"title": title, "body": body or "", "link": link or ""})
    pem_path = os.path.join(DATA, "vapid_private.pem")
    for s in subs:
        try:
            webpush(subscription_info={"endpoint": s["endpoint"],
                                       "keys": {"p256dh": s["p256dh"], "auth": s["auth"]}},
                    data=payload, vapid_private_key=pem_path, vapid_claims={"sub": VAPID_SUB})
        except WebPushException as ex:
            if getattr(ex.response, "status_code", None) in (404, 410):
                with db() as con:
                    con.execute("DELETE FROM push_subscriptions WHERE endpoint=?", (s["endpoint"],))
            else:
                log.warning("web push failed: %s", ex)
        except Exception:  # noqa: BLE001
            log.exception("web push error")


@app.get("/api/push/pubkey")
def push_pubkey(user=Depends(current_user)):
    with db() as con:
        return {"enabled": PUSH_OK, "key": setting(con, "vapid_public")}


@app.post("/api/push/subscribe")
async def push_subscribe(request: Request, user=Depends(current_user)):
    sub = await request.json()
    ep, keys = sub.get("endpoint"), (sub.get("keys") or {})
    if not ep or not keys.get("p256dh") or not keys.get("auth"):
        raise HTTPException(400, "bad subscription")
    with db() as con:
        con.execute("""INSERT INTO push_subscriptions(user_id,endpoint,p256dh,auth,created_at)
            VALUES(?,?,?,?,?) ON CONFLICT(endpoint) DO UPDATE SET
              user_id=excluded.user_id, p256dh=excluded.p256dh, auth=excluded.auth""",
            (user["id"], ep, keys["p256dh"], keys["auth"], datetime.utcnow().isoformat()))
    return {"ok": True}


@app.post("/api/push/unsubscribe")
async def push_unsubscribe(request: Request, user=Depends(current_user)):
    ep = (await request.json()).get("endpoint")
    with db() as con:
        con.execute("DELETE FROM push_subscriptions WHERE endpoint=? AND user_id=?", (ep, user["id"]))
    return {"ok": True}


@app.post("/api/push/test")
def push_test(user=Depends(current_user)):
    with db() as con:
        n = con.execute("SELECT COUNT(*) c FROM push_subscriptions WHERE user_id=?",
                        (user["id"],)).fetchone()["c"]
    if not n:
        return {"ok": False, "reason": "no_device"}
    deliver_push(user["id"], "Marquee 🔔", "Test notification — push works on this device.", "")
    return {"ok": True, "devices": n}


# ---------------------------------------------------------------- home / watch next

def today():
    return date.today().isoformat()


@app.get("/api/home")
def home(user=Depends(current_user)):
    uid, t = user["id"], today()
    out = {"watch_next": [], "stale": [], "up_to_date": [], "not_started": [], "archived": []}
    with db() as con:
        rows = con.execute("""
          SELECT s.*, f.archived, f.rating,
            (SELECT COUNT(*) FROM episodes e WHERE e.show_id=s.id AND e.season>0
               AND e.air_date IS NOT NULL AND e.air_date<=?) AS aired,
            (SELECT COUNT(*) FROM watches w WHERE w.user_id=? AND w.show_id=s.id AND w.season>0) AS watched,
            (SELECT MAX(w.watched_at) FROM watches w WHERE w.user_id=? AND w.show_id=s.id) AS last_watched,
            (SELECT MIN(e.air_date) FROM episodes e WHERE e.show_id=s.id AND e.season>0
               AND e.air_date>?) AS next_air
          FROM follows f JOIN shows s ON s.id=f.show_id WHERE f.user_id=?""",
          (t, uid, uid, t, uid)).fetchall()
        stale_cut = (datetime.utcnow() - timedelta(days=STALE_DAYS)).isoformat()
        fresh_cut = (date.today() - timedelta(days=STALE_DAYS)).isoformat()  # "recently aired"
        for r in rows:
            nxt = con.execute("""
              SELECT e.season, e.number, e.title, e.air_date FROM episodes e
              WHERE e.show_id=? AND e.season>0 AND e.air_date IS NOT NULL AND e.air_date<=?
                AND NOT EXISTS (SELECT 1 FROM watches w WHERE w.user_id=? AND w.show_id=e.show_id
                                AND w.season=e.season AND w.number=e.number)
              ORDER BY e.season, e.number LIMIT 1""", (r["id"], t, uid)).fetchone()
            item = {
                "id": r["id"], "title": r["title"], "poster": r["poster"], "year": r["year"],
                "status": r["status"], "rating": r["rating"], "avg_runtime": r["avg_runtime"],
                "aired": r["aired"], "watched": min(r["watched"], r["aired"]),
                "remaining": max(r["aired"] - r["watched"], 0),
                "last_watched": r["last_watched"], "next_air": r["next_air"],
                "next_ep": dict(nxt) if nxt else None,
            }
            if r["archived"]:
                out["archived"].append(item)          # explicitly stopped — stays out of Up Next
            elif r["watched"] == 0:
                out["not_started"].append(item)
            elif nxt:
                # a fresh drop (next unwatched episode aired recently) means you were caught up and
                # new content arrived → Up Next, even if you last watched a long time ago.
                fresh_drop = bool(nxt["air_date"]) and nxt["air_date"] >= fresh_cut
                recently_watched = bool(r["last_watched"]) and r["last_watched"] >= stale_cut
                if fresh_drop or recently_watched:
                    out["watch_next"].append(item)
                else:                                 # behind on old episodes AND lapsed
                    out["stale"].append(item)
            else:
                out["up_to_date"].append(item)
    out["watch_next"].sort(key=lambda x: x["last_watched"] or "", reverse=True)
    out["stale"].sort(key=lambda x: x["last_watched"] or "", reverse=True)
    out["up_to_date"].sort(key=lambda x: x["next_air"] or "9999")
    out["not_started"].sort(key=lambda x: x["title"] or "")
    return out


@app.get("/api/dashboard")
def dashboard(user=Depends(current_user)):
    """Trakt-inspired home: on-deck, calendar, recommended, recent, household activity."""
    uid, t = user["id"], today()
    home_data = home(user)
    up = upcoming(user)
    calendar = up["episodes"][:16]
    with db() as con:
        # recently watched by me (collapse same show/day handled client-side; send raw recents)
        recent = con.execute("""
          SELECT w.show_id, w.season, w.number, w.watched_at, s.title, s.poster, e.title AS ep_title
          FROM watches w JOIN shows s ON s.id=w.show_id
          LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
          WHERE w.user_id=? ORDER BY w.watched_at DESC LIMIT 60""", (uid,)).fetchall()
        # household activity: what OTHER users watched recently
        social = con.execute("""
          SELECT w.user_id, u.username, u.display_name, u.avatar, w.show_id, w.season, w.number,
                 w.watched_at, s.title, s.poster, e.title AS ep_title
          FROM watches w JOIN users u ON u.id=w.user_id JOIN shows s ON s.id=w.show_id
          LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
          WHERE w.user_id<>? ORDER BY w.watched_at DESC LIMIT 40""", (uid,)).fetchall()
        # recent shared reviews across the household
        reviews = con.execute("""
          SELECT r.item_type, r.item_id, r.rating, r.body, r.updated_at,
                 u.username, u.display_name, u.avatar
          FROM reviews r JOIN users u ON u.id=r.user_id
          ORDER BY r.updated_at DESC LIMIT 8""").fetchall()

    def collapse(rows):
        out, seen = [], {}
        for r in rows:
            day = r["watched_at"][:10]
            key = (day, r["show_id"], r["user_id"] if "user_id" in r.keys() else uid)
            if key in seen:
                seen[key]["count"] += 1
                continue
            item = {"show_id": r["show_id"], "title": r["title"], "poster": r["poster"],
                    "season": r["season"], "number": r["number"], "ep_title": r["ep_title"],
                    "watched_at": r["watched_at"], "count": 1}
            if "display_name" in r.keys():
                item["by"] = {"display_name": r["display_name"] or r["username"], "avatar": r["avatar"]}
            seen[key] = item
            out.append(item)
        return out

    rev_out = []
    for r in reviews:
        title = None
        with db() as con:
            tbl = "shows" if r["item_type"] == "show" else "movies"
            row = con.execute(f"SELECT title, poster FROM {tbl} WHERE id=?", (r["item_id"],)).fetchone()
        if not row:
            continue
        rev_out.append({"type": r["item_type"], "id": r["item_id"], "title": row["title"],
                        "poster": row["poster"], "rating": r["rating"],
                        "body": (r["body"] or "")[:180], "updated_at": r["updated_at"],
                        "by": {"display_name": r["display_name"] or r["username"], "avatar": r["avatar"]}})

    return {
        "up_next": home_data["watch_next"],
        "stale": home_data["stale"],
        "calendar": calendar,
        "recent": collapse(recent)[:24],
        "social": collapse(social)[:12],
        "reviews": rev_out,
        "counts": {"up_to_date": len(home_data["up_to_date"]),
                   "not_started": len(home_data["not_started"])},
    }


@app.get("/api/upcoming")
def upcoming(user=Depends(current_user)):
    uid, t = user["id"], today()
    horizon = (date.today() + timedelta(days=90)).isoformat()
    with db() as con:
        eps = con.execute("""
          SELECT e.show_id, s.title AS show_title, s.poster, e.season, e.number, e.title, e.air_date
          FROM episodes e JOIN shows s ON s.id=e.show_id
          JOIN follows f ON f.show_id=e.show_id AND f.user_id=? AND f.archived=0
          WHERE e.air_date>? AND e.air_date<=? AND e.season>0
          ORDER BY e.air_date, s.title, e.season, e.number""", (uid, t, horizon)).fetchall()
        movs = con.execute("""
          SELECT m.id, m.title, m.poster, m.release_date FROM movies m
          JOIN movie_states ms ON ms.movie_id=m.id AND ms.user_id=? AND ms.state='watchlist'
          WHERE m.release_date>? AND m.release_date<=?
          ORDER BY m.release_date""", (uid, t, horizon)).fetchall()
    return {"episodes": [dict(r) for r in eps], "movies": [dict(r) for r in movs]}


# ---------------------------------------------------------------- show detail + marking

@app.get("/api/show/{show_id}")
def show_detail(show_id: int, user=Depends(current_user)):
    uid = user["id"]
    with db() as con:
        s = con.execute("SELECT * FROM shows WHERE id=?", (show_id,)).fetchone()
        if not s or not s["details"]:
            # first visit (or pre-details catalog row): pull full data from TMDB
            if not upsert_show(con, show_id, fetch_episodes=not s) and not s:
                raise HTTPException(404, "show not found on TMDB")
            s = con.execute("SELECT * FROM shows WHERE id=?", (show_id,)).fetchone()
        f = con.execute("SELECT * FROM follows WHERE user_id=? AND show_id=?", (uid, show_id)).fetchone()
        eps = con.execute("""SELECT e.*, (w.user_id IS NOT NULL) AS watched, w.watched_at
            FROM episodes e LEFT JOIN watches w ON w.show_id=e.show_id AND w.season=e.season
              AND w.number=e.number AND w.user_id=?
            WHERE e.show_id=? ORDER BY e.season, e.number""", (uid, show_id)).fetchall()
        seasons = {}
        for e in eps:
            seasons.setdefault(e["season"], []).append({
                "season": e["season"], "number": e["number"], "title": e["title"],
                "air_date": e["air_date"], "runtime": e["runtime"],
                "still": e["still"] if "still" in e.keys() else None,
                "custom": (e["source"] if "source" in e.keys() else "tmdb") == "custom",
                "watched": bool(e["watched"]), "watched_at": e["watched_at"]})
        info = {}
        try:
            info = json.loads(s["details"] or "{}")
        except (json.JSONDecodeError, TypeError):
            pass
        return {**{k: s[k] for k in s.keys() if k != "details"}, "info": info,
                "followed": bool(f), "archived": bool(f and f["archived"]),
                "rating": f["rating"] if f else None,
                "seasons": [{"season": k, "episodes": v} for k, v in sorted(seasons.items())]}


def show_summary(con, uid, show_id):
    """Card-shaped summary of one show for in-place UI patches."""
    t = today()
    r = con.execute("""
      SELECT s.*, f.archived, f.rating,
        (SELECT COUNT(*) FROM episodes e WHERE e.show_id=s.id AND e.season>0
           AND e.air_date IS NOT NULL AND e.air_date<=?) AS aired,
        (SELECT COUNT(*) FROM watches w WHERE w.user_id=? AND w.show_id=s.id AND w.season>0) AS watched,
        (SELECT MAX(w.watched_at) FROM watches w WHERE w.user_id=? AND w.show_id=s.id) AS last_watched,
        (SELECT MIN(e.air_date) FROM episodes e WHERE e.show_id=s.id AND e.season>0
           AND e.air_date>?) AS next_air
      FROM shows s LEFT JOIN follows f ON f.show_id=s.id AND f.user_id=?
      WHERE s.id=?""", (t, uid, uid, t, uid, show_id)).fetchone()
    if not r:
        return None
    nxt = con.execute("""
      SELECT e.season, e.number, e.title, e.air_date FROM episodes e
      WHERE e.show_id=? AND e.season>0 AND e.air_date IS NOT NULL AND e.air_date<=?
        AND NOT EXISTS (SELECT 1 FROM watches w WHERE w.user_id=? AND w.show_id=e.show_id
                        AND w.season=e.season AND w.number=e.number)
      ORDER BY e.season, e.number LIMIT 1""", (show_id, t, uid)).fetchone()
    return {"id": r["id"], "title": r["title"], "poster": r["poster"], "year": r["year"],
            "status": r["status"], "rating": r["rating"], "avg_runtime": r["avg_runtime"],
            "aired": r["aired"], "watched": min(r["watched"], r["aired"]),
            "remaining": max(r["aired"] - r["watched"], 0),
            "last_watched": r["last_watched"], "next_air": r["next_air"],
            "next_ep": dict(nxt) if nxt else None}


@app.post("/api/show/{show_id}/episodes/custom")
async def add_custom_episodes(show_id: int, request: Request, user=Depends(admin_user)):
    """Add placeholder episodes TMDB doesn't have. If TMDB later adds the same
    season/episode numbers, its data replaces these automatically on refresh."""
    body = await request.json()
    season = int(body["season"])
    titles = [t.strip() for t in (body.get("titles") or "").splitlines() if t.strip()]
    count = int(body.get("count") or 0) or len(titles)
    if count <= 0 or count > 200:
        raise HTTPException(400, "give a count (1-200) or one title per line")
    air = (body.get("air_date") or "").strip() or date.today().isoformat()
    with db() as con:
        if not con.execute("SELECT 1 FROM shows WHERE id=?", (show_id,)).fetchone():
            raise HTTPException(404, "unknown show")
        start = (con.execute("SELECT MAX(number) m FROM episodes WHERE show_id=? AND season=?",
                             (show_id, season)).fetchone()["m"] or 0) + 1
        added = 0
        for i in range(count):
            n = start + i
            title = titles[i] if i < len(titles) else f"Episode {n}"
            cur = con.execute("SELECT 1 FROM episodes WHERE show_id=? AND season=? AND number=?",
                              (show_id, season, n)).fetchone()
            if cur:
                continue
            con.execute("""INSERT INTO episodes(show_id,season,number,title,air_date,runtime,source)
                VALUES(?,?,?,?,?,NULL,'custom')""", (show_id, season, n, title, air))
            added += 1
    return {"ok": True, "added": added, "season": season, "from": start}


@app.post("/api/show/{show_id}/episodes/custom/delete")
async def delete_custom_episode(show_id: int, request: Request, user=Depends(admin_user)):
    body = await request.json()
    season, number = int(body["season"]), int(body["number"])
    with db() as con:
        r = con.execute("""DELETE FROM episodes WHERE show_id=? AND season=? AND number=?
            AND source='custom'""", (show_id, season, number))
        if r.rowcount:
            con.execute("DELETE FROM watches WHERE show_id=? AND season=? AND number=?",
                        (show_id, season, number))
    return {"ok": True, "deleted": bool(r.rowcount)}


@app.get("/api/show/{show_id}/ratings")
def show_ratings(show_id: int, user=Depends(current_user)):
    """Per-episode TMDB ratings + per-season averages, for the sparklines."""
    with db() as con:
        have = con.execute("""SELECT COUNT(*) c FROM episodes WHERE show_id=? AND season>0
            AND rating IS NOT NULL""", (show_id,)).fetchone()["c"]
        total = con.execute("SELECT COUNT(*) c FROM episodes WHERE show_id=? AND season>0",
                            (show_id,)).fetchone()["c"]
        seasons = [r["season"] for r in con.execute(
            "SELECT DISTINCT season FROM episodes WHERE show_id=? AND season>0 ORDER BY season",
            (show_id,))]
    # lazy-fetch ratings from TMDB if we don't have them (older data / never fetched)
    if total and have < total * 0.5:
        for sn in seasons:
            sd = tmdb(f"/tv/{show_id}/season/{sn}")
            if not sd:
                continue
            with db() as con:
                for e in sd.get("episodes", []):
                    rat = round(e.get("vote_average") or 0, 1) or None
                    if rat is not None:
                        con.execute("""UPDATE episodes SET rating=? WHERE show_id=? AND season=? AND number=?""",
                                    (rat, show_id, e["season_number"], e["episode_number"]))
    with db() as con:
        rows = con.execute("""SELECT season, number, title, rating FROM episodes
            WHERE show_id=? AND season>0 AND rating IS NOT NULL ORDER BY season, number""",
            (show_id,)).fetchall()
    by_season = {}
    flat = []
    for r in rows:
        by_season.setdefault(r["season"], []).append(r["rating"])
        flat.append({"season": r["season"], "number": r["number"],
                     "title": r["title"], "rating": r["rating"]})
    season_avg = [{"season": s, "avg": round(sum(v) / len(v), 2), "count": len(v)}
                  for s, v in sorted(by_season.items()) if v]
    return {"episodes": flat, "season_avg": season_avg}


@app.get("/api/show/{show_id}/episode/{season}/{number}")
def episode_detail(show_id: int, season: int, number: int, user=Depends(current_user)):
    uid = user["id"]
    with db() as con:
        e = con.execute("""SELECT e.*, s.title AS show_title, s.poster AS show_poster,
              s.backdrop AS show_backdrop, s.details AS show_details,
              (w.user_id IS NOT NULL) AS watched, w.watched_at
            FROM episodes e JOIN shows s ON s.id=e.show_id
            LEFT JOIN watches w ON w.show_id=e.show_id AND w.season=e.season AND w.number=e.number
              AND w.user_id=?
            WHERE e.show_id=? AND e.season=? AND e.number=?""",
            (uid, show_id, season, number)).fetchone()
        if not e:
            raise HTTPException(404, "unknown episode")
        try:
            season_poster = (json.loads(e["show_details"] or "{}").get("season_posters") or {}).get(str(season))
        except (json.JSONDecodeError, TypeError):
            season_poster = None
        sib = con.execute("""SELECT season, number FROM episodes WHERE show_id=? AND season>0
            ORDER BY season, number""", (show_id,)).fetchall()
        prev_ep = next_ep = None
        for i, r in enumerate(sib):
            if r["season"] == season and r["number"] == number:
                prev_ep = dict(sib[i - 1]) if i > 0 else None
                next_ep = dict(sib[i + 1]) if i + 1 < len(sib) else None
                break
        earlier = con.execute("""SELECT COUNT(*) c FROM episodes e WHERE e.show_id=? AND e.season>0
            AND (e.season<? OR (e.season=? AND e.number<?))
            AND e.air_date IS NOT NULL AND e.air_date<=?
            AND NOT EXISTS (SELECT 1 FROM watches w WHERE w.user_id=? AND w.show_id=e.show_id
                            AND w.season=e.season AND w.number=e.number)""",
            (show_id, season, season, number, today(), uid)).fetchone()["c"]
        # lazy-fetch credits/rating for this episode on first view (tmdb rows only)
        extra = {}
        try:
            extra = json.loads(e["details"] or "{}")
        except (json.JSONDecodeError, TypeError):
            pass
        if not extra and (e["source"] if "source" in e.keys() else "tmdb") == "tmdb":
            d = tmdb(f"/tv/{show_id}/season/{season}/episode/{number}",
                     append_to_response="credits")
            if d:
                crew = (d.get("credits") or {}).get("crew") or d.get("crew") or []
                extra = {
                    "vote": round(d.get("vote_average") or 0, 1), "votes": d.get("vote_count"),
                    "directors": [c["name"] for c in crew if c.get("job") == "Director"][:3],
                    "writers": [c["name"] for c in crew if c.get("department") == "Writing"][:3],
                    "guests": [{"id": g["id"], "name": g["name"], "character": g.get("character"),
                                "img": img(g.get("profile_path"), "w185")}
                               for g in (d.get("guest_stars") or
                                         (d.get("credits") or {}).get("guest_stars") or [])[:8]],
                }
                con.execute("UPDATE episodes SET details=? WHERE show_id=? AND season=? AND number=?",
                            (json.dumps(extra), show_id, season, number))
        out = {k: e[k] for k in e.keys() if k not in ("details", "show_details")}
        return {**out, "watched": bool(e["watched"]), "prev": prev_ep, "next": next_ep,
                "season_poster": season_poster, "earlier_unwatched": earlier, "extra": extra}


@app.post("/api/show/{show_id}/watch")
async def mark_episode(show_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    uid = user["id"]
    season, number = int(body["season"]), int(body["number"])
    now = datetime.utcnow().isoformat()
    with db() as con:
        if body.get("set_date"):
            # update (or create) the watch's date without toggling
            wa = body["set_date"]
            exists = con.execute("""SELECT 1 FROM watches WHERE user_id=? AND show_id=?
                AND season=? AND number=?""", (uid, show_id, season, number)).fetchone()
            if exists:
                con.execute("""UPDATE watches SET watched_at=? WHERE user_id=? AND show_id=?
                    AND season=? AND number=?""", (wa, uid, show_id, season, number))
            else:
                con.execute("""INSERT INTO watches(user_id,show_id,season,number,watched_at)
                    VALUES(?,?,?,?,?)""", (uid, show_id, season, number, wa))
                con.execute("INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)",
                            (uid, show_id, now))
            return {"ok": True, "show": show_summary(con, uid, show_id)}
        if body.get("unwatch"):
            con.execute("DELETE FROM watches WHERE user_id=? AND show_id=? AND season=? AND number=?",
                        (uid, show_id, season, number))
        elif body.get("previous"):
            eps = con.execute("""SELECT season, number FROM episodes WHERE show_id=? AND season>0
                AND (season<? OR (season=? AND number<=?)) AND air_date IS NOT NULL AND air_date<=?""",
                (show_id, season, season, number, today())).fetchall()
            con.executemany("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                VALUES(?,?,?,?,?)""", [(uid, show_id, e["season"], e["number"], now) for e in eps])
        else:
            con.execute("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                VALUES(?,?,?,?,?)""", (uid, show_id, season, number, now))
        con.execute("""INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)""",
                    (uid, show_id, now))
        return {"ok": True, "show": show_summary(con, uid, show_id)}


@app.post("/api/show/{show_id}/season/{season}/watch")
async def mark_season(show_id: int, season: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    uid, now = user["id"], datetime.utcnow().isoformat()
    with db() as con:
        if body.get("unwatch"):
            con.execute("DELETE FROM watches WHERE user_id=? AND show_id=? AND season=?",
                        (uid, show_id, season))
        else:
            eps = con.execute("""SELECT number FROM episodes WHERE show_id=? AND season=?
                AND air_date IS NOT NULL AND air_date<=?""", (show_id, season, today())).fetchall()
            con.executemany("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                VALUES(?,?,?,?,?)""", [(uid, show_id, season, e["number"], now) for e in eps])
        return {"ok": True, "show": show_summary(con, uid, show_id)}


@app.post("/api/show/{show_id}/follow")
async def follow(show_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    with db() as con:
        if body.get("unfollow"):
            con.execute("DELETE FROM follows WHERE user_id=? AND show_id=?", (user["id"], show_id))
            con.execute("DELETE FROM watches WHERE user_id=? AND show_id=?", (user["id"], show_id))
        elif "archived" in body:
            con.execute("UPDATE follows SET archived=? WHERE user_id=? AND show_id=?",
                        (1 if body["archived"] else 0, user["id"], show_id))
        elif "rating" in body:
            con.execute("UPDATE follows SET rating=? WHERE user_id=? AND show_id=?",
                        (body["rating"], user["id"], show_id))
        else:
            con.execute("INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)",
                        (user["id"], show_id, datetime.utcnow().isoformat()))
    return {"ok": True}


# ---------------------------------------------------------------- movies

@app.get("/api/movies")
def movies(user=Depends(current_user)):
    with db() as con:
        rows = con.execute("""SELECT m.*, ms.state, ms.watched_at, ms.rating FROM movies m
            JOIN movie_states ms ON ms.movie_id=m.id WHERE ms.user_id=?
            ORDER BY COALESCE(ms.watched_at, m.release_date) DESC""", (user["id"],)).fetchall()
    out = {"watched": [], "watchlist": []}
    for r in rows:
        (out["watched"] if r["state"] == "watched" else out["watchlist"]).append(dict(r))
    return out


@app.get("/api/movie/{movie_id}")
def movie_detail(movie_id: int, user=Depends(current_user)):
    uid = user["id"]
    with db() as con:
        m = con.execute("SELECT * FROM movies WHERE id=?", (movie_id,)).fetchone()
        need_details = not m or "details" not in m.keys() or not m["details"]
    if need_details:
        d = tmdb(f"/movie/{movie_id}", append_to_response="credits,release_dates")
        if not d:
            raise HTTPException(404, "movie not found on TMDB")
        cert = None
        for rd in (d.get("release_dates") or {}).get("results", []):
            if rd.get("iso_3166_1") == "US":
                for x in rd.get("release_dates", []):
                    if x.get("certification"):
                        cert = x["certification"]
        details = {
            "overview": d.get("overview"), "tagline": d.get("tagline"),
            "vote": round(d.get("vote_average") or 0, 1), "votes": d.get("vote_count"),
            "backdrop": img(d.get("backdrop_path"), "w780"), "runtime": d.get("runtime"),
            "genres": [g["name"] for g in d.get("genres", [])],
            "content_rating": cert, "imdb_id": d.get("imdb_id"),
            "directors": [c["name"] for c in (d.get("credits") or {}).get("crew", [])
                          if c.get("job") == "Director"][:3],
            "cast": [{"id": c["id"], "name": c["name"], "character": c.get("character"),
                      "img": img(c.get("profile_path"), "w185")}
                     for c in ((d.get("credits") or {}).get("cast") or [])[:14]],
        }
        with db() as con:
            try:
                con.execute("ALTER TABLE movies ADD COLUMN details TEXT")
            except sqlite3.OperationalError:
                pass
            upsert_movie(con, movie_id)
            con.execute("UPDATE movies SET details=? WHERE id=?", (json.dumps(details), movie_id))
            m = con.execute("SELECT * FROM movies WHERE id=?", (movie_id,)).fetchone()
    info = {}
    try:
        info = json.loads(m["details"] or "{}")
    except (json.JSONDecodeError, TypeError):
        pass
    with db() as con:
        st = con.execute("SELECT state, rating FROM movie_states WHERE user_id=? AND movie_id=?",
                        (uid, movie_id)).fetchone()
    return {**{k: m[k] for k in m.keys() if k != "details"}, "info": info,
            "state": st["state"] if st else None, "my_rating": st["rating"] if st else None}


# ---------------------------------------------------------------- where to watch (streaming availability)

WATCH_TTL = 7 * 24 * 3600   # streaming availability shifts slowly — refresh weekly


@app.get("/api/watch_providers/{item_type}/{item_id}")
def watch_providers(item_type: str, item_id: int, user=Depends(current_user)):
    """US streaming / rent / buy availability from TMDB (JustWatch data), cached weekly.
    Always returns a well-formed result — empty groups when there's no token or no coverage."""
    if item_type not in ("show", "movie"):
        raise HTTPException(404, "unknown type")
    kind = "tv" if item_type == "show" else "movie"
    with db() as con:
        row = con.execute("SELECT data, fetched_at FROM watch_providers "
                          "WHERE item_type=? AND item_id=? AND region='US'",
                          (item_type, item_id)).fetchone()
    if row and row["fetched_at"]:
        try:
            age = (datetime.utcnow() - datetime.fromisoformat(row["fetched_at"])).total_seconds()
            if age < WATCH_TTL:
                return json.loads(row["data"])
        except (ValueError, json.JSONDecodeError):
            pass
    # (re)fetch — a missing TMDB token or network hiccup degrades to an empty result, never a 500
    try:
        d = tmdb(f"/{kind}/{item_id}/watch/providers") or {}
    except httpx.HTTPError:
        d = {}
    us = (d.get("results") or {}).get("US") or {}

    def group(items):
        out, seen = [], set()
        for p in items or []:
            pid = p.get("provider_id")
            if pid in seen:
                continue
            seen.add(pid)
            out.append({"id": pid, "name": p.get("provider_name"),
                        "logo": img(p.get("logo_path"), "w92")})
        return out

    # "stream" folds free + ad-supported tiers in with subscription flatrate (all watch-now-included)
    stream = group((us.get("flatrate") or []) + (us.get("free") or []) + (us.get("ads") or []))
    rent, buy = group(us.get("rent")), group(us.get("buy"))
    result = {"region": "US", "link": us.get("link"),
              "flatrate": stream, "rent": rent, "buy": buy,
              "has_any": bool(stream or rent or buy)}
    with db() as con:
        con.execute("""INSERT INTO watch_providers(item_type,item_id,region,data,fetched_at)
            VALUES(?,?,'US',?,?)
            ON CONFLICT(item_type,item_id,region)
              DO UPDATE SET data=excluded.data, fetched_at=excluded.fetched_at""",
            (item_type, item_id, json.dumps(result), datetime.utcnow().isoformat()))
    return result


@app.post("/api/movie/{movie_id}/state")
async def movie_state(movie_id: int, request: Request, user=Depends(current_user)):
    body = await request.json()
    state = body.get("state")
    with db() as con:
        if not con.execute("SELECT 1 FROM movies WHERE id=?", (movie_id,)).fetchone():
            upsert_movie(con, movie_id)
        if state == "none":
            con.execute("DELETE FROM movie_states WHERE user_id=? AND movie_id=?", (user["id"], movie_id))
        else:
            watched_at = datetime.utcnow().isoformat() if state == "watched" else None
            con.execute("""INSERT INTO movie_states(user_id,movie_id,state,watched_at,rating)
                VALUES(?,?,?,?,?) ON CONFLICT(user_id,movie_id) DO UPDATE SET state=excluded.state,
                watched_at=COALESCE(excluded.watched_at, movie_states.watched_at),
                rating=COALESCE(?, movie_states.rating)""",
                (user["id"], movie_id, state, watched_at, body.get("rating"), body.get("rating")))
    return {"ok": True}


# ---------------------------------------------------------------- search + add

@app.get("/api/search")
def search(q: str, user=Depends(current_user)):
    res = tmdb("/search/multi", query=q) or {}
    uid = user["id"]
    out = []
    with db() as con:
        followed = {r["show_id"] for r in con.execute(
            "SELECT show_id FROM follows WHERE user_id=?", (uid,))}
        mstates = {r["movie_id"]: r["state"] for r in con.execute(
            "SELECT movie_id, state FROM movie_states WHERE user_id=?", (uid,))}
    for r in (res.get("results") or [])[:24]:
        if r.get("media_type") == "tv":
            out.append({"type": "show", "id": r["id"], "title": r.get("name"),
                        "year": (r.get("first_air_date") or "")[:4], "poster": img(r.get("poster_path")),
                        "followed": r["id"] in followed})
        elif r.get("media_type") == "movie":
            out.append({"type": "movie", "id": r["id"], "title": r.get("title"),
                        "year": (r.get("release_date") or "")[:4], "poster": img(r.get("poster_path")),
                        "state": mstates.get(r["id"])})
    return {"results": out}


@app.post("/api/add")
async def add(request: Request, user=Depends(current_user)):
    body = await request.json()
    tmdb_id = int(body["id"])
    with db() as con:
        if body["type"] == "show":
            if not con.execute("SELECT 1 FROM shows WHERE id=?", (tmdb_id,)).fetchone():
                if not upsert_show(con, tmdb_id):
                    raise HTTPException(404, "show not found on TMDB")
            con.execute("INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)",
                        (user["id"], tmdb_id, datetime.utcnow().isoformat()))
        else:
            if not con.execute("SELECT 1 FROM movies WHERE id=?", (tmdb_id,)).fetchone():
                if not upsert_movie(con, tmdb_id):
                    raise HTTPException(404, "movie not found on TMDB")
            state = body.get("state", "watchlist")
            con.execute("""INSERT INTO movie_states(user_id,movie_id,state,watched_at)
                VALUES(?,?,?,?) ON CONFLICT(user_id,movie_id) DO UPDATE SET state=excluded.state""",
                (user["id"], tmdb_id, state,
                 datetime.utcnow().isoformat() if state == "watched" else None))
    return {"ok": True}


# ---------------------------------------------------------------- people

_person_cache = {}


@app.get("/api/person/{person_id}")
def person_detail(person_id: int, user=Depends(current_user)):
    hit = _person_cache.get(person_id)
    if hit and time.time() - hit[0] < 86400:
        return hit[1]
    d = tmdb(f"/person/{person_id}", append_to_response="combined_credits")
    if not d:
        raise HTTPException(404, "person not found")
    seen = {}
    for c in (d.get("combined_credits") or {}).get("cast", []):
        mt = c.get("media_type")
        if mt not in ("movie", "tv"):
            continue
        key = (mt, c["id"])
        date = c.get("release_date") or c.get("first_air_date") or ""
        if key not in seen or (c.get("vote_count", 0) > seen[key]["_vc"]):
            seen[key] = {
                "type": "show" if mt == "tv" else "movie", "id": c["id"],
                "title": c.get("title") or c.get("name"),
                "year": (date or "")[:4], "poster": img(c.get("poster_path")),
                "character": c.get("character"), "vote": round(c.get("vote_average") or 0, 1),
                "_vc": c.get("vote_count", 0), "_date": date}
    # rank by how widely-seen the title is (vote count), so signature roles lead
    credits = sorted(seen.values(), key=lambda x: (-x["_vc"], x["_date"] or "0"))
    for c in credits:
        c.pop("_vc", None)
    data = {
        "id": d["id"], "name": d.get("name"),
        "bio": d.get("biography"), "birthday": d.get("birthday"),
        "deathday": d.get("deathday"), "place": d.get("place_of_birth"),
        "known_for": d.get("known_for_department"),
        "img": img(d.get("profile_path"), "w342"),
        "imdb_id": d.get("imdb_id"),
        "credits": credits,
    }
    _person_cache[person_id] = (time.time(), data)
    return data


# ---------------------------------------------------------------- discover

_discover_cache = {}


@app.get("/api/discover")
def discover(user=Depends(current_user)):
    uid = user["id"]
    hit = _discover_cache.get(uid)
    if hit and time.time() - hit[0] < 21600:
        return hit[1]
    with db() as con:
        followed = {r["show_id"] for r in con.execute(
            "SELECT show_id FROM follows WHERE user_id=?", (uid,))}
        have_movies = {r["movie_id"] for r in con.execute(
            "SELECT movie_id FROM movie_states WHERE user_id=?", (uid,))}
        recent = con.execute("""SELECT s.id, s.title FROM watches w JOIN shows s ON s.id=w.show_id
            WHERE w.user_id=? ORDER BY w.watched_at DESC LIMIT 1""", (uid,)).fetchone()
        top = con.execute("""SELECT s.id, s.title, COUNT(*) c FROM watches w
            JOIN shows s ON s.id=w.show_id WHERE w.user_id=? GROUP BY s.id
            ORDER BY c DESC LIMIT 2""", (uid,)).fetchall()
    seeds = []
    if recent:
        seeds.append(dict(recent))
    for t in top:
        if not any(s["id"] == t["id"] for s in seeds):
            seeds.append({"id": t["id"], "title": t["title"]})
    seeds = seeds[:2]

    def tv_items(res):
        return [{"type": "show", "id": r["id"], "title": r.get("name"),
                 "year": (r.get("first_air_date") or "")[:4],
                 "poster": img(r.get("poster_path")), "vote": round(r.get("vote_average") or 0, 1)}
                for r in (res or {}).get("results", []) if r["id"] not in followed][:14]

    def movie_items(res):
        return [{"type": "movie", "id": r["id"], "title": r.get("title"),
                 "year": (r.get("release_date") or "")[:4],
                 "poster": img(r.get("poster_path")), "vote": round(r.get("vote_average") or 0, 1)}
                for r in (res or {}).get("results", []) if r["id"] not in have_movies][:14]

    sections = []
    sections.append({"title": "Trending shows this week", "items": tv_items(tmdb("/trending/tv/week"))})
    for s in seeds:
        recs = tv_items(tmdb(f"/tv/{s['id']}/recommendations"))
        if recs:
            sections.append({"title": f"Because you watched {s['title']}", "items": recs})
    sections.append({"title": "Popular right now", "items": movie_items(tmdb("/movie/popular"))})
    sections.append({"title": "Trending films", "items": movie_items(tmdb("/trending/movie/week"))})
    # vote_count threshold keeps these to recognizable, widely-rated titles
    sections.append({"title": "Acclaimed television", "items": tv_items(tmdb(
        "/discover/tv", sort_by="vote_average.desc", **{"vote_count.gte": 800},
        without_genres="10767,10763"))})
    sections.append({"title": "Critically adored films", "items": movie_items(tmdb(
        "/discover/movie", sort_by="vote_average.desc", **{"vote_count.gte": 4000}))})
    data = {"sections": [s for s in sections if s["items"]]}
    _discover_cache[uid] = (time.time(), data)
    return data


# ---------------------------------------------------------------- stats

# A watched_at shared by this many episodes is a batch mark (TV Time import /
# "mark whole season"), not real-time viewing — exclude it from binge/biggest-day
# stats so an import doesn't masquerade as a 1,300-episode "day".
BULK_MARK = 5


def biggest_binge(con, uid, lo=None, hi=None):
    """Biggest genuine single-day binge (date, episode count, top show), ignoring
    bulk import/season-mark timestamps. Returns None if there's no real viewing."""
    bulk = "w.watched_at NOT IN (SELECT watched_at FROM watches WHERE user_id=? GROUP BY watched_at HAVING COUNT(*)>=?)"
    where, args = "w.user_id=?", [uid]
    if lo:
        where += " AND w.watched_at>=?"; args.append(lo)
    if hi:
        where += " AND w.watched_at<=?"; args.append(hi)
    row = con.execute(
        f"""SELECT substr(w.watched_at,1,10) d, COUNT(*) c FROM watches w
            WHERE {where} AND {bulk} GROUP BY d ORDER BY c DESC LIMIT 1""",
        (*args, uid, BULK_MARK)).fetchone()
    if not row:
        return None
    top = con.execute(
        f"""SELECT s.title FROM watches w JOIN shows s ON s.id=w.show_id
            WHERE w.user_id=? AND substr(w.watched_at,1,10)=? AND {bulk}
            GROUP BY s.id ORDER BY COUNT(*) DESC LIMIT 1""",
        (uid, row["d"], uid, BULK_MARK)).fetchone()
    return {"date": row["d"], "count": row["c"], "top": top["title"] if top else None}


def _heat_by_year(rows):
    """Fold the (year, dow, hour, count) rows into {'all': [[dow,hour,count]…],
    '<year>': [...], …} — the all-time grid plus one grid per year, for the
    watch-clock year selector."""
    years, allc = {}, {}
    for r in rows:
        key = (int(r["d"]), int(r["h"]))
        years.setdefault(r["y"], {})
        years[r["y"]][key] = years[r["y"]].get(key, 0) + r["c"]
        allc[key] = allc.get(key, 0) + r["c"]
    flat = lambda m: [[d, h, c] for (d, h), c in m.items()]
    out = {y: flat(m) for y, m in years.items()}
    out["all"] = flat(allc)
    return out


def compute_stats(uid):
    with db() as con:
        eps_total = con.execute("SELECT COUNT(*) c FROM watches WHERE user_id=?", (uid,)).fetchone()["c"]
        minutes = con.execute("""SELECT COALESCE(SUM(COALESCE(e.runtime, s.avg_runtime, 30)),0) m
            FROM watches w JOIN shows s ON s.id=w.show_id
            LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
            WHERE w.user_id=?""", (uid,)).fetchone()["m"]
        mov = con.execute("""SELECT COUNT(*) c, COALESCE(SUM(COALESCE(m.runtime,110)),0) m
            FROM movie_states ms JOIN movies m ON m.id=ms.movie_id
            WHERE ms.user_id=? AND ms.state='watched'""", (uid,)).fetchone()
        shows_n = con.execute("SELECT COUNT(*) c FROM follows WHERE user_id=?", (uid,)).fetchone()["c"]
        monthly = con.execute("""
          SELECT substr(watched_at,1,7) ym, COUNT(*) c FROM watches WHERE user_id=?
            AND watched_at >= date('now','-23 months','start of month') GROUP BY ym
          UNION ALL
          SELECT substr(watched_at,1,7) ym, COUNT(*) c FROM movie_states WHERE user_id=?
            AND state='watched' AND watched_at IS NOT NULL
            AND watched_at >= date('now','-23 months','start of month') GROUP BY ym""",
          (uid, uid)).fetchall()
        agg = {}
        for r in monthly:
            if r["ym"]:
                agg[r["ym"]] = agg.get(r["ym"], 0) + r["c"]
        top = con.execute("""SELECT s.title, s.poster, COUNT(*) eps,
              SUM(COALESCE(e.runtime, s.avg_runtime, 30)) mins
            FROM watches w JOIN shows s ON s.id=w.show_id
            LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
            WHERE w.user_id=? GROUP BY s.id ORDER BY mins DESC LIMIT 10""", (uid,)).fetchall()
        genres = con.execute("""SELECT s.genres FROM watches w JOIN shows s ON s.id=w.show_id
            WHERE w.user_id=? AND s.genres!=''""", (uid,)).fetchall()
        gcount = {}
        for r in genres:
            for g in r["genres"].split(","):
                gcount[g] = gcount.get(g, 0) + 1
        yr = date.today().year
        this_year = con.execute("""SELECT COUNT(*) c FROM watches WHERE user_id=?
            AND watched_at>=?""", (uid, f"{yr}-01-01")).fetchone()["c"]
        movies_this_year = con.execute("""SELECT COUNT(*) c FROM movie_states WHERE user_id=?
            AND state='watched' AND watched_at>=?""", (uid, f"{yr}-01-01")).fetchone()["c"]
        top_this_year = con.execute("""SELECT s.title, COUNT(*) eps,
              SUM(COALESCE(e.runtime, s.avg_runtime, 30)) mins
            FROM watches w JOIN shows s ON s.id=w.show_id
            LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
            WHERE w.user_id=? AND w.watched_at>=? GROUP BY s.id
            ORDER BY mins DESC LIMIT 5""", (uid, f"{yr}-01-01")).fetchall()

        # streaks + records from distinct watch dates
        dates = [r["d"] for r in con.execute("""
            SELECT DISTINCT substr(watched_at,1,10) d FROM watches WHERE user_id=?
            UNION SELECT DISTINCT substr(watched_at,1,10) FROM movie_states
              WHERE user_id=? AND state='watched' AND watched_at IS NOT NULL
            ORDER BY d""", (uid, uid)) if r["d"]]
        longest = cur = 0
        longest_end = None
        prev = None
        for d0 in dates:
            if prev and (date.fromisoformat(d0) - date.fromisoformat(prev)).days == 1:
                cur += 1
            else:
                cur = 1
            if cur > longest:
                longest, longest_end = cur, d0
            prev = d0
        current_streak = 0
        if dates:
            t = date.today()
            ds = set(dates)
            probe = t if t.isoformat() in ds else t - timedelta(days=1)
            while probe.isoformat() in ds:
                current_streak += 1
                probe -= timedelta(days=1)
        big_day = biggest_binge(con, uid)
        first = con.execute("""SELECT w.watched_at, s.title FROM watches w JOIN shows s ON s.id=w.show_id
            WHERE w.user_id=? ORDER BY w.watched_at LIMIT 1""", (uid,)).fetchone()

        yearly = con.execute("""SELECT substr(watched_at,1,4) y, COUNT(*) c FROM watches
            WHERE user_id=? GROUP BY y ORDER BY y""", (uid,)).fetchall()
        heat = con.execute("""SELECT strftime('%Y', watched_at, 'localtime') y,
              strftime('%w', watched_at, 'localtime') d,
              strftime('%H', watched_at, 'localtime') h, COUNT(*) c
            FROM watches WHERE user_id=? GROUP BY y, d, h""", (uid,)).fetchall()

        # completion buckets over followed shows
        comp = {"finished": 0, "in_progress": 0, "up_to_date": 0, "dropped": 0, "not_started": 0}
        for r in con.execute("""
            SELECT f.archived, s.status,
              (SELECT COUNT(*) FROM episodes e WHERE e.show_id=s.id AND e.season>0
                 AND e.air_date IS NOT NULL AND e.air_date<=date('now')) aired,
              (SELECT COUNT(*) FROM watches w WHERE w.user_id=f.user_id AND w.show_id=s.id
                 AND w.season>0) watched
            FROM follows f JOIN shows s ON s.id=f.show_id WHERE f.user_id=?""", (uid,)):
            if r["archived"]:
                comp["dropped"] += 1
            elif r["watched"] == 0:
                comp["not_started"] += 1
            elif r["watched"] >= r["aired"]:
                comp["finished" if r["status"] in ("Ended", "Canceled") else "up_to_date"] += 1
            else:
                comp["in_progress"] += 1

        decades = con.execute("""SELECT (m.year/10)*10 dec, COUNT(*) c FROM movie_states ms
            JOIN movies m ON m.id=ms.movie_id WHERE ms.user_id=? AND ms.state='watched'
            AND m.year IS NOT NULL GROUP BY dec ORDER BY dec""", (uid,)).fetchall()
        rating_hist = con.execute("""SELECT rating r, COUNT(*) c FROM (
            SELECT rating FROM movie_states WHERE user_id=? AND rating IS NOT NULL
            UNION ALL SELECT rating FROM follows WHERE user_id=? AND rating IS NOT NULL)
            GROUP BY rating ORDER BY rating""", (uid, uid)).fetchall()
        top_rated = con.execute("""SELECT title, rating FROM (
            SELECT m.title, ms.rating FROM movie_states ms JOIN movies m ON m.id=ms.movie_id
              WHERE ms.user_id=? AND ms.rating IS NOT NULL
            UNION ALL SELECT s.title, f.rating FROM follows f JOIN shows s ON s.id=f.show_id
              WHERE f.user_id=? AND f.rating IS NOT NULL)
            ORDER BY rating DESC, title LIMIT 8""", (uid, uid)).fetchall()

    days_active = max((date.today() - date.fromisoformat(dates[0])).days, 1) if dates else 1
    heat_years = _heat_by_year(heat)
    return {
        "episodes": eps_total, "tv_minutes": minutes, "movies": mov["c"],
        "movie_minutes": mov["m"], "shows": shows_n,
        "this_year": {"episodes": this_year, "movies": movies_this_year,
                      "top": [dict(r) for r in top_this_year]},
        "monthly": [{"ym": k, "count": v} for k, v in sorted(agg.items())],
        "yearly": [{"y": r["y"], "c": r["c"]} for r in yearly if r["y"]],
        "top_shows": [dict(r) for r in top],
        "genres": sorted(({"name": k, "count": v} for k, v in gcount.items()),
                         key=lambda x: -x["count"])[:8],
        "heatmap": heat_years.get("all", []),
        "heat_years": heat_years,
        "streak": {"current": current_streak, "longest": longest, "longest_end": longest_end},
        "big_day": big_day,
        "first_watch": dict(first) if first else None,
        "per_day": round((eps_total + mov["c"]) / days_active, 2),
        "completion": comp,
        "movie_decades": [{"dec": r["dec"], "c": r["c"]} for r in decades],
        "rating_hist": {r["r"]: r["c"] for r in rating_hist},
        "top_rated": [dict(r) for r in top_rated],
    }


@app.get("/api/stats")
def stats(user=Depends(current_user)):
    return compute_stats(user["id"])


@app.get("/api/profile/{username}/stats")
def stats_public(username: str, user=Depends(current_user)):
    with db() as con:
        u = resolve_member(con, username)
    return compute_stats(u["id"])


# ------------------------------------------------- advanced stats (Trakt-VIP parity)

COUNTRY_NAMES = {
    "US": "United States", "GB": "United Kingdom", "CA": "Canada", "JP": "Japan",
    "KR": "South Korea", "FR": "France", "DE": "Germany", "ES": "Spain", "IT": "Italy",
    "AU": "Australia", "NZ": "New Zealand", "IN": "India", "CN": "China", "TW": "Taiwan",
    "HK": "Hong Kong", "BR": "Brazil", "MX": "Mexico", "AR": "Argentina", "SE": "Sweden",
    "NO": "Norway", "DK": "Denmark", "FI": "Finland", "IS": "Iceland", "NL": "Netherlands",
    "BE": "Belgium", "IE": "Ireland", "RU": "Russia", "PL": "Poland", "TR": "Turkey",
    "IL": "Israel", "ZA": "South Africa", "TH": "Thailand", "PH": "Philippines",
    "ID": "Indonesia", "SG": "Singapore", "MY": "Malaysia", "VN": "Vietnam", "PT": "Portugal",
    "GR": "Greece", "AT": "Austria", "CH": "Switzerland", "CZ": "Czechia", "HU": "Hungary",
    "CO": "Colombia", "CL": "Chile", "UA": "Ukraine", "AE": "UAE", "SA": "Saudi Arabia",
    "EG": "Egypt", "NG": "Nigeria", "RO": "Romania", "LU": "Luxembourg",
}


def compute_advanced(con, uid):
    show_eps = {r["show_id"]: r["c"] for r in con.execute(
        "SELECT show_id, COUNT(*) c FROM watches WHERE user_id=? GROUP BY show_id", (uid,))}
    networks, countries = {}, {}
    actors, directors = {}, {}
    if show_eps:
        ids = list(show_eps)
        rows = con.execute("SELECT id,title,details FROM shows WHERE id IN (%s)"
                           % ",".join("?" * len(ids)), ids).fetchall()
        for r in rows:
            eps = show_eps.get(r["id"], 0)
            det = json.loads(r["details"]) if r["details"] else {}
            for n in (det.get("networks") or []):
                networks[n] = networks.get(n, 0) + eps
            for iso in (det.get("origin") or "").split(","):
                iso = iso.strip()
                if iso:
                    countries[iso] = countries.get(iso, 0) + eps
            for c in (det.get("cast") or [])[:10]:
                a = actors.setdefault(c["id"], {"name": c["name"], "img": c.get("img"),
                                                "shows": 0, "movies": 0})
                a["shows"] += 1
            for name in (det.get("created_by") or []):
                directors[name] = directors.get(name, 0) + 1

    mov_ids = [r["movie_id"] for r in con.execute(
        "SELECT movie_id FROM movie_states WHERE user_id=? AND state='watched'", (uid,))]
    studios = {}
    if mov_ids:
        rows = con.execute("SELECT id,title,details FROM movies WHERE id IN (%s)"
                           % ",".join("?" * len(mov_ids)), mov_ids).fetchall()
        for r in rows:
            det = json.loads(r["details"]) if r["details"] else {}
            for n in (det.get("companies") or []):
                studios[n] = studios.get(n, 0) + 1
            for iso in (det.get("countries") or []):
                countries[iso] = countries.get(iso, 0) + 1
            for c in (det.get("cast") or [])[:10]:
                a = actors.setdefault(c["id"], {"name": c["name"], "img": c.get("img"),
                                                "shows": 0, "movies": 0})
                a["movies"] += 1
            for name in (det.get("directors") or []):
                directors[name] = directors.get(name, 0) + 1

    def top(d, key=lambda kv: -kv[1], n=10):
        return sorted(d.items(), key=key)[:n]

    people = sorted(actors.values(), key=lambda a: -(a["shows"] + a["movies"]))
    people = [a for a in people if (a["shows"] + a["movies"]) > 1][:12] or \
        sorted(actors.values(), key=lambda a: -(a["shows"] + a["movies"]))[:12]
    return {
        "networks": [{"name": k, "count": v} for k, v in top(networks)],
        "studios": [{"name": k, "count": v} for k, v in top(studios)],
        "countries": [{"code": k, "name": COUNTRY_NAMES.get(k, k), "count": v}
                      for k, v in top(countries, n=12)],
        "actors": [{"name": a["name"], "img": a["img"],
                    "shows": a["shows"], "movies": a["movies"]} for a in people],
        "directors": [{"name": k, "count": v} for k, v in top(directors)],
        "movies_enriched": con.execute(
            "SELECT COUNT(*) c FROM movies WHERE id IN (%s) AND details IS NOT NULL"
            % (",".join("?" * len(mov_ids)) or "NULL"), mov_ids).fetchone()["c"] if mov_ids else 0,
        "movies_total": len(mov_ids),
    }


@app.get("/api/stats/advanced")
def stats_advanced(user=Depends(current_user)):
    with db() as con:
        mov_ids = [r["movie_id"] for r in con.execute(
            "SELECT movie_id FROM movie_states WHERE user_id=? AND state='watched'", (user["id"],))]
        backfill_movie_details(con, mov_ids, cap=8)
        return compute_advanced(con, user["id"])


@app.get("/api/profile/{username}/stats/advanced")
def stats_advanced_public(username: str, user=Depends(current_user)):
    with db() as con:
        u = resolve_member(con, username)
        return compute_advanced(con, u["id"])


# ------------------------------------------------- year in review (shareable recap)

def compute_recap(con, uid, year):
    y = str(year)
    lo, hi = f"{y}-01-01", f"{y}-12-31T23:59:59.999999"
    eps = con.execute("""SELECT COUNT(*) c, COALESCE(SUM(COALESCE(e.runtime,s.avg_runtime,30)),0) m
        FROM watches w JOIN shows s ON s.id=w.show_id
        LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
        WHERE w.user_id=? AND w.watched_at>=? AND w.watched_at<=?""", (uid, lo, hi)).fetchone()
    mov = con.execute("""SELECT COUNT(*) c, COALESCE(SUM(COALESCE(m.runtime,110)),0) m
        FROM movie_states ms JOIN movies m ON m.id=ms.movie_id
        WHERE ms.user_id=? AND ms.state='watched' AND ms.watched_at>=? AND ms.watched_at<=?""",
        (uid, lo, hi)).fetchone()
    top_shows = con.execute("""SELECT s.title, s.poster, COUNT(*) eps,
          SUM(COALESCE(e.runtime, s.avg_runtime, 30)) mins
        FROM watches w JOIN shows s ON s.id=w.show_id
        LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
        WHERE w.user_id=? AND w.watched_at>=? AND w.watched_at<=?
        GROUP BY s.id ORDER BY mins DESC LIMIT 5""", (uid, lo, hi)).fetchall()
    top_movies = con.execute("""SELECT m.title, m.poster, ms.rating
        FROM movie_states ms JOIN movies m ON m.id=ms.movie_id
        WHERE ms.user_id=? AND ms.state='watched' AND ms.watched_at>=? AND ms.watched_at<=?
        ORDER BY ms.rating IS NULL, ms.rating DESC, ms.watched_at DESC LIMIT 5""",
        (uid, lo, hi)).fetchall()
    grows = con.execute("""SELECT s.genres FROM watches w JOIN shows s ON s.id=w.show_id
        WHERE w.user_id=? AND s.genres!='' AND w.watched_at>=? AND w.watched_at<=?""",
        (uid, lo, hi)).fetchall()
    gcount = {}
    for r in grows:
        for g in r["genres"].split(","):
            gcount[g] = gcount.get(g, 0) + 1
    monthly = con.execute("""SELECT substr(watched_at,6,2) mo, COUNT(*) c FROM watches
        WHERE user_id=? AND watched_at>=? AND watched_at<=? GROUP BY mo""", (uid, lo, hi)).fetchall()
    months = [0] * 12
    for r in monthly:
        if r["mo"]:
            months[int(r["mo"]) - 1] += r["c"]
    binge = biggest_binge(con, uid, lo, hi)
    first = con.execute("""SELECT w.watched_at, s.title FROM watches w JOIN shows s ON s.id=w.show_id
        WHERE w.user_id=? AND w.watched_at>=? AND w.watched_at<=? ORDER BY w.watched_at LIMIT 1""",
        (uid, lo, hi)).fetchone()
    last = con.execute("""SELECT w.watched_at, s.title FROM watches w JOIN shows s ON s.id=w.show_id
        WHERE w.user_id=? AND w.watched_at>=? AND w.watched_at<=? ORDER BY w.watched_at DESC LIMIT 1""",
        (uid, lo, hi)).fetchone()
    new_shows = con.execute("""SELECT COUNT(*) c FROM (
        SELECT show_id, MIN(watched_at) f FROM watches WHERE user_id=? GROUP BY show_id
        HAVING f>=? AND f<=?)""", (uid, lo, hi)).fetchone()["c"]
    mo_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    busiest = max(range(12), key=lambda i: months[i]) if any(months) else None
    genres = sorted(({"name": k, "count": v} for k, v in gcount.items()), key=lambda x: -x["count"])[:5]
    return {
        "year": year,
        "has_data": (eps["c"] + mov["c"]) > 0,
        "episodes": eps["c"], "movies": mov["c"],
        "minutes": eps["m"] + mov["m"], "tv_minutes": eps["m"], "movie_minutes": mov["m"],
        "top_shows": [dict(r) for r in top_shows],
        "top_movies": [dict(r) for r in top_movies],
        "genres": genres,
        "months": months,
        "busiest_month": mo_names[busiest] if busiest is not None else None,
        "busiest_month_count": months[busiest] if busiest is not None else 0,
        "binge": binge,
        "first_watch": dict(first) if first else None,
        "last_watch": dict(last) if last else None,
        "new_shows": new_shows,
    }


def recap_year_unlocked(year):
    """A year's recap unlocks only once that year is over — any past year, or the current
    year once it's December. (Keeps '2026 wrapped' from showing up in July.)"""
    now = datetime.now()
    return year < now.year or (year == now.year and now.month == 12)


def available_recap_years(con, uid):
    """Years this user actually watched something in that are also unlocked, newest first."""
    years = set()
    for tbl, cond in (("watches", ""), ("movie_states", " AND state='watched'")):
        for r in con.execute(f"SELECT DISTINCT substr(watched_at,1,4) y FROM {tbl} "
                             f"WHERE user_id=? AND watched_at IS NOT NULL{cond}", (uid,)):
            if r["y"] and r["y"].isdigit():
                years.add(int(r["y"]))
    return sorted((y for y in years if recap_year_unlocked(y)), reverse=True)


def recap_current_pending(con, uid):
    """The current year's recap IF unlocked (December), has data, and not yet seen — the
    one-time slideshow to auto-present. Otherwise None."""
    cy = datetime.now().year
    if not recap_year_unlocked(cy) or cy not in available_recap_years(con, uid):
        return None
    seen = con.execute("SELECT 1 FROM recap_seen WHERE user_id=? AND year=?", (uid, cy)).fetchone()
    return None if seen else cy


@app.get("/api/recap")
def recap_index(user=Depends(current_user)):
    with db() as con:
        return {"years": available_recap_years(con, user["id"]),
                "autoshow": recap_current_pending(con, user["id"])}


@app.get("/api/recap/{year}")
def recap(year: int, user=Depends(current_user)):
    if not recap_year_unlocked(year):
        return {"year": year, "locked": True, "has_data": False}
    with db() as con:
        d = compute_recap(con, user["id"], year)
        d["years"] = available_recap_years(con, user["id"])
        return d


@app.post("/api/recap/{year}/seen")
def recap_seen_mark(year: int, user=Depends(current_user)):
    with db() as con:
        con.execute("INSERT OR IGNORE INTO recap_seen(user_id,year,seen_at) VALUES(?,?,?)",
                    (user["id"], year, datetime.utcnow().isoformat()))
    return {"ok": True}


@app.get("/api/profile/{username}/recap/{year}")
def recap_public(username: str, year: int, user=Depends(current_user)):
    if not recap_year_unlocked(year):
        return {"year": year, "locked": True, "has_data": False}
    with db() as con:
        u = resolve_member(con, username)
        d = compute_recap(con, u["id"], year)
        d["years"] = available_recap_years(con, u["id"])
        return d


# ---------------------------------------------------------------- history

@app.get("/api/history")
def history(user=Depends(current_user), type: str = "tv", cursor: str = ""):
    uid = user["id"]
    with db() as con:
        if type == "movie":
            q = """SELECT m.id, m.title, m.poster, m.year, ms.rating, ms.watched_at,
                     COALESCE(m.runtime, 110) runtime
                   FROM movie_states ms JOIN movies m ON m.id=ms.movie_id
                   WHERE ms.user_id=? AND ms.state='watched' AND ms.watched_at IS NOT NULL"""
            params = [uid]
            if cursor:
                q += " AND ms.watched_at < ?"
                params.append(cursor)
            q += " ORDER BY ms.watched_at DESC LIMIT 120"
            rows = [dict(r) for r in con.execute(q, params)]
            return {"items": rows, "cursor": rows[-1]["watched_at"] if len(rows) == 120 else None}

        q = """SELECT w.show_id, w.season, w.number, w.watched_at, s.title, s.poster,
                 e.title AS ep_title, COALESCE(e.runtime, s.avg_runtime, 30) runtime
               FROM watches w JOIN shows s ON s.id=w.show_id
               LEFT JOIN episodes e ON e.show_id=w.show_id AND e.season=w.season AND e.number=w.number
               WHERE w.user_id=?"""
        params = [uid]
        if cursor:
            q += " AND w.watched_at < ?"
            params.append(cursor)
        q += " ORDER BY w.watched_at DESC LIMIT 600"
        rows = con.execute(q, params).fetchall()
    hit_limit = len(rows) == 600
    last_day = rows[-1]["watched_at"][:10] if rows else None
    # if one enormous day fills the whole page, paginate inside it by timestamp
    single_day = hit_limit and rows and rows[0]["watched_at"][:10] == last_day
    groups, order = {}, []
    for r in rows:
        day = r["watched_at"][:10]
        if hit_limit and not single_day and day == last_day:
            continue        # trailing day may be incomplete — refetched whole next page
        key = (day, r["show_id"])
        if key not in groups:
            groups[key] = {"day": day, "show_id": r["show_id"], "title": r["title"],
                           "poster": r["poster"], "eps": [], "minutes": 0,
                           "last_at": r["watched_at"]}
            order.append(key)
        g = groups[key]
        g["eps"].append([r["season"], r["number"], r["ep_title"]])
        g["minutes"] += r["runtime"] or 30
    items = [groups[k] for k in order]
    next_cursor = None
    if hit_limit:
        next_cursor = rows[-1]["watched_at"] if single_day else last_day + "T23:59:59.999999"
    return {"items": items, "cursor": next_cursor}


# ---------------------------------------------------------------- imports

IMPORT_STATUS = {}


def _import_tvtime(uid, zbytes):
    st = IMPORT_STATUS[uid] = {"state": "running", "done": 0, "total": 0, "errors": []}
    try:
        zf = zipfile.ZipFile(BytesIO(zbytes))
        names = {os.path.basename(n): n for n in zf.namelist()}
        movies_j = json.loads(zf.read(names["movies.json"])) if "movies.json" in names else []
        shows_j = json.loads(zf.read(names["shows.json"])) if "shows.json" in names else []
        acts = {}
        if "activity_history.csv" in names:
            import csv as _csv
            for r in _csv.DictReader(zf.read(names["activity_history.csv"]).decode().splitlines()):
                if r["type"] == "show" and r["tvdb_id"]:
                    acts[int(r["tvdb_id"])] = r
        st["total"] = len(movies_j) + len(shows_j)
        with db() as con:
            for m in movies_j:
                st["done"] += 1
                found = None
                imdb = m["id"].get("imdb")
                if imdb and imdb != "-1":
                    r = tmdb(f"/find/{imdb}", external_source="imdb_id")
                    if r and r.get("movie_results"):
                        found = r["movie_results"][0]
                if not found and m.get("title"):
                    r = tmdb("/search/movie", query=m["title"])
                    cands = (r or {}).get("results") or []
                    exact = [c for c in cands if (c.get("title") or "").lower() == m["title"].lower()]
                    found = max(exact or cands, key=lambda c: c.get("vote_count", 0)) if cands else None
                if not found:
                    st["errors"].append(f"movie not matched: {m.get('title')}")
                    continue
                upsert_movie(con, found["id"])
                w = (m.get("watched_at") or "").rstrip("Z").split(".")[0] or None
                con.execute("""INSERT INTO movie_states(user_id,movie_id,state,watched_at,rating)
                    VALUES(?,?,?,?,?) ON CONFLICT(user_id,movie_id) DO NOTHING""",
                    (uid, found["id"], "watched" if m.get("is_watched") else "watchlist", w,
                     m.get("rating")))
            for sh in shows_j:
                st["done"] += 1
                tvdb = sh["id"].get("tvdb")
                meta = acts.get(tvdb, {})
                found = None
                if tvdb:
                    r = tmdb(f"/find/{tvdb}", external_source="tvdb_id")
                    if r and r.get("tv_results"):
                        found = r["tv_results"][0]
                if not found and meta.get("title"):
                    r = tmdb("/search/tv", query=meta["title"])
                    if r and r.get("results"):
                        found = r["results"][0]
                if not found:
                    st["errors"].append(f"show not matched: {meta.get('title') or tvdb}")
                    continue
                sid = found["id"]
                if not con.execute("SELECT 1 FROM shows WHERE id=?", (sid,)).fetchone():
                    upsert_show(con, sid)
                archived = 1 if meta.get("status") == "stopped" else 0
                con.execute("""INSERT OR IGNORE INTO follows(user_id,show_id,added_at,archived,rating)
                    VALUES(?,?,?,?,?)""", (uid, sid, datetime.utcnow().isoformat(), archived,
                                           int(meta["rating"]) if meta.get("rating") else None))
                rows = []
                for se in sh.get("seasons", []):
                    for e in se.get("episodes", []):
                        if e.get("is_watched"):
                            w = (e.get("watched_at") or "").rstrip("Z").split(".")[0] or \
                                datetime.utcnow().isoformat()
                            rows.append((uid, sid, se["number"], e["number"], w))
                con.executemany("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                    VALUES(?,?,?,?,?)""", rows)
        st["state"] = "done"
    except Exception as e:  # noqa: BLE001
        log.exception("tvtime import failed")
        st["state"] = "failed"
        st["errors"].append(str(e))


@app.post("/api/import/tvtime")
async def import_tvtime(file: UploadFile, user=Depends(current_user)):
    data = await file.read()
    if IMPORT_STATUS.get(user["id"], {}).get("state") == "running":
        raise HTTPException(409, "an import is already running")
    threading.Thread(target=_import_tvtime, args=(user["id"], data), daemon=True).start()
    return {"ok": True}


@app.get("/api/import/status")
def import_status(user=Depends(current_user)):
    return IMPORT_STATUS.get(user["id"], {"state": "idle"})


# ---------------------------------------------------------------- plex account linking (PIN flow)

def plex_client_id(con):
    cid = setting(con, "plex_client_id")
    if not cid:
        cid = secrets.token_hex(12)
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('plex_client_id',?)", (cid,))
    return cid


def plex_headers(cid):
    return {"X-Plex-Product": "Marquee", "X-Plex-Version": "1.0",
            "X-Plex-Client-Identifier": cid, "X-Plex-Device-Name": "Marquee",
            "Accept": "application/json"}


@app.post("/api/plex/pin")
def plex_pin(user=Depends(current_user)):
    with db() as con:
        cid = plex_client_id(con)
    r = httpx.post("https://plex.tv/api/v2/pins", data={"strong": "true"},
                   headers=plex_headers(cid), timeout=30)
    r.raise_for_status()
    d = r.json()
    auth_url = ("https://app.plex.tv/auth#?clientID=" + cid +
                "&code=" + d["code"] +
                "&context%5Bdevice%5D%5Bproduct%5D=Marquee")
    return {"id": d["id"], "code": d["code"], "url": auth_url}


@app.get("/api/plex/pin/{pin_id}")
def plex_pin_poll(pin_id: int, user=Depends(current_user)):
    with db() as con:
        cid = plex_client_id(con)
    r = httpx.get(f"https://plex.tv/api/v2/pins/{pin_id}", headers=plex_headers(cid), timeout=30)
    if r.status_code == 404:
        raise HTTPException(410, "pin expired — start over")
    r.raise_for_status()
    tok = r.json().get("authToken")
    if not tok:
        return {"linked": False}
    acct = httpx.get("https://plex.tv/api/v2/user",
                     headers={**plex_headers(cid), "X-Plex-Token": tok}, timeout=30)
    acct.raise_for_status()
    a = acct.json()
    username = a.get("username") or a.get("title")
    with db() as con:
        con.execute("UPDATE users SET plex_username=?, plex_token=? WHERE id=?",
                    (username, tok, user["id"]))
    return {"linked": True, "username": username, "thumb": a.get("thumb"),
            "email": a.get("email")}


@app.post("/api/plex/unlink")
def plex_unlink(user=Depends(current_user)):
    with db() as con:
        con.execute("UPDATE users SET plex_username=NULL, plex_token=NULL WHERE id=?", (user["id"],))
    return {"ok": True}


@app.get("/api/plex/status")
def plex_status(user=Depends(current_user)):
    with db() as con:
        me = con.execute("SELECT plex_username, plex_token FROM users WHERE id=?",
                         (user["id"],)).fetchone()
        token = plex_owner_token(con)
        return {"plex_username": me["plex_username"],
                "has_own_token": bool(me["plex_token"]),
                "direct_sync": bool(token),
                "last_event": setting(con, "webhook_last"),
                "last_event_user": setting(con, "webhook_last_user"),
                "last_poll": setting(con, "plex_last_poll")}


# ---------------------------------------------------------------- plex direct sync

PLEX_URL = os.environ.get("PLEX_URL", "http://192.168.10.42:32400")
_plex_meta_cache = {}     # ratingKey -> tmdb id
_plex_accounts = {"at": 0, "map": {}}


def plex_get(path, token, **params):
    r = httpx.get(f"{PLEX_URL}{path}", params={**params, "X-Plex-Token": token},
                  headers={"Accept": "application/json"}, timeout=20)
    r.raise_for_status()
    return r.json()


def plex_owner_token(con):
    r = con.execute("""SELECT plex_token FROM users
        WHERE plex_token IS NOT NULL ORDER BY is_admin DESC LIMIT 1""").fetchone()
    return r["plex_token"] if r else None


def plex_account_map(token):
    """plex accountID -> plex username (owner id 1 + real id + friends). cached 12h."""
    if time.time() - _plex_accounts["at"] < 43200 and _plex_accounts["map"]:
        return _plex_accounts["map"]
    m = {}
    with db() as con:
        cid = plex_client_id(con)
    try:
        me = httpx.get("https://plex.tv/api/v2/user",
                       headers={**plex_headers(cid), "X-Plex-Token": token}, timeout=20).json()
        m[1] = me.get("username")
        m[me.get("id")] = me.get("username")
        fr = httpx.get("https://plex.tv/api/v2/friends",
                       headers={**plex_headers(cid), "X-Plex-Token": token}, timeout=20)
        if fr.status_code == 200:
            for f in fr.json():
                m[f.get("id")] = f.get("username") or f.get("title")
    except httpx.HTTPError:
        log.exception("plex account map fetch failed")
    if m:
        _plex_accounts.update({"at": time.time(), "map": m})
    return m


def plex_tmdb_id(rating_key, token):
    if rating_key in _plex_meta_cache:
        return _plex_meta_cache[rating_key]
    try:
        d = plex_get(f"/library/metadata/{rating_key}", token, includeGuids=1)
        guids = (d["MediaContainer"]["Metadata"][0].get("Guid") or [])
        for g in guids:
            mm = re.match(r"tmdb://(\d+)", g.get("id", ""))
            if mm:
                _plex_meta_cache[rating_key] = int(mm.group(1))
                return _plex_meta_cache[rating_key]
    except Exception:  # noqa: BLE001
        pass
    _plex_meta_cache[rating_key] = None
    return None


def record_plex_watch(con, uid, mtype, tmdb_id, season, number, watched_at=None):
    """Returns True only when this creates a *genuinely new* watch (so callers can notify)."""
    now = watched_at or datetime.utcnow().isoformat()
    if mtype == "movie" and tmdb_id:
        upsert_movie(con, tmdb_id)
        prev = con.execute("SELECT state FROM movie_states WHERE user_id=? AND movie_id=?",
                           (uid, tmdb_id)).fetchone()
        con.execute("""INSERT INTO movie_states(user_id,movie_id,state,watched_at)
            VALUES(?,?,?,?) ON CONFLICT(user_id,movie_id) DO UPDATE SET state='watched',
            watched_at=COALESCE(movie_states.watched_at, excluded.watched_at)""",
            (uid, tmdb_id, "watched", now))
        return not (prev and prev["state"] == "watched")
    if mtype == "episode" and tmdb_id and number:
        if not con.execute("SELECT 1 FROM shows WHERE id=?", (tmdb_id,)).fetchone():
            upsert_show(con, tmdb_id)
        con.execute("INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)",
                    (uid, tmdb_id, now))
        cur = con.execute("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
            VALUES(?,?,?,?,?)""", (uid, tmdb_id, season or 0, number, now))
        return cur.rowcount > 0
    return False


def plex_poll_once():
    with db() as con:
        token = plex_owner_token(con)
        if not token:
            return "no linked plex account with a token"
        cursor = int(setting(con, "plex_history_cursor") or 0)
        users_by_plex = {(r["plex_username"] or "").lower(): r["id"] for r in
                         con.execute("SELECT id, plex_username FROM users WHERE plex_username IS NOT NULL")}
    if not cursor:
        cursor = int(time.time())   # start from now on first run
    amap = plex_account_map(token)
    d = plex_get("/status/sessions/history/all", token, sort="viewedAt:asc",
                 **{"viewedAt>": cursor, "X-Plex-Container-Size": 100})
    entries = d.get("MediaContainer", {}).get("Metadata", []) or []
    marked = 0
    newest = cursor
    new_watches = []
    with db() as con:
        for e in entries:
            newest = max(newest, int(e.get("viewedAt") or 0))
            uname = (amap.get(e.get("accountID")) or "").lower()
            uid = users_by_plex.get(uname)
            if not uid:
                continue
            when = datetime.utcfromtimestamp(int(e["viewedAt"])).isoformat() if e.get("viewedAt") else None
            if e.get("type") == "movie":
                tid = plex_tmdb_id(e.get("ratingKey"), token)
                if record_plex_watch(con, uid, "movie", tid, None, None, when):
                    marked += 1
                    new_watches.append((uid, "movie", tid, None, None))
            elif e.get("type") == "episode":
                # history entries carry grandparentKey (a path) but NOT grandparentRatingKey,
                # so derive the show's ratingKey from the path when the field is absent
                gk = e.get("grandparentRatingKey") or (e.get("grandparentKey") or "").rsplit("/", 1)[-1]
                tid = plex_tmdb_id(gk, token)
                s, n = int(e.get("parentIndex") or 0), int(e.get("index") or 0)
                if record_plex_watch(con, uid, "episode", tid, s, n, when):
                    marked += 1
                    new_watches.append((uid, "episode", tid, s, n))
        if new_watches:
            notify_auto_tracked(con, new_watches)
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('plex_history_cursor',?)",
                    (str(newest),))
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('plex_last_poll',?)",
                    (datetime.utcnow().isoformat(),))
        if marked:
            con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last',?)",
                        (datetime.utcnow().isoformat(),))
            con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last_user',?)",
                        ("plex history",))
    return f"marked {marked} of {len(entries)} new history entries"


def plex_poll_loop():
    time.sleep(90)
    while True:
        try:
            msg = plex_poll_once()
            log.debug("plex poll: %s", msg)
        except Exception:  # noqa: BLE001
            log.exception("plex poll failed")
        time.sleep(75)


@app.post("/api/webhook/plex")
async def plex_native_webhook(request: Request):
    """Native Plex webhook (Plex Pass): multipart form with a `payload` JSON field."""
    form = await request.form()
    try:
        p = json.loads(form.get("payload", "{}"))
    except json.JSONDecodeError:
        raise HTTPException(400, "bad payload")
    if p.get("event") != "media.scrobble":
        return {"ok": True, "ignored": p.get("event")}
    account = ((p.get("Account") or {}).get("title") or "").strip()
    md = p.get("Metadata") or {}
    with db() as con:
        u = con.execute("SELECT id FROM users WHERE plex_username=? COLLATE NOCASE",
                        (account,)).fetchone()
        if not u:
            return {"ok": False, "reason": f"no user mapped to plex account {account}"}
        token = plex_owner_token(con)
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last',?)",
                    (datetime.utcnow().isoformat(),))
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last_user',?)",
                    (account,))
        if md.get("type") == "movie":
            tid = None
            for g in (md.get("Guid") or []):
                mm = re.match(r"tmdb://(\d+)", g.get("id", ""))
                if mm:
                    tid = int(mm.group(1))
            if not tid and token:
                tid = plex_tmdb_id(md.get("ratingKey"), token)
            ok = record_plex_watch(con, u["id"], "movie", tid, None, None)
            return {"ok": ok}
        if md.get("type") == "episode":
            tid = plex_tmdb_id(md.get("grandparentRatingKey"), token) if token else None
            if not tid:
                r = tmdb("/search/tv", query=md.get("grandparentTitle", ""))
                tid = r["results"][0]["id"] if r and r.get("results") else None
            ok = record_plex_watch(con, u["id"], "episode", tid,
                                   int(md.get("parentIndex") or 0), int(md.get("index") or 0))
            return {"ok": ok}
    return {"ok": False, "reason": "unhandled type"}


# ---------------------------------------------------------------- plex (tautulli webhook)

@app.post("/api/webhook/tautulli")
async def tautulli(request: Request):
    with db() as con:
        secret = setting(con, "webhook_secret")
    if not secret or request.query_params.get("secret") != secret:
        raise HTTPException(403, "bad secret")
    body = await request.json()
    account = (body.get("user") or "").strip()
    mtype = body.get("media_type")
    with db() as con:
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last',?)",
                    (datetime.utcnow().isoformat(),))
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('webhook_last_user',?)",
                    (account,))
    guids = " ".join(str(body.get(k) or "") for k in ("guids", "guid", "grandparent_guid", "grandparent_guids"))
    m = re.search(r"tmdb://(\d+)", guids)
    tmdb_id = int(m.group(1)) if m else None
    with db() as con:
        u = con.execute("SELECT id FROM users WHERE plex_username=? COLLATE NOCASE", (account,)).fetchone()
        if not u:
            return {"ok": False, "reason": f"no user mapped to plex account {account}"}
        uid = u["id"]
        now = datetime.utcnow().isoformat()
        if mtype == "movie":
            if not tmdb_id:
                r = tmdb("/search/movie", query=body.get("title", ""), year=body.get("year"))
                tmdb_id = r["results"][0]["id"] if r and r.get("results") else None
            if not tmdb_id:
                return {"ok": False, "reason": "movie not matched"}
            upsert_movie(con, tmdb_id)
            con.execute("""INSERT INTO movie_states(user_id,movie_id,state,watched_at)
                VALUES(?,?,?,?) ON CONFLICT(user_id,movie_id) DO UPDATE SET state='watched',
                watched_at=COALESCE(movie_states.watched_at, excluded.watched_at)""",
                (uid, tmdb_id, "watched", now))
            return {"ok": True, "marked": f"movie {tmdb_id}"}
        if mtype == "episode":
            season, number = int(body.get("season") or 0), int(body.get("episode") or 0)
            if not tmdb_id:
                r = tmdb("/search/tv", query=body.get("grandparent_title", ""))
                tmdb_id = r["results"][0]["id"] if r and r.get("results") else None
            if not tmdb_id or not number:
                return {"ok": False, "reason": "episode not matched"}
            if not con.execute("SELECT 1 FROM shows WHERE id=?", (tmdb_id,)).fetchone():
                upsert_show(con, tmdb_id)
            con.execute("INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)",
                        (uid, tmdb_id, now))
            con.execute("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                VALUES(?,?,?,?,?)""", (uid, tmdb_id, season, number, now))
            return {"ok": True, "marked": f"s{season}e{number} of {tmdb_id}"}
    return {"ok": False, "reason": f"unhandled media_type {mtype}"}


# ---------------------------------------------------------------- overseerr (requests)

def overseerr_cfg(con):
    return setting(con, "overseerr_url"), setting(con, "overseerr_key")


OVERSEERR_STATUS = {1: "none", 2: "pending", 3: "processing", 4: "partial", 5: "available"}
SEASON_PRIO = {"none": 0, "pending": 1, "processing": 2, "partial": 3, "downloading": 4, "available": 5}
_ov_user_cache = {"at": 0, "map": {}}


def overseerr_user_id(url, key, plex_username):
    """Match a Marquee user's Plex username -> Overseerr user id (cached 1h)."""
    if not plex_username:
        return None
    if time.time() - _ov_user_cache["at"] > 3600 or not _ov_user_cache["map"]:
        try:
            r = httpx.get(f"{url}/api/v1/user?take=100", headers={"X-Api-Key": key}, timeout=15)
            r.raise_for_status()
            _ov_user_cache["map"] = {(u.get("plexUsername") or "").lower(): u["id"]
                                     for u in r.json().get("results", [])}
            _ov_user_cache["at"] = time.time()
        except httpx.HTTPError:
            return None
    return _ov_user_cache["map"].get(plex_username.lower())


@app.get("/api/overseerr/me")
def overseerr_me(user=Depends(current_user)):
    """The Overseerr account this Marquee user maps to (via Plex identity)."""
    with db() as con:
        url, key = overseerr_cfg(con)
        u = con.execute("SELECT plex_username FROM users WHERE id=?", (user["id"],)).fetchone()
    if not url or not key:
        return {"enabled": False}
    if not u or not u["plex_username"]:
        return {"enabled": True, "linked": False, "reason": "link Plex first"}
    oid = overseerr_user_id(url, key, u["plex_username"])
    if not oid:
        return {"enabled": True, "linked": False, "reason": "your Plex account isn't on the Overseerr server"}
    return {"enabled": True, "linked": True, "account": u["plex_username"]}


@app.get("/api/request/status/{item_type}/{tmdb_id}")
def request_status(item_type: str, tmdb_id: int, user=Depends(current_user)):
    with db() as con:
        url, key = overseerr_cfg(con)
    if not url or not key:
        return {"enabled": False}
    kind = "movie" if item_type == "movie" else "tv"
    try:
        r = httpx.get(f"{url}/api/v1/{kind}/{tmdb_id}", headers={"X-Api-Key": key}, timeout=15)
        r.raise_for_status()
        d = r.json()
        info = d.get("mediaInfo") or {}
        status = OVERSEERR_STATUS.get(info.get("status", 1), "none")
        out = {"enabled": True, "status": status}
        # download progress from Sonarr/Radarr (via Overseerr). Only genuinely in-flight
        # grabs count — Sonarr also lists "warning"/"queued"/"completed" items (e.g. a stuck
        # upgrade for an episode that already hasFile) which must NOT read as "downloading".
        dl = info.get("downloadStatus") or []
        active = [x for x in dl if x.get("status") == "downloading" and (x.get("sizeLeft") or 0) > 0]
        if active:
            ps, eta = [], None
            for x in active:
                sz, left = x.get("size") or 0, x.get("sizeLeft") or 0
                if sz:
                    ps.append(100 * (sz - left) / sz)
                eta = eta or x.get("timeLeft")
            out["download"] = {"active": len(active),
                               "progress": round(sum(ps) / len(ps)) if ps else 0, "eta": eta}
        if kind == "tv":
            season_status = {s["seasonNumber"]: OVERSEERR_STATUS.get(s.get("status", 1), "none")
                             for s in (info.get("seasons") or [])}
            # A just-approved season isn't reflected in mediaInfo.seasons yet, so fold in the
            # request state — otherwise a requested season reads "none", looks un-requested,
            # and the user re-requests it (Overseerr request enum: 1=pending, 2=approved).
            REQ_SEASON = {1: "pending", 2: "processing"}
            for rq in (info.get("requests") or []):
                rst = REQ_SEASON.get(rq.get("status"))
                if not rst:
                    continue
                for s in (rq.get("seasons") or []):
                    sn = s.get("seasonNumber")
                    if sn is not None and SEASON_PRIO.get(rst, 0) > SEASON_PRIO.get(season_status.get(sn, "none"), 0):
                        season_status[sn] = rst
            # per-season download progress, keyed off the Sonarr episode.seasonNumber
            dl_by_season = {}
            for x in active:
                sn = (x.get("episode") or {}).get("seasonNumber")
                if sn is None:
                    continue
                sz, left = x.get("size") or 0, x.get("sizeLeft") or 0
                b = dl_by_season.setdefault(sn, {"ps": [], "eta": None})
                if sz:
                    b["ps"].append(100 * (sz - left) / sz)
                b["eta"] = b["eta"] or x.get("timeLeft")
            seasons = []
            for s in d.get("seasons", []):
                sn = s.get("seasonNumber", 0)
                if sn <= 0:
                    continue
                row = {"number": sn, "episodes": s.get("episodeCount", 0),
                       "status": season_status.get(sn, "none")}
                if sn in dl_by_season:
                    b = dl_by_season[sn]
                    row["status"] = "downloading"
                    row["progress"] = round(sum(b["ps"]) / len(b["ps"])) if b["ps"] else 0
                    if b["eta"]:
                        row["eta"] = b["eta"]
                seasons.append(row)
            out["seasons"] = seasons
        return out
    except httpx.HTTPError:
        return {"enabled": True, "status": "unknown"}


@app.post("/api/request")
async def make_request(request: Request, user=Depends(current_user)):
    body = await request.json()
    item_type, tmdb_id = body["item_type"], int(body["item_id"])
    with db() as con:
        url, key = overseerr_cfg(con)
        u = con.execute("SELECT plex_username FROM users WHERE id=?", (user["id"],)).fetchone()
    if not url or not key:
        raise HTTPException(400, "Overseerr isn't configured")
    payload = {"mediaType": "movie" if item_type == "movie" else "tv", "mediaId": tmdb_id}
    if item_type == "show":
        payload["seasons"] = body.get("seasons") or "all"     # list of season numbers or "all"
    oid = overseerr_user_id(url, key, u["plex_username"] if u else None)
    if oid:
        payload["userId"] = oid                                # attribute to the requesting user
    try:
        r = httpx.post(f"{url}/api/v1/request", json=payload, headers={"X-Api-Key": key}, timeout=20)
        if r.status_code == 409:
            return {"ok": True, "status": "already requested"}
        r.raise_for_status()
    except httpx.HTTPError as e:
        raise HTTPException(502, f"Overseerr request failed: {e}")
    return {"ok": True, "status": "requested"}


@app.get("/api/request/config")
def request_config(user=Depends(current_user)):
    with db() as con:
        url, key = overseerr_cfg(con)
    return {"enabled": bool(url and key), "url": url or None}


# ---------------------------------------------------------------- admin

@app.get("/api/users")
def list_users(_=Depends(admin_user)):
    with db() as con:
        return [dict(r) for r in con.execute(
            "SELECT id, username, display_name, avatar, is_admin, plex_username, created_at FROM users")]


@app.get("/api/admin/registration")
def get_registration(_=Depends(admin_user)):
    with db() as con:
        return {"closed": setting(con, "registration_closed") == "1"}


@app.post("/api/admin/registration")
async def set_registration(request: Request, _=Depends(admin_user)):
    body = await request.json()
    with db() as con:
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES('registration_closed',?)",
                    ("1" if body.get("closed") else "0",))
    return {"ok": True}


@app.post("/api/users")
async def create_or_update_user(request: Request, _=Depends(admin_user)):
    body = await request.json()
    with db() as con:
        if body.get("id"):
            if body.get("password"):
                con.execute("UPDATE users SET pass=? WHERE id=?", (hash_pw(body["password"]), body["id"]))
            if "plex_username" in body:
                con.execute("UPDATE users SET plex_username=? WHERE id=?",
                            (body["plex_username"] or None, body["id"]))
        else:
            if not (body.get("username") or "").strip() or len(body.get("password") or "") < 4:
                raise HTTPException(400, "username and a 4+ char password required")
            if con.execute("SELECT 1 FROM users WHERE username=? COLLATE NOCASE",
                           (body["username"].strip(),)).fetchone():
                raise HTTPException(409, "that username is taken")
            cur = con.execute("""INSERT INTO users(username,pass,is_admin,plex_username,created_at)
                VALUES(?,?,?,?,?)""", (body["username"].strip(), hash_pw(body["password"]),
                1 if body.get("is_admin") else 0, body.get("plex_username"),
                datetime.utcnow().isoformat()))
            ensure_default_list(con, cur.lastrowid)
    return {"ok": True}


# ---------------------------------------------------------------- refresh loop

def refresh_catalog():
    """Refetch episode lists for shows that may still change."""
    with db() as con:
        ids = [r["id"] for r in con.execute("""
            SELECT DISTINCT s.id FROM shows s JOIN follows f ON f.show_id=s.id
            WHERE (s.status NOT IN ('Ended','Canceled')
               OR EXISTS (SELECT 1 FROM episodes e WHERE e.show_id=s.id
                          AND (e.air_date IS NULL OR e.air_date>date('now'))))
            AND NOT EXISTS (SELECT 1 FROM episodes e WHERE e.show_id=s.id AND e.source='custom')""")]
    log.info("refresh: %d shows", len(ids))
    for sid in ids:
        try:
            with db() as con:
                upsert_show(con, sid)
        except Exception:  # noqa: BLE001
            log.exception("refresh failed for %s", sid)


def refresh_loop():
    time.sleep(120)
    while True:
        try:
            refresh_catalog()
        except Exception:  # noqa: BLE001
            log.exception("refresh loop error")
        time.sleep(12 * 3600)


# ---------------------------------------------------------------- static

app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.get("/")
def index():
    return FileResponse(os.path.join(STATIC, "index.html"),
                        headers={"Cache-Control": "no-cache"})


@app.get("/api/build")
def build_id():
    return {"build": BUILD}


@app.get("/sw.js")
def service_worker():
    # served from root so its scope covers "/" (a /static/ worker could not control navigations)
    return FileResponse(os.path.join(STATIC, "sw.js"), media_type="application/javascript",
                        headers={"Cache-Control": "no-cache", "Service-Worker-Allowed": "/"})


@app.exception_handler(404)
async def spa_fallback(request: Request, exc):
    if request.url.path.startswith(("/api/", "/static/")):
        return JSONResponse({"detail": "not found"}, status_code=404)
    return FileResponse(os.path.join(STATIC, "index.html"))


@app.on_event("startup")
def startup():
    with db() as con:
        con.executescript(SCHEMA)
        for col in ("overview TEXT", "still TEXT"):
            try:
                con.execute(f"ALTER TABLE episodes ADD COLUMN {col}")
            except sqlite3.OperationalError:
                pass
        try:
            con.execute("ALTER TABLE users ADD COLUMN plex_token TEXT")
        except sqlite3.OperationalError:
            pass
        for stmt in ("ALTER TABLE episodes ADD COLUMN source TEXT DEFAULT 'tmdb'",
                     "ALTER TABLE shows ADD COLUMN details TEXT",
                     "ALTER TABLE episodes ADD COLUMN details TEXT",
                     "ALTER TABLE episodes ADD COLUMN rating REAL",
                     "ALTER TABLE users ADD COLUMN avatar TEXT",
                     "ALTER TABLE users ADD COLUMN display_name TEXT",
                     "ALTER TABLE movies ADD COLUMN details TEXT",
                     "ALTER TABLE users ADD COLUMN banner TEXT",
                     "ALTER TABLE lists ADD COLUMN visibility TEXT DEFAULT 'private'"):
            try:
                con.execute(stmt)
            except sqlite3.OperationalError:
                pass
        for u in con.execute("SELECT id FROM users").fetchall():
            ensure_default_list(con, u["id"])
    os.makedirs(os.path.join(DATA, "avatars"), exist_ok=True)
    os.makedirs(os.path.join(DATA, "banners"), exist_ok=True)
    ensure_vapid()
    threading.Thread(target=refresh_loop, daemon=True).start()
    threading.Thread(target=plex_poll_loop, daemon=True).start()
    threading.Thread(target=notif_loop, daemon=True).start()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8010)
