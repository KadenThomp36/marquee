#!/usr/bin/env python3
"""Fill a *local development* Marquee database with a plausible household.

Developing against the real server is off the table — that database is the
household's actual history — and a stock local instance is empty and has no TMDB
token, so most screens render nothing. This writes fixture rows straight into a
local SQLite file and generates placeholder poster art to go with them, so every
screen has something real-shaped to lay out: multi-season shows part-watched,
films on both shelves, reading with sessions, lists, reviews, notifications, and
an unseen milestone so the completion fanfare fires on first launch.

Nothing here touches the network, and nothing here is real.

Usage:
    python3 Tools/seed_dev_server.py --db ~/path/to/dev/marquee.db \\
        --art-dir ~/path/to/marquee/static/devart \\
        --art-base http://127.0.0.1:8010/static/devart

Needs: pip install pillow
"""
import argparse
import hashlib
import json
import os
import random
import sqlite3
from datetime import date, datetime, timedelta

from PIL import Image, ImageDraw, ImageFont

FONT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Shared", "Resources", "Fonts")

# Invented titles, so nothing here can be mistaken for a real catalogue.
SHOWS = [
    ("The Long Weekend", 2019, "Returning Series", "Drama,Comedy", 42, 4, [10, 10, 10, 6]),
    ("Brass & Bone", 2016, "Ended", "Drama,Crime", 55, 5, [8, 10, 10, 10, 8]),
    ("Nightporter", 2021, "Returning Series", "Thriller,Mystery", 48, 3, [8, 8, 8]),
    ("Cormorant Bay", 2014, "Ended", "Drama", 51, 6, [12, 12, 12, 12, 12, 10]),
    ("Signal Hill", 2023, "Returning Series", "Sci-Fi,Drama", 46, 2, [8, 8]),
    ("The Paper Orchestra", 2018, "Ended", "Comedy", 24, 3, [12, 12, 12]),
    ("Vesper Line", 2022, "Returning Series", "Animation,Sci-Fi", 24, 2, [12, 12]),
    ("Harrow Street", 2012, "Canceled", "Crime", 44, 2, [13, 9]),
]

MOVIES = [
    ("The Salt Road", 2021, 127, "Drama"), ("Nocturne for Two", 2019, 104, "Romance,Drama"),
    ("Ironbark", 2023, 141, "Action,Thriller"), ("A Quiet Inheritance", 2017, 98, "Drama"),
    ("Lantern Season", 2020, 112, "Fantasy"), ("The Understudy", 2022, 95, "Comedy"),
    ("Cold Harbour", 2015, 133, "Thriller"), ("Marigold Street", 2024, 108, "Drama,Comedy"),
    ("Every Third Winter", 2018, 121, "Drama"), ("The Cartographer", 2025, 116, "Adventure"),
    ("Blue Hour", 2024, 99, "Romance"), ("Tin Soldiers", 2016, 145, "War,Drama"),
]

BOOKS = [
    ("The Weight of Small Things", "Ada Ferrers", 2019, 384, "Literary Fiction"),
    ("Cartography of Salt", "Ada Ferrers", 2022, 412, "Literary Fiction"),
    ("Northline", "Rue Callander", 2017, 296, "Mystery"),
    ("Northline: Undertow", "Rue Callander", 2019, 331, "Mystery"),
    ("A Grammar of Weather", "Perry Oduya", 2021, 268, "Essays"),
    ("The Glasshouse Year", "Ines Marchetti", 2023, 452, "Historical Fiction"),
]

MANGA = [
    ("Lantern Ward", 148, 16, "Finished", "manga", 2016, "Action,Drama"),
    ("Paper Kites", 92, 11, "Releasing", "manhwa", 2020, "Romance,Slice of Life"),
    ("Ninth Bell", 210, 24, "Releasing", "manga", 2014, "Fantasy,Adventure"),
]

EPISODE_WORDS = [
    "Overture", "The Quiet Part", "Salt and Ash", "Long Division", "A Better Silence",
    "Undertow", "Six of Cups", "Hollow Season", "The Second Bell", "Nightjar",
    "Anchor Point", "What the River Took", "Fair Weather", "Small Hours", "Ledger",
    "The Understudy", "Northbound", "Glasshouse", "Weathermaker", "Last Call",
]

PALETTES = [
    ((28, 24, 17), (240, 181, 68)), ((18, 26, 34), (94, 160, 214)),
    ((30, 18, 26), (203, 96, 130)), ((16, 30, 24), (86, 186, 132)),
    ((30, 22, 16), (222, 130, 74)), ((22, 18, 32), (150, 130, 232)),
    ((32, 18, 18), (214, 92, 92)), ((18, 28, 30), (74, 190, 190)),
]


def now_iso(offset_days=0, hour=None, minute=None):
    """Naive local timestamps — the DB convention since the 2026-07-18 tz migration."""
    moment = datetime.now() - timedelta(days=offset_days)
    if hour is not None:
        moment = moment.replace(hour=hour, minute=minute or 0, second=0, microsecond=0)
    return moment.replace(microsecond=0).isoformat()


# ---------------------------------------------------------------- placeholder art

def art_font(size):
    path = os.path.join(FONT_DIR, "Limelight-Regular.ttf")
    if os.path.exists(path):
        return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def make_poster(text, path, width=400, height=600, kind="poster"):
    """A gradient card with the title set in the app's display face. Enough to judge
    layout, obviously not real artwork."""
    seed = int(hashlib.sha256(text.encode()).hexdigest()[:8], 16)
    dark, accent = PALETTES[seed % len(PALETTES)]
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(1, height - 1)
        draw.line([(0, y), (width, y)],
                  fill=tuple(round(d + (a - d) * (t ** 2) * 0.55) for d, a in zip(dark, accent)))
    # a few deco rules, so the placeholder still reads as "Midnight Marquee"
    for i in range(4):
        y = height * (0.14 + i * 0.02)
        draw.line([(width * 0.1, y), (width * 0.9, y)], fill=accent, width=2)

    size = 34 if kind == "poster" else 30
    font = art_font(size)
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) > width * 0.8 and line:
            lines.append(line)
            line = word
        else:
            line = trial
    lines.append(line)
    y = height * 0.5 - len(lines) * size * 0.62
    for l in lines:
        draw.text((width / 2, y), l, font=font, fill=(245, 238, 224), anchor="ma")
        y += size * 1.24
    img.save(path, "PNG")


def art(art_dir, art_base, key, text, kind="poster"):
    os.makedirs(art_dir, exist_ok=True)
    slug = hashlib.sha256(f"{kind}:{key}".encode()).hexdigest()[:16]
    filename = f"{slug}.png"
    path = os.path.join(art_dir, filename)
    if not os.path.exists(path):
        if kind == "backdrop":
            make_poster(text, path, 780, 439, "backdrop")
        elif kind == "still":
            make_poster(text, path, 500, 281, "backdrop")
        else:
            make_poster(text, path)
    return f"{art_base.rstrip('/')}/{filename}"


# ---------------------------------------------------------------- seeding

def seed(db_path, art_dir, art_base, rng):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    users = [r["id"] for r in cur.execute("SELECT id FROM users ORDER BY id")]
    if not users:
        raise SystemExit("Register an account first (the first one becomes admin), "
                         "then run this against the same database.")
    me = users[0]
    cur.execute("UPDATE users SET features=? WHERE id=?",
                (json.dumps({"books": 1, "manga": 1}), me))

    # a second household member, so "Around the house" and shared lists have content
    other = next((u for u in users if u != me), None)
    if other is None:
        cur.execute("""INSERT INTO users(username,pass,is_admin,created_at,display_name)
            VALUES(?,?,0,?,?)""",
            ("housemate", "seed$0" * 1, now_iso(400), "Housemate"))
        other = cur.lastrowid
        cur.execute("INSERT INTO lists(user_id,name,is_default,created_at) VALUES(?,?,1,?)",
                    (other, "Want to Watch", now_iso(400)))

    show_ids = []
    for index, (title, year, status, genres, runtime, _, counts) in enumerate(SHOWS):
        show_id = 900_000 + index
        show_ids.append(show_id)
        details = {
            "overview": f"{title} follows a household through a season of small "
                        f"catastrophes and the meals that follow them.",
            "tagline": ["Everyone keeps something back.", "The tide always returns.",
                        "Nothing stays quiet for long.", "Some doors only open once."][index % 4],
            "vote": round(rng.uniform(6.8, 8.9), 1), "votes": rng.randint(400, 9000),
            "first_air": f"{year}-03-0{(index % 8) + 1}",
            "last_air": f"{year + len(counts) - 1}-11-14",
            "networks": [["Halcyon", "Ardent+", "Pelican", "Northgate"][index % 4]],
            "created_by": [["Ines Marchetti", "Rue Callander", "Perry Oduya"][index % 3]],
            "content_rating": ["TV-14", "TV-MA", "TV-PG"][index % 3],
            "origin": ["US", "GB", "CA", "JP"][index % 4],
            "language": "en",
            "n_seasons": len(counts), "n_episodes": sum(counts),
            "cast": [{"id": 5_000_000 + index * 10 + n,
                      "name": f"{rng.choice(['Ana', 'Tomas', 'Ruth', 'Idris', 'Mei', 'Bo'])} "
                              f"{rng.choice(['Vance', 'Okafor', 'Lindqvist', 'Barros', 'Nakamura'])}",
                      "character": rng.choice(["Del", "Marta", "The Keeper", "Yusuf", "Bea"]),
                      "img": None} for n in range(8)],
            "season_names": {"1": "Low Season"} if index % 3 == 0 else {},
            "season_posters": {},
        }
        cur.execute("""INSERT OR REPLACE INTO shows(id,title,poster,backdrop,year,status,genres,
            avg_runtime,last_refreshed,details,imdb_id,imdb_rating,imdb_votes,imdb_checked)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (show_id, title, art(art_dir, art_base, title, title),
             art(art_dir, art_base, title, title, "backdrop"), year, status, genres, runtime,
             now_iso(1), json.dumps(details), f"tt{9_000_000 + index}",
             round(rng.uniform(7.0, 8.8), 1), rng.randint(2_000, 400_000), now_iso(1)))

        air = date(year, 3, 1)
        for season, count in enumerate(counts, start=1):
            for number in range(1, count + 1):
                air += timedelta(days=7)
                cur.execute("""INSERT OR REPLACE INTO episodes(show_id,season,number,title,
                    air_date,runtime,overview,still,source,rating,imdb_rating,imdb_votes)
                    VALUES(?,?,?,?,?,?,?,?, 'tmdb',?,?,?)""",
                    (show_id, season, number,
                     f"{rng.choice(EPISODE_WORDS)}" + (f" ({number})" if number > 9 else ""),
                     air.isoformat(), runtime + rng.randint(-6, 8),
                     "A quiet episode with one loud minute in the middle.",
                     art(art_dir, art_base, f"{show_id}:{season}:{number}", title, "still"),
                     round(rng.uniform(6.4, 9.3), 1),
                     round(rng.uniform(6.6, 9.4), 1), rng.randint(120, 40_000)))

        # follow it, and watch a plausible amount of it
        cur.execute("""INSERT OR REPLACE INTO follows(user_id,show_id,added_at,archived,rating)
            VALUES(?,?,?,?,?)""",
            (me, show_id, now_iso(500 - index * 30), 1 if index == 7 else 0,
             rng.choice([None, 7, 8, 8, 9, 10])))

        total = sum(counts)
        # A mix that exercises every home-screen bucket: shows finished long ago, two
        # in progress and watched *this week* (so they land in Up Next), one behind
        # and lapsed (so it lands in "haven't watched in a while"), and one untouched.
        fraction, oldest, newest = [
            (1.00, 700, 300),   # finished, a while back
            (1.00, 620, 210),   # finished
            (0.55, 300, 2),     # in progress, watched two days ago  → Up Next
            (0.32, 520, 190),   # behind and lapsed                  → stale
            (0.90, 240, 1),     # in progress, watched yesterday     → Up Next
            (1.00, 320, 40),    # finished — this one's the milestone
            (0.12, 400, 150),   # barely started, lapsed             → stale
            (0.40, 900, 640),   # dropped (archived)
        ][index]
        watched = int(total * fraction)

        # Lay the watches out oldest → newest across the window, with the jitter that
        # makes a couple of days read as real binges.
        episodes = [(season, number)
                    for season, count in enumerate(counts, start=1)
                    for number in range(1, count + 1)][:watched]
        span = max(1, oldest - newest)
        for position, (season, number) in enumerate(episodes):
            share = position / max(1, len(episodes) - 1)
            day = int(oldest - span * share) + rng.choice([0, 0, 0, 1, -1, 2])
            cur.execute("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                VALUES(?,?,?,?,?)""",
                (me, show_id, season, number,
                 now_iso(max(0, day), hour=rng.choice([19, 20, 20, 21, 21, 22, 23]),
                         minute=rng.choice([0, 12, 27, 41]))))

        # the housemate is watching a couple of the same shows
        if index in (0, 2, 4):
            for number in range(1, min(6, counts[0]) + 1):
                cur.execute("""INSERT OR IGNORE INTO watches(user_id,show_id,season,number,watched_at)
                    VALUES(?,?,?,?,?)""",
                    (other, show_id, 1, number, now_iso(rng.randint(0, 9), hour=21)))
            cur.execute("""INSERT OR IGNORE INTO follows(user_id,show_id,added_at) VALUES(?,?,?)""",
                        (other, show_id, now_iso(60)))

    # an episode that airs in a few days, so Upcoming has something
    for index, show_id in enumerate(show_ids[:4]):
        cur.execute("""INSERT OR REPLACE INTO episodes(show_id,season,number,title,air_date,
            runtime,overview,still,source) VALUES(?,?,?,?,?,?,?,?, 'tmdb')""",
            (show_id, len(SHOWS[index][6]), 99, "Season finale",
             (date.today() + timedelta(days=3 + index * 5)).isoformat(),
             48, "Not aired yet.", None))

    movie_ids = []
    for index, (title, year, runtime, genres) in enumerate(MOVIES):
        movie_id = 800_000 + index
        movie_ids.append(movie_id)
        details = {
            "overview": f"{title}: a film about arriving somewhere slightly too late.",
            "tagline": "Some roads only run one way.",
            "vote": round(rng.uniform(6.0, 8.6), 1), "votes": rng.randint(300, 20_000),
            "backdrop": art(art_dir, art_base, title, title, "backdrop"),
            "runtime": runtime, "genres": genres.split(","),
            "content_rating": ["PG-13", "R", "PG"][index % 3],
            "imdb_id": f"tt{7_000_000 + index}",
            "directors": [["Ines Marchetti", "Perry Oduya", "Rue Callander"][index % 3]],
            "companies": [["Halcyon Pictures", "Pelican Films", "Northgate"][index % 3]],
            "countries": [["US", "GB", "FR", "JP"][index % 4]],
            "cast": [{"id": 6_000_000 + index * 5 + n, "name": f"Cast Member {n + 1}", "img": None}
                     for n in range(6)],
        }
        cur.execute("""INSERT OR REPLACE INTO movies(id,title,poster,year,release_date,runtime,
            genres,details,imdb_id,imdb_rating,imdb_votes) VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
            (movie_id, title, art(art_dir, art_base, title, title), year,
             f"{year}-{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}", runtime, genres,
             json.dumps(details), f"tt{7_000_000 + index}",
             round(rng.uniform(5.8, 8.5), 1), rng.randint(1_000, 300_000)))

        state = "watched" if index < 8 else "watchlist"
        cur.execute("""INSERT OR REPLACE INTO movie_states(user_id,movie_id,state,watched_at,rating)
            VALUES(?,?,?,?,?)""",
            (me, movie_id, state,
             now_iso(rng.randint(2, 800), hour=20) if state == "watched" else None,
             rng.choice([None, 6, 7, 8, 8, 9, 10]) if state == "watched" else None))

    # a film released next month, so Upcoming has a movie row too
    cur.execute("UPDATE movies SET release_date=? WHERE id=?",
                ((date.today() + timedelta(days=21)).isoformat(), movie_ids[-1]))
    cur.execute("UPDATE movie_states SET state='watchlist', watched_at=NULL WHERE user_id=? AND movie_id=?",
                (me, movie_ids[-1]))

    # ---- lists
    default_list = cur.execute("SELECT id FROM lists WHERE user_id=? AND is_default=1",
                               (me,)).fetchone()
    default_id = default_list["id"] if default_list else None
    if default_id is None:
        cur.execute("INSERT INTO lists(user_id,name,is_default,created_at) VALUES(?,?,1,?)",
                    (me, "Want to Watch", now_iso(300)))
        default_id = cur.lastrowid
    cur.execute("INSERT INTO lists(user_id,name,visibility,created_at) VALUES(?,?,?,?)",
                (me, "Sunday nights", "public", now_iso(120)))
    sunday = cur.lastrowid
    cur.execute("INSERT INTO lists(user_id,name,visibility,created_at) VALUES(?,?,?,?)",
                (other, "House picks", "collab", now_iso(90)))
    house = cur.lastrowid
    for list_id, pairs in ((default_id, [("movie", m) for m in movie_ids[8:]]),
                           (sunday, [("show", s) for s in show_ids[:3]]
                                    + [("movie", movie_ids[0])]),
                           (house, [("show", show_ids[4]), ("movie", movie_ids[2])])):
        for item_type, item_id in pairs:
            cur.execute("""INSERT OR IGNORE INTO list_items(list_id,item_type,item_id,added_at)
                VALUES(?,?,?,?)""", (list_id, item_type, item_id, now_iso(rng.randint(1, 90))))

    # ---- favorites
    for position, (item_type, item_id) in enumerate(
            [("show", show_ids[1]), ("show", show_ids[3]), ("movie", movie_ids[0]),
             ("movie", movie_ids[4]), ("show", show_ids[5])]):
        cur.execute("""INSERT OR IGNORE INTO favorites(user_id,item_type,item_id,position,created_at)
            VALUES(?,?,?,?,?)""", (me, item_type, item_id, position, now_iso(100)))

    # ---- reviews (with one reply, so threads render)
    cur.execute("""INSERT OR REPLACE INTO reviews(user_id,item_type,item_id,rating,body,
        created_at,updated_at) VALUES(?,?,?,?,?,?,?)""",
        (other, "show", show_ids[0], 9,
         "The third season finally lets the quiet scenes breathe. Best thing on all year.",
         now_iso(6), now_iso(6)))
    review_id = cur.lastrowid
    cur.execute("""INSERT INTO review_replies(review_id,user_id,body,created_at)
        VALUES(?,?,?,?)""", (review_id, me, "Agreed — episode six especially.", now_iso(5)))
    cur.execute("""INSERT OR REPLACE INTO reviews(user_id,item_type,item_id,rating,body,
        created_at,updated_at) VALUES(?,?,?,?,?,?,?)""",
        (me, "movie", movie_ids[0], 8, "Gorgeous, slow, worth it.", now_iso(20), now_iso(20)))

    # ---- reading
    book_ids = []
    for index, (title, author, year, pages, genre) in enumerate(BOOKS):
        cur.execute("""INSERT OR REPLACE INTO books(id,olid,title,author,cover,year,pages,
            details,genres,series,hardcover_id,rating,slug)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (700_000 + index, None, title, author,
             art(art_dir, art_base, title, title), year, pages,
             json.dumps({"desc": f"{title} — a novel about staying put."}), genre,
             "Northline" if title.startswith("Northline") else "",
             400_000 + index, round(rng.uniform(3.6, 4.6), 2), None))
        book_id = 700_000 + index
        book_ids.append(book_id)
        state = ["finished", "finished", "finished", "reading", "want", "reading"][index]
        progress = pages if state == "finished" else (
            rng.randint(40, pages - 40) if state == "reading" else 0)
        started = now_iso(rng.randint(40, 300)) if state != "want" else None
        finished = now_iso(rng.randint(3, 35)) if state == "finished" else None
        cur.execute("""INSERT OR REPLACE INTO book_states(user_id,book_id,state,progress,rating,
            started_at,finished_at,updated_at,mode) VALUES(?,?,?,?,?,?,?,?,?)""",
            (me, book_id, state, progress,
             rng.choice([None, 7, 8, 9]) if state == "finished" else None,
             started, finished, now_iso(rng.randint(0, 20)),
             "pages" if index % 3 else "pct"))
        if state != "want":
            position = 0
            for session in range(rng.randint(3, 9)):
                step = rng.randint(18, 60)
                start_day = rng.randint(2, 120)
                cur.execute("""INSERT INTO reading_sessions(user_id,kind,item_id,started_at,
                    ended_at,start_pos,end_pos) VALUES(?,'book',?,?,?,?,?)""",
                    (me, book_id, now_iso(start_day, hour=22),
                     now_iso(start_day, hour=22, minute=rng.choice([28, 35, 47, 55])),
                     position, min(pages, position + step)))
                position = min(pages, position + step)

    for index, (title, chapters, volumes, status, origin, year, genres) in enumerate(MANGA):
        manga_id = 600_000 + index
        cur.execute("""INSERT OR REPLACE INTO manga(id,title,cover,chapters,volumes,status,
            origin,year,details) VALUES(?,?,?,?,?,?,?,?,?)""",
            (manga_id, title, art(art_dir, art_base, title, title), chapters, volumes,
             status, origin, year,
             json.dumps({"genres": genres.split(","), "score": round(rng.uniform(7, 9), 1),
                         "desc": f"{title}: a long-running series about patience.",
                         "chlist": [[n, ""] for n in range(1, min(chapters, 60) + 1)]})))
        state = ["finished", "reading", "reading"][index]
        cur.execute("""INSERT OR REPLACE INTO manga_states(user_id,manga_id,state,progress,
            rating,started_at,finished_at,updated_at,mode) VALUES(?,?,?,?,?,?,?,?,'chapters')""",
            (me, manga_id, state, chapters if state == "finished" else rng.randint(10, chapters - 5),
             rng.choice([None, 8, 9]), now_iso(rng.randint(60, 400)),
             now_iso(rng.randint(2, 40)) if state == "finished" else None, now_iso(rng.randint(0, 10))))

    # ---- notifications
    for index, (kind, title, body, link) in enumerate([
        ("airing", f"{SHOWS[0][0]} — S4E7 airs tomorrow", "Small Hours", f"show/{show_ids[0]}"),
        ("comment", "Housemate reviewed something you watched", "", f"show/{show_ids[0]}"),
        ("plex", f"Marked {SHOWS[4][0]} S2E3 watched — from Plex", "", f"show/{show_ids[4]}"),
        ("new_season", f"{SHOWS[2][0]} — Season 4 premieres Aug 12", "", f"show/{show_ids[2]}"),
    ]):
        cur.execute("""INSERT INTO notifications(user_id,type,title,body,link,created_at,read_at)
            VALUES(?,?,?,?,?,?,?)""",
            (me, kind, title, body, link, now_iso(index), now_iso(index) if index > 1 else None))

    # ---- one *unseen* milestone, so the fanfare fires on the very first launch
    cur.execute("DELETE FROM milestones WHERE user_id=? AND show_id=?", (me, show_ids[5]))
    cur.execute("""INSERT OR IGNORE INTO milestones(user_id,kind,show_id,season,created_at,seen_at)
        VALUES(?, 'show', ?, 0, ?, NULL)""", (me, show_ids[5], now_iso(0)))
    cur.execute("""UPDATE settings SET value=? WHERE key='milestones_seeded'""", (now_iso(0),))

    con.commit()
    counts = {t: cur.execute(f"SELECT COUNT(*) c FROM {t}").fetchone()["c"]
              for t in ("shows", "episodes", "watches", "movies", "movie_states",
                        "books", "manga", "reading_sessions", "lists", "list_items",
                        "reviews", "notifications", "milestones")}
    con.close()
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, help="path to the LOCAL marquee.db")
    parser.add_argument("--art-dir", required=True, help="where to write placeholder art")
    parser.add_argument("--art-base", required=True, help="URL the art is served from")
    parser.add_argument("--seed", type=int, default=20260727)
    args = parser.parse_args()

    db_path = os.path.expanduser(args.db)
    if not os.path.exists(db_path):
        raise SystemExit(f"no database at {db_path} — start the server once first")
    counts = seed(db_path, os.path.expanduser(args.art_dir), args.art_base,
                  random.Random(args.seed))
    for table, count in counts.items():
        print(f"{table:20} {count:>6}")


if __name__ == "__main__":
    main()
