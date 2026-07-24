/* Marquee SPA v3 */
"use strict";
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const view = $("#view"), topbar = $("#topbar"), tabbar = $("#tabbar");
let ME = null;
const CACHE = {};
const BUILD = "20260723d";   // must match main.py BUILD; a mismatch means this code is stale

/* ---------- icons (drawn, never emoji) ---------- */
const I = {
  check: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="m4.5 12.8 5 5L19.5 6.6" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  plus: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>`,
  x: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/></svg>`,
  chev: `<svg class="chev" viewBox="0 0 24 24" fill="none"><path d="m9 5.5 7 6.5-7 6.5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  chevS: `<svg viewBox="0 0 24 24" fill="none"><path d="m9 5.5 7 6.5-7 6.5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  star: `<svg viewBox="0 0 24 24"><path d="M12 3.6l2.5 5.2 5.7.7-4.2 4 1.1 5.7L12 16.4l-5.1 2.8 1.1-5.7-4.2-4 5.7-.7z" fill="currentColor"/></svg>`,
  uptohere: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M19 12H7M11 7.5 6.5 12l4.5 4.5M4.5 5.5v13" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  ticket: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M4 8.5A2.5 2.5 0 0 1 6.5 6h11A2.5 2.5 0 0 1 20 8.5v1.2a2.3 2.3 0 0 0 0 4.6v1.2a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 15.5v-1.2a2.3 2.3 0 0 0 0-4.6z" stroke="currentColor" stroke-width="1.8"/></svg>`,
  share: `<svg class="ico" viewBox="0 0 24 24" fill="none"><circle cx="18" cy="5.5" r="2.6" stroke="currentColor" stroke-width="1.9"/><circle cx="6" cy="12" r="2.6" stroke="currentColor" stroke-width="1.9"/><circle cx="18" cy="18.5" r="2.6" stroke="currentColor" stroke-width="1.9"/><path d="m8.3 10.7 7.4-4M8.3 13.3l7.4 4" stroke="currentColor" stroke-width="1.9"/></svg>`,
  listadd: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M4 7h11M4 12h7M4 17h7" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M17 14v6M14 17h6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>`,
  bookmark: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M6 4.5h12v15l-6-4-6 4z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>`,
  bookmarkfill: `<svg class="ico" viewBox="0 0 24 24"><path d="M6 4.5h12v15l-6-4-6 4z" fill="currentColor"/></svg>`,
  edit: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M14.5 5.5l4 4M4 20l1-4L16 5a1.5 1.5 0 0 1 2 0l1 1a1.5 1.5 0 0 1 0 2L8 19z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  trash: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M5 7h14M10 7V5h4v2M6.5 7l.8 12h9.4l.8-12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  camera: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M4 8h3l1.5-2h7L17 8h3v11H4z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><circle cx="12" cy="13" r="3.2" stroke="currentColor" stroke-width="1.8"/></svg>`,
  image: `<svg class="ico" viewBox="0 0 24 24" fill="none"><rect x="3.5" y="5" width="17" height="14" rx="2.2" stroke="currentColor" stroke-width="1.8"/><circle cx="8.5" cy="10" r="1.7" fill="currentColor"/><path d="m5 17 4.5-4.5 3.5 3.5 3-2.5 3 3" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  chevR: `<svg viewBox="0 0 24 24" fill="none"><path d="m9 5.5 7 6.5-7 6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  eye: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="3.2" stroke="currentColor" stroke-width="1.8"/></svg>`,
  flag: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M5 21V4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M5 4.5h13l-2.4 4 2.4 4H5z" fill="currentColor" opacity=".55"/></svg>`,
  reply: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M10 8V4.5L3.5 11 10 17.5V14c5 0 8 1.6 10 5 0-6-3.5-11-10-11z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  bell: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M6 9a6 6 0 0 1 12 0c0 5 1.8 6.5 2.5 7.3.4.5.1 1.2-.6 1.2H4.1c-.7 0-1-.7-.6-1.2C4.2 15.5 6 14 6 9Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M9.5 20a2.5 2.5 0 0 0 5 0" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  lock: `<svg class="ico" viewBox="0 0 24 24" fill="none"><rect x="5" y="10.5" width="14" height="9.5" rx="2.4" stroke="currentColor" stroke-width="1.8"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="15" r="1.5" fill="currentColor"/></svg>`,
  globe: `<svg class="ico" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="8.6" stroke="currentColor" stroke-width="1.8"/><path d="M3.5 12h17M12 3.4c2.4 2.3 3.7 5.4 3.7 8.6S14.4 18.3 12 20.6c-2.4-2.3-3.7-5.4-3.7-8.6S9.6 5.7 12 3.4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  users: `<svg class="ico" viewBox="0 0 24 24" fill="none"><circle cx="9" cy="8" r="3.3" stroke="currentColor" stroke-width="1.8"/><path d="M3.5 19.5c0-3 2.5-5 5.5-5s5.5 2 5.5 5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M16 5.5a3.2 3.2 0 0 1 0 6.2M17.5 14.6c1.9.5 3.4 2.2 3.4 4.9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`,
  sort: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M7 5v14M7 19l-3.2-3.2M7 5l3.2 3.2M17 19V5M17 5l3.2 3.2M17 19l-3.2-3.2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
};
const isEnded = st => st === "Ended" || st === "Canceled";

/* source brand logos (inline SVG) */
const SRC_LOGO = {
  Trakt: `<svg class="srclogo trakt" viewBox="0 0 24 24" aria-label="Trakt"><circle cx="12" cy="12" r="11.2" fill="#ed1c24"/><path d="M5.2 16.8 13 9l-1.1-1.1-8 8zM8 6.2l6.6 6.6M18.8 7.4 12.4 13.8l6 6" fill="none" stroke="#fff" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round" opacity=".95"/></svg>`,
  TMDB: `<svg class="srclogo tmdb" viewBox="0 0 62 16" aria-label="TMDB"><defs><linearGradient id="tmdbg" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#90cea1"/><stop offset=".56" stop-color="#3cbec9"/><stop offset="1" stop-color="#01b4e4"/></linearGradient></defs><rect width="62" height="16" rx="3.2" fill="url(#tmdbg)"/><text x="31" y="11.6" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-weight="800" font-size="9.5" letter-spacing=".3" fill="#0d253f">TMDB</text></svg>`,
  MyAnimeList: `<svg class="srclogo mal" viewBox="0 0 48 16" aria-label="MyAnimeList"><rect width="48" height="16" rx="3" fill="#2e51a2"/><text x="24" y="11.8" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-weight="800" font-size="9.5" letter-spacing=".4" fill="#fff">MAL</text></svg>`,
};

/* ---------- utils ---------- */
async function api(path, opts = {}) {
  if (opts.body && !(opts.body instanceof FormData)) {
    opts.headers = { "Content-Type": "application/json", ...(opts.headers || {}) };
    opts.body = JSON.stringify(opts.body);
    opts.method = opts.method || "POST";
  }
  const r = await fetch("/api" + path, opts);
  if (r.status === 401) { ME = null; routes.login(); throw new Error("auth"); }
  if (!r.ok) {
    let msg = r.statusText;
    try { msg = (await r.json()).detail || msg; } catch {}
    toast(msg); throw new Error(msg);
  }
  return r.json();
}
function cached(path) {
  const stale = CACHE[path];
  const fresh = api(path).then(d => { CACHE[path] = d; return d; });
  return {
    stale,
    /* call cb(freshData, animate=false) only if the user is still there AND data changed */
    refresh(isCurrent, cb) {
      fresh.then(d => {
        if (!isCurrent()) return;
        if (stale && JSON.stringify(d) === JSON.stringify(stale)) return;   // no double flash
        cb(d);
      }).catch(() => {});
    },
  };
}
const esc = s => (s ?? "").toString().replace(/[&<>"']/g, c =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
function toast(msg) {
  const t = $("#toast"); t.textContent = msg; t.classList.add("show");
  clearTimeout(t._h); t._h = setTimeout(() => t.classList.remove("show"), 2400);
}
// rich "episode watched" toast with cover art → tap to rate & comment
let _etT = null;
function episodeDoneToast(showId, season, number, title, img) {
  let el = document.getElementById("eptoast");
  if (!el) { el = document.createElement("div"); el.id = "eptoast"; document.body.appendChild(el); }
  el.classList.remove("show");
  el.innerHTML = `<a class="et-card" href="#/show/${showId}/e/${season}/${number}">
      <span class="et-art"${img ? ` style="background-image:url('${img}')"` : ""}></span>
      <span class="et-body">
        <span class="et-badge">${I.check}<i>Watched</i></span>
        <span class="et-title">${esc(title || "Episode " + number)}</span>
        <span class="et-sub">${sxe(season, number)} · Rate &amp; see comments</span>
      </span>
      <span class="et-go">${I.star}</span></a>`;
  void el.offsetWidth;                 // force a reflow so the slide-in always animates
  el.classList.add("show");
  clearTimeout(_etT); _etT = setTimeout(() => el.classList.remove("show"), 5500);
  $(".et-card", el).onclick = () => { clearTimeout(_etT); el.classList.remove("show"); };
}
const fmtDate = d => d ? new Date(d.length <= 10 ? d + "T00:00" : d)
  .toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "";
// naive local-time stamp "YYYY-MM-DDTHH:MM:SS" — the DB convention (household tz, not UTC)
const nowStamp = () => { const d = new Date(), p = n => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`; };
const fmtHours = m => m >= 6000 ? `${(m / 1440).toFixed(1)} days` : `${Math.round(m / 60)} hrs`;
const sxe = (s, n) => `S${s} · E${n}`;
const POSTER = p => p || "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 2 3'%3E%3Crect width='2' height='3' fill='%231f1a13'/%3E%3C/svg%3E";
const skRows = n => Array.from({ length: n }, () => `<div class="sk row-sk"></div>`).join("");
// show a loading skeleton only if the fetch is actually slow — keeps back-navigation
// (which reads fast, local data) from flashing a skeleton over the previous screen
function deferSkeleton(html, ms = 160) {
  let done = false;
  const t = setTimeout(() => { if (!done) view.innerHTML = html; }, ms);
  return () => { done = true; clearTimeout(t); };
}
function sparks(el) {
  const r = el.getBoundingClientRect();
  for (let i = 0; i < 8; i++) {
    const s = document.createElement("i");
    s.className = "spark";
    s.style.left = r.left + r.width / 2 + "px";
    s.style.top = r.top + r.height / 2 + "px";
    const a = (Math.PI * 2 * i) / 8 + Math.random() * .5;
    s.style.setProperty("--dx", Math.cos(a) * (24 + Math.random() * 16) + "px");
    s.style.setProperty("--dy", Math.sin(a) * (24 + Math.random() * 16) + "px");
    document.body.appendChild(s);
    setTimeout(() => s.remove(), 520);
  }
}

/* ---------- shared: avatar, share, lists, reviews ---------- */
function avatarHTML(u, cls = "") {
  const name = u.display_name || u.username || "?";
  if (u.avatar) return `<span class="avatar ${cls}"><img src="${u.avatar}" alt=""></span>`;
  const initial = name.trim()[0].toUpperCase();
  const hue = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return `<span class="avatar ${cls}" style="--ah:${hue}">${initial}</span>`;
}

// image fallback chain — first available wins (e.g. episode still → season poster → show backdrop → poster)
const pickImg = (...cands) => cands.find(Boolean) || "";

function castStrip(people) {
  if (!people || !people.length) return "";
  return `<div class="cast-strip">${people.map(c => {
    const inner = `<div class="face">${c.img ? `<img loading="lazy" src="${c.img}" alt="">` : personGlyph()}</div>
      <div class="cn">${esc(c.name)}</div><div class="cc">${esc(c.character || "")}</div>`;
    return c.id ? `<a class="cast" href="#/person/${c.id}">${inner}</a>`
      : `<div class="cast">${inner}</div>`;
  }).join("")}</div>`;
}
const personGlyph = () => `<svg viewBox="0 0 24 24" class="pglyph"><circle cx="12" cy="8.5" r="4" fill="currentColor"/><path d="M4.5 20c0-4.1 3.4-6.5 7.5-6.5s7.5 2.4 7.5 6.5z" fill="currentColor"/></svg>`;

/* square-crop + compress an image file -> Blob (jpeg). Drag to pan, slider to zoom. */
function cropImage(file) {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const s = sheet(`<div class="sh-t">Adjust your photo</div>
        <div class="cropwrap" id="cw"><canvas id="cc"></canvas><div class="crop-ring"></div></div>
        <div class="crop-z">${I.plus}<input type="range" id="cz" min="1" max="4" step="0.01" value="1"></div>
        <button class="btn pri" data-a="save">Save photo</button>
        <button class="btn ghost" data-a="cancel">Cancel</button>`, { cls: "cropsheet" });
      const cv = $("#cc", s.el), ctx = cv.getContext("2d");
      const V = Math.min(300, s.el.clientWidth - 40); cv.width = V; cv.height = V;
      const base = Math.max(V / img.naturalWidth, V / img.naturalHeight);
      let zoom = 1, tx = 0, ty = 0;
      const clamp = () => {
        const w = img.naturalWidth * base * zoom, h = img.naturalHeight * base * zoom;
        const mx = Math.max(0, (w - V) / 2), my = Math.max(0, (h - V) / 2);
        tx = Math.max(-mx, Math.min(mx, tx)); ty = Math.max(-my, Math.min(my, ty));
      };
      const draw = () => {
        clamp();
        const eff = base * zoom, w = img.naturalWidth * eff, h = img.naturalHeight * eff;
        ctx.clearRect(0, 0, V, V);
        ctx.drawImage(img, V / 2 - w / 2 + tx, V / 2 - h / 2 + ty, w, h);
      };
      draw();
      let drag = false, px, py;
      const down = e => { drag = true; const p = e.touches ? e.touches[0] : e; px = p.clientX; py = p.clientY; };
      const move = e => {
        if (!drag) return; e.preventDefault();
        const p = e.touches ? e.touches[0] : e;
        const k = cv.width / (cv.clientWidth || cv.width);   // display px -> canvas px
        tx += (p.clientX - px) * k; ty += (p.clientY - py) * k; px = p.clientX; py = p.clientY; draw();
      };
      const up = () => drag = false;
      cv.addEventListener("mousedown", down); cv.addEventListener("touchstart", down, { passive: true });
      window.addEventListener("mousemove", move); cv.addEventListener("touchmove", move, { passive: false });
      window.addEventListener("mouseup", up); cv.addEventListener("touchend", up);
      $("#cz", s.el).oninput = e => { zoom = +e.target.value; draw(); };
      s.el.addEventListener("click", ev => {
        const a = ev.target.closest("[data-a]"); if (!a) return;
        window.removeEventListener("mousemove", move); window.removeEventListener("mouseup", up);
        if (a.dataset.a === "cancel") { URL.revokeObjectURL(url); s.close(); return resolve(null); }
        // export at 480px
        const OUT = 480, out = document.createElement("canvas"); out.width = out.height = OUT;
        const octx = out.getContext("2d");
        const eff = base * zoom * (OUT / V), w = img.naturalWidth * eff, h = img.naturalHeight * eff;
        octx.drawImage(img, OUT / 2 - w / 2 + tx * (OUT / V), OUT / 2 - h / 2 + ty * (OUT / V), w, h);
        out.toBlob(b => { URL.revokeObjectURL(url); s.close(); resolve(b); }, "image/jpeg", 0.85);
      });
    };
    img.src = url;
  });
}

async function share(title, path) {
  const url = location.origin + "/#/" + path;
  if (navigator.share) {
    try { await navigator.share({ title: "Marquee · " + title, url }); return; } catch { return; }
  }
  try { await navigator.clipboard.writeText(url); toast("Link copied"); }
  catch { toast(url); }
}

function sheet(innerHTML, { cls = "" } = {}) {
  const el = document.createElement("div");
  el.className = "sheetwrap";
  el.innerHTML = `<div class="sheet ${cls}">${innerHTML}</div>`;
  document.body.appendChild(el);
  requestAnimationFrame(() => el.classList.add("show"));
  const close = () => { el.classList.remove("show"); setTimeout(() => el.remove(), 240); };
  el.addEventListener("click", e => { if (e.target === el) close(); });
  return { el, close };
}

async function addToListMenu(itemType, itemId, title) {
  const { lists } = await api(`/item/${itemType}/${itemId}/lists`);
  const render = ls => ls.map(l => `
    <button class="list-opt ${l.has ? "on" : ""}" data-id="${l.id}">
      <span class="lo-ic">${l.collab ? I.users : l.has ? I.bookmarkfill : I.bookmark}</span>
      <span class="lo-name">${esc(l.name)}${l.collab ? `<i class="lo-shared">shared by ${esc(l.owner || "a member")}</i>` : ""}</span>
      ${l.has ? `<span class="lo-check">${I.check}</span>` : ""}</button>`).join("");
  const s = sheet(`<div class="sh-t">Add “${esc(title)}” to…</div>
    <div id="listopts">${render(lists)}</div>
    <div class="newlist"><input id="nl" placeholder="New list name…" maxlength="60">
      <button class="btn" id="nladd">${I.plus}</button></div>
    <button class="btn ghost" data-v="done">Done</button>`, { cls: "listsheet" });
  const refresh = async () => {
    const { lists } = await api(`/item/${itemType}/${itemId}/lists`);
    $("#listopts", s.el).innerHTML = render(lists);
  };
  s.el.addEventListener("click", async e => {
    if (e.target.closest('[data-v="done"]')) return s.close();
    const opt = e.target.closest(".list-opt");
    if (opt) {
      const has = opt.classList.contains("on");
      await api(`/list/${opt.dataset.id}/item`, { body: { item_type: itemType, item_id: itemId, remove: has } });
      if (!has) sparks(opt);
      delete CACHE["/lists"];
      await refresh();
    }
  });
  $("#nladd", s.el).onclick = async () => {
    const name = $("#nl", s.el).value.trim();
    if (!name) return;
    const l = await api("/lists", { body: { name } });
    await api(`/list/${l.id}/item`, { body: { item_type: itemType, item_id: itemId } });
    $("#nl", s.el).value = "";
    delete CACHE["/lists"];
    await refresh();
    toast(`Added to ${name}`);
  };
}

let SEER = null;   // {enabled, url}
const OV_ICON = `<svg class="ico ov" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="8.4" stroke="currentColor" stroke-width="1.9"/><path d="M12 8v5.4M9.4 11.2 12 13.8l2.6-2.6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const ST_LABEL = { none: "Not on server", pending: "Requested", processing: "Processing", partial: "Partial", available: "On Plex", downloading: "Downloading" };

async function mountRequest(slot, itemType, tmdbId) {
  if (!slot) return;
  if (SEER === null) { try { SEER = await api("/request/config"); } catch { SEER = { enabled: false }; } }
  if (!SEER.enabled) return;
  let st;
  try { st = await api(`/request/status/${itemType}/${tmdbId}`); } catch { return; }
  paintReq(slot, itemType, tmdbId, st);
  if (itemType === "show") paintSeasonStates(st.seasons || []);
}
// per-season availability/request badge inside each season accordion header
function paintSeasonStates(seasons) {
  const map = {}; seasons.forEach(s => (map[s.number] = s));
  $$("[data-reqs]").forEach(el => {
    const s = map[+el.dataset.reqs];
    if (!s || s.status === "none") { el.className = "seas-state"; el.innerHTML = ""; return; }
    if (s.status === "downloading") {
      const p = s.progress ?? 0;
      el.className = "seas-state dl";
      el.innerHTML = `<span class="ss-bar"><i style="width:${p}%"></i></span><span class="ss-t">${p}%${s.eta ? " · " + esc(s.eta) : ""}</span>`;
      el.title = `Downloading — ${p}%${s.eta ? " · " + s.eta + " left" : ""}`;
    } else if (s.status === "available") {
      el.className = "seas-state plex";
      el.innerHTML = `${I.check}<span class="ss-t">On Plex</span>`;
    } else {   // pending / processing / partial
      el.className = "seas-state req";
      el.innerHTML = `${OV_ICON}<span class="ss-t">${ST_LABEL[s.status]}</span>`;
    }
  });
}
function dlPill(dl) {
  if (!dl) return "";
  if (dl.progress != null) return `<span class="dl-pill"><span class="dl-bar"><i style="width:${dl.progress}%"></i></span>${dl.progress}%${dl.eta ? ` · ${esc(dl.eta)}` : ""}</span>`;
  return `<span class="dl-pill">Downloading…</span>`;
}
function paintReq(slot, itemType, tmdbId, st) {
  const status = st.status;
  if (itemType === "movie") {
    if (status === "available") slot.innerHTML = `<span class="btn onplex">${I.check} On Plex</span>`;
    else if (["pending", "processing", "partial"].includes(status))
      slot.innerHTML = `<span class="btn requested">${OV_ICON} Requested</span>${st.download ? dlPill(st.download) : ""}`;
    else {
      slot.innerHTML = `<button class="btn seerbtn">${OV_ICON} Request</button>`;
      slot.querySelector("button").onclick = async () => {
        const b = slot.querySelector("button"); b.disabled = true; b.innerHTML = "Requesting…";
        try {
          await api("/request", { body: { item_type: itemType, item_id: tmdbId } });
          toast("Requested on Overseerr");
          paintReq(slot, itemType, tmdbId, { status: "pending" });   // optimistic
          setTimeout(() => mountRequest(slot, itemType, tmdbId), 2500);   // real status soon after
        } catch { b.disabled = false; b.innerHTML = `${OV_ICON} Request`; }
      };
    }
    return;
  }
  // show: open a season picker
  const label = status === "available" ? `${I.check} On Plex`
    : status === "none" ? `${OV_ICON} Request` : `${OV_ICON} Manage request`;
  slot.innerHTML = `<button class="btn ${status === "available" ? "onplex" : "seerbtn"}">${label}</button>${st.download ? dlPill(st.download) : ""}`;
  slot.querySelector("button").onclick = () =>
    seasonRequestSheet(tmdbId, st, () => mountRequest(slot, itemType, tmdbId));
}
// one clear state badge per season, the way Overseerr surfaces it
function reqStateBadge(s) {
  if (s.status === "downloading") {
    const p = s.progress ?? 0;
    return `<span class="rq-state dl" title="Downloading${s.eta ? " · " + s.eta + " left" : ""}">
      <span class="rq-bar"><i style="width:${p}%"></i></span><span class="rq-pct">${p}%</span></span>`;
  }
  const M = { available: ["plex", `${I.check}On Plex`], partial: ["part", "Partial"],
              processing: ["req", "Processing"], pending: ["req", "Requested"] };
  const m = M[s.status];
  return m ? `<span class="rq-state ${m[0]}">${m[1]}</span>` : "";
}
function seasonRequestSheet(tmdbId, st, done) {
  const seasons = st.seasons || [];
  const canSelect = s => s.status === "none";
  const anyOpen = seasons.some(canSelect);
  const avail = seasons.filter(s => s.status === "available").length;
  const dling = seasons.filter(s => s.status === "downloading").length;
  const reqd = seasons.filter(s => ["pending", "processing", "partial"].includes(s.status)).length;
  // overall one-line summary
  let head, hcls;
  if (seasons.length && avail === seasons.length) { head = `All ${seasons.length} seasons on Plex`; hcls = "plex"; }
  else if (dling) { head = `Downloading ${dling} season${dling > 1 ? "s" : ""}`; hcls = "dl"; }
  else if (avail) { head = `${avail} of ${seasons.length} seasons on Plex`; hcls = "part"; }
  else if (reqd) { head = "Requested — waiting to download"; hcls = "req"; }
  else { head = "Not on Plex yet"; hcls = "none"; }
  const oBar = st.download && st.download.progress != null
    ? `<div class="rq-obar"><i style="width:${st.download.progress}%"></i></div>
       <span class="rq-osub">${st.download.progress}% overall${st.download.eta ? ` · ${esc(st.download.eta)} left` : ""}</span>` : "";
  const row = s => `<label class="rq-row ${s.status}${canSelect(s) ? " sel" : " locked"}" data-n="${s.number}">
      ${canSelect(s) ? `<input type="checkbox" data-n="${s.number}"><span class="rq-check">${I.check}</span>`
                     : `<span class="rq-dot ${s.status}"></span>`}
      <span class="rq-info"><b>Season ${s.number}</b><span class="rq-sub">${s.episodes} episode${s.episodes === 1 ? "" : "s"}</span></span>
      ${reqStateBadge(s)}</label>`;
  const sh = sheet(`<div class="sh-t">Request${anyOpen ? " seasons" : ""}</div>
    <div class="rq-overall ${hcls}"><span class="rq-ohead">${head}</span>${oBar}</div>
    <div class="rq-list">${seasons.map(row).join("") || '<div class="hint">No seasons found.</div>'}</div>
    ${anyOpen ? `<label class="rq-all"><input type="checkbox" id="seasall"><span class="rq-check">${I.check}</span> Select all not on Plex</label>
    <button class="btn pri" data-a="req" disabled>Request selected</button>` : ""}
    <button class="btn ghost" data-a="cancel">${anyOpen ? "Cancel" : "Close"}</button>`, { cls: "editor rqsheet" });
  const updateBtn = () => {
    const n = $$(".rq-row input:checked", sh.el).length, b = $('[data-a="req"]', sh.el);
    if (b) { b.disabled = !n; b.textContent = n ? `Request ${n} season${n > 1 ? "s" : ""}` : "Request selected"; }
  };
  if ($("#seasall", sh.el)) $("#seasall", sh.el).onchange = e => {
    $$(".rq-row.sel input", sh.el).forEach(c => { c.checked = e.target.checked; c.closest(".rq-row").classList.toggle("on", e.target.checked); });
    updateBtn();
  };
  sh.el.addEventListener("change", e => { const o = e.target.closest(".rq-row"); if (o) o.classList.toggle("on", e.target.checked); updateBtn(); });
  sh.el.addEventListener("click", async ev => {
    const a = ev.target.closest("[data-a]"); if (!a) return;
    if (a.dataset.a === "cancel") return sh.close();
    if (a.dataset.a === "req") {
      const sel = $$(".rq-row input:checked", sh.el).map(c => +c.dataset.n);
      if (!sel.length) return;
      a.disabled = true; a.textContent = "Requesting…";
      try {
        await api("/request", { body: { item_type: "show", item_id: tmdbId, seasons: sel } });
        sel.forEach(n => {
          const r = $(`.rq-row[data-n="${n}"]`, sh.el);
          if (r) r.outerHTML = `<div class="rq-row pending locked"><span class="rq-dot pending"></span>
            <span class="rq-info"><b>Season ${n}</b><span class="rq-sub">just requested</span></span>
            <span class="rq-state req">Requested</span></div>`;
        });
        toast(`Requested ${sel.length} season${sel.length > 1 ? "s" : ""}`);
        a.textContent = "Requested ✓";
        setTimeout(() => { sh.close(); done(); }, 900);
        setTimeout(done, 3500);   // re-confirm from Overseerr in case the first refetch was too early
      } catch { a.disabled = false; a.textContent = "Request selected"; }
    }
  });
}

const RSTARS = (n, cls = "") => `<span class="rstars ${cls}">${[1,2,3,4,5,6,7,8,9,10].map(i =>
  `<i class="${n >= i ? "on" : ""}" data-v="${i}">${I.star}</i>`).join("")}</span>`;

/* ---------- spoiler veil ----------
   One reusable "frosted curtain" used everywhere spoilers are hidden — unwatched
   episode overviews AND review/comment bodies. If `watched` is true the content is
   auto-uncovered (returned plain, never veiled — you've already seen the thing);
   otherwise it's blurred behind a tap/keyboard reveal. Revealing is handled once,
   globally, by the delegated listeners below. */
function veil(inner, { watched = false, cls = "", label = "Contains spoilers", sub = "Tap to reveal" } = {}) {
  if (watched) return inner;
  return `<div class="spoiler ${cls}" role="button" tabindex="0" aria-expanded="false"
      aria-label="${esc(label)} — press to reveal">
    <div class="spoiler-inner">${inner}</div>
    <div class="spoiler-veil" aria-hidden="true"><span class="spoiler-cue">${I.eye}<b>${esc(label)}</b><small>${esc(sub)}</small></span></div>
  </div>`;
}
function revealSpoiler(sp) {
  sp.classList.add("revealed");
  sp.setAttribute("aria-expanded", "true");
  sp.removeAttribute("role");
  sp.removeAttribute("tabindex");
  sp.removeAttribute("aria-label");
}
document.addEventListener("click", e => {
  const sp = e.target.closest?.(".spoiler:not(.revealed)");
  if (sp) { e.preventDefault(); revealSpoiler(sp); }
});
document.addEventListener("keydown", e => {
  if (e.key !== "Enter" && e.key !== " " && e.key !== "Spacebar") return;
  const sp = document.activeElement?.closest?.(".spoiler:not(.revealed)");
  if (sp) { e.preventDefault(); revealSpoiler(sp); }
});

async function reviewsBlock(itemType, itemId, { watched = true } = {}) {
  const wrap = document.createElement("div");
  wrap.className = "reviews";
  const load = async () => {
    const { reviews } = await api(`/reviews/${itemType}/${itemId}`);
    const mine = reviews.find(r => r.mine);
    wrap.innerHTML = `
      <div class="section"><h2>Reviews</h2><div class="rule"></div>
        <span class="cnt">${reviews.length}</span></div>
      <div class="myreview" id="myrev">
        ${mine ? renderReview(mine, true) : `
          <button class="btn addrev" id="writerev">${I.edit} Write a review</button>`}
      </div>
      <div class="rev-list">${reviews.filter(r => !r.mine).map(r => renderReview(r)).join("")
        || (mine ? "" : `<div class="empty" style="padding:18px">No reviews from the house yet — be the first.</div>`)}</div>
      <div id="ext-reviews"></div>`;
    if ($("#writerev", wrap)) $("#writerev", wrap).onclick = () => openEditor();
    $$(".rev-edit", wrap).forEach(b => b.onclick = () => openEditor(mine));
    $$(".rev-del", wrap).forEach(b => b.onclick = async () => {
      if (confirm("Delete your review?")) { await api(`/review/${b.dataset.id}`, { method: "DELETE" }); load(); }
    });
    $$(".reply-btn", wrap).forEach(b => b.onclick = () => openReplyEditor(+b.dataset.rid));
    $$(".reply-del", wrap).forEach(b => b.onclick = async () => {
      if (confirm("Delete this reply?")) { await api(`/reply/${b.dataset.id}`, { method: "DELETE" }); load(); }
    });
    loadExternal();
  };
  async function loadExternal() {
    let ext;
    try { ext = (await api(`/external_reviews/${itemType}/${itemId}`)).reviews; } catch { return; }
    const host = $("#ext-reviews", wrap);
    if (!host || !ext || !ext.length) return;
    host.innerHTML = `
      <div class="section ext-h"><h2>From the community</h2><div class="rule"></div>
        <span class="cnt">${ext.length}</span></div>
      ${ext.map(r => `<div class="review ext">
        <div class="rev-head"><span class="src-av">${srcGlyph(r.source)}</span>
          <div class="rev-who"><b>${esc(r.author || "someone")}</b>
            <span class="rev-date">${r.date ? fmtDate(r.date) : ""} · via ${esc(r.source)}</span></div>
          ${r.rating ? `<span class="rev-rating">${I.star} ${r.rating}</span>` : ""}
          ${r.likes ? `<span class="rev-likes">♥ ${r.likes}</span>` : ""}</div>
        ${veil(`<p class="rev-body">${esc(r.body)}</p>`, { watched, cls: "sp-rev", label: "Spoiler" })}
        <button class="read-more" type="button">Read more</button>
        <span class="src-tag">${esc(r.source)}</span></div>`).join("")}`;
    // only clamp reviews that actually overflow; make them expandable
    // (skip veiled ones — the curtain handles overflow; they show in full once revealed)
    $$(".review.ext", host).forEach(el => {
      if ($(".spoiler", el)) return;
      const body = $(".rev-body", el);
      if (body.scrollHeight > 230) {
        el.classList.add("clamped");
        $(".read-more", el).onclick = () => {
          const exp = el.classList.toggle("expanded");
          $(".read-more", el).textContent = exp ? "Show less" : "Read more";
        };
      }
    });
  }
  const srcGlyph = s => `<span class="src-logo">${SRC_LOGO[s] || SRC_LOGO.TMDB}</span>`;
  function renderReply(rp) {
    return `<div class="reply ${rp.mine ? "mine" : ""}" id="reply-${rp.id}">
      ${avatarHTML(rp.author, "xs")}
      <div class="reply-main">
        <div class="reply-top"><b>${esc(rp.author.display_name)}</b>
          <span class="rev-date">${fmtDate(rp.created_at.slice(0, 10))}</span>
          ${rp.mine ? `<button class="reply-del" data-id="${rp.id}" title="Delete">${I.trash}</button>` : ""}</div>
        <p>${esc(rp.body)}</p>
      </div></div>`;
  }
  function renderReview(r, isMine = false) {
    const replies = (r.replies || []).map(renderReply).join("");
    return `<div class="review ${isMine ? "mine" : ""}" id="rev-${r.id}">
      <div class="rev-head">${avatarHTML(r.author, "sm")}
        <div class="rev-who"><b>${esc(r.author.display_name)}</b>
          <span class="rev-date">${fmtDate((r.updated_at || r.created_at).slice(0, 10))}</span></div>
        ${r.rating ? `<span class="rev-rating">${I.star} ${r.rating}<small>/10</small></span>` : ""}
        ${isMine ? `<span class="rev-actions"><button class="rev-edit">${I.edit}</button>
          <button class="rev-del" data-id="${r.id}">${I.trash}</button></span>` : ""}
      </div>
      ${r.body ? veil(`<p class="rev-body">${esc(r.body)}</p>`,
        { watched: isMine || watched, cls: "sp-rev", label: "Spoiler" }) : ""}
      ${replies ? `<div class="replies">${replies}</div>` : ""}
      <button class="reply-btn" data-rid="${r.id}">${I.reply}<span>Reply</span></button>
    </div>`;
  }
  function openReplyEditor(reviewId) {
    const s = sheet(`<div class="sh-t">Reply</div>
      <textarea id="replybody" rows="4" placeholder="Add a reply…"></textarea>
      <button class="btn pri" data-v="save">Post reply</button>
      <button class="btn ghost" data-v="cancel">Cancel</button>`, { cls: "reveditor" });
    setTimeout(() => $("#replybody", s.el)?.focus(), 60);
    s.el.addEventListener("click", async e => {
      if (e.target.closest('[data-v="cancel"]')) return s.close();
      if (e.target.closest('[data-v="save"]')) {
        const body = $("#replybody", s.el).value.trim();
        if (!body) { toast("Write something first"); return; }
        await api(`/review/${reviewId}/reply`, { body: { body } });
        s.close(); load();
      }
    });
  }
  function openEditor(existing) {
    let rating = existing?.rating || 0;
    const s = sheet(`<div class="sh-t">${existing ? "Edit your review" : "Write a review"}</div>
      <div class="rate-row">Your rating <span class="hint">(optional)</span> ${RSTARS(rating, "big")}<span class="rate-num">${rating || "–"}</span></div>
      <textarea id="revbody" rows="5" placeholder="What did you think? (rating optional — words optional too)">${esc(existing?.body || "")}</textarea>
      <button class="btn pri" data-v="save">${existing ? "Save" : "Post review"}</button>
      <button class="btn ghost" data-v="cancel">Cancel</button>`, { cls: "reveditor" });
    $(".rstars", s.el).onclick = e => {
      const v = e.target.closest("[data-v]")?.dataset.v;
      if (!v) return;
      rating = +v === rating ? 0 : +v;
      $(".rstars", s.el).outerHTML = RSTARS(rating, "big");
      $(".rate-num", s.el).textContent = rating || "–";
    };
    s.el.addEventListener("click", async e => {
      if (e.target.closest('[data-v="cancel"]')) return s.close();
      if (e.target.closest('[data-v="save"]')) {
        const body = $("#revbody", s.el).value.trim();
        if (!body && !rating) { toast("Add a rating or some words"); return; }
        await api(`/reviews/${itemType}/${itemId}`, { body: { rating: rating || null, body } });
        s.close(); load();
      }
    });
  }
  load();
  return wrap;
}

/* ---------- router ---------- */
const routes = {};
function seg() { return location.hash.replace(/^#\/?/, "").split("/"); }
function parseHash() {
  const p = seg();
  if (!ME) return routes.login();
  $$(".sheetwrap").forEach(el => el.remove());   // navigating away dismisses any open sheet
  window.scrollTo(0, 0);
  if (p[0] === "show" && p[2] === "e") routes.episode(p[1], p[3], p[4]);
  else if (p[0] === "show") routes.show(p[1]);
  else if (p[0] === "movie") routes.movie(p[1]);
  else if (p[0] === "person") routes.person(p[1]);
  else if (p[0] === "list") routes.list(p[1]);
  else if (p[0] === "u" && p[2] === "recap") routes.recap(p[1], p[3]);
  else if (p[0] === "u") routes.profile(p[1]);
  else if (p[0] === "recap") routes.recap(null, p[1]);
  else (routes[p[0]] || routes.home)(p[1]);
  const active = { list: "lists", movie: "movies", show: "home", u: "profile",
    recap: "profile", stats: "profile" }[p[0]] || p[0] || "home";
  $$("#nav a, #tabbar a, .gear, .bell").forEach(a =>
    a.classList.toggle("on", a.dataset.r === active));
}
window.addEventListener("hashchange", parseHash);

/* ---------- login / register ---------- */
let SIGNUP_OPEN = null;
routes.login = async (mode = "login") => {
  topbar.hidden = true; tabbar.hidden = true;
  if (SIGNUP_OPEN === null) { try { SIGNUP_OPEN = (await api("/signup_open")).open; } catch { SIGNUP_OPEN = false; } }
  const isReg = mode === "register" && SIGNUP_OPEN;
  view.innerHTML = `<div class="login">
    <span class="wordmark">Marquee</span>
    <div class="sub">${isReg ? "create your account" : "now showing · your shows"}</div>
    <form id="loginform" autocomplete="on">
      <input id="u" name="username" placeholder="username" type="text" autocomplete="username"
        autocapitalize="none" autocorrect="off" spellcheck="false" enterkeyhint="next">
      <input id="p" name="password" placeholder="password" type="password"
        autocomplete="${isReg ? "new-password" : "current-password"}" enterkeyhint="go">
      <button class="btn pri" type="submit" id="go">${isReg ? "Create account" : "Take your seat"}</button>
    </form>
    <div class="err" id="err"></div>
    ${SIGNUP_OPEN ? `<div class="switch">${isReg
      ? `Already have an account? <a id="tolog">Sign in</a>`
      : `New here? <a id="toreg">Create an account</a>`}</div>` : ""}
  </div>`;
  const go = async () => {
    $("#err").textContent = "";
    const u = $("#u").value.trim(), p = $("#p").value;
    if (!u || !p) { $("#err").textContent = "Enter a username and password"; return; }
    try {
      ME = await api(isReg ? "/register" : "/login", { body: { username: u, password: p } });
      topbar.hidden = false; tabbar.hidden = false;
      Object.keys(CACHE).forEach(k => delete CACHE[k]);
      if (!seg()[0]) location.hash = "#/";   // keep a shared deep link through login
      boot();
    } catch (e) {
      $("#err").textContent = isReg ? (e.message || "Couldn't create account")
        : "Wrong username or password";
    }
  };
  $("#loginform").onsubmit = e => { e.preventDefault(); go(); };
  if ($("#toreg")) $("#toreg").onclick = () => routes.login("register");
  if ($("#tolog")) $("#tolog").onclick = () => routes.login("login");
  $("#u").focus();
};

/* ---------- home ---------- */
function bigCard(it, { punch = true, badge = "" } = {}) {
  const ep = it.next_ep;
  const pct = it.aired ? Math.round(100 * it.watched / it.aired) : 0;
  const epLine = ep ? `<b>${sxe(ep.season, ep.number)}</b>  ${esc(ep.title || "")}`
    : it.next_air ? `returns ${fmtDate(it.next_air)}`
    : (it.status === "Ended" || it.status === "Canceled") ? "series complete" : "waiting for new episodes";
  const hoursLeft = it.remaining && it.avg_runtime ? it.remaining * it.avg_runtime / 60 : 0;
  const subline = it.remaining
    ? `${it.remaining} left${hoursLeft >= 1 ? ` · ${hoursLeft < 10 ? hoursLeft.toFixed(1) : Math.round(hoursLeft)} hrs to go` : ""}`
    : "";
  return `<div class="bcard" data-id="${it.id}">
    <img class="poster" loading="lazy" src="${POSTER(it.poster)}" alt="">
    <div class="scrim"></div>
    <a class="fill" href="#/show/${it.id}" aria-label="${esc(it.title)}"></a>
    ${badge ? `<span class="badge">${badge}</span>` : ""}
    ${isEnded(it.status) ? `<span class="ended-tag">${I.flag} Ended</span>` : ""}
    ${punch && ep ? `<button class="punch" title="Mark ${sxe(ep.season, ep.number)} watched"
        data-s="${ep.season}" data-n="${ep.number}">${I.check}</button>` : ""}
    <div class="info">
      <div class="t">${esc(it.title)}</div>
      <div class="ep">${epLine}</div>
      ${subline ? `<div class="sub">${subline}</div>` : ""}
      <div class="pbar" title="${it.watched} of ${it.aired} watched">
        <div class="pbar-track"><div class="pbar-fill" style="--p:${pct}%"></div></div>
        <div class="pbar-num">${pct}%</div>
      </div>
    </div>
  </div>`;
}
function railHead(title, more) {
  return `<div class="rail-head"><h2>${title}</h2>${more
    ? `<a class="rail-more" href="${more}">All ${I.chevR}</a>` : ""}</div>`;
}
function watchedCard(it, { by = false, past = false } = {}) {
  const shortDate = d => new Date(d.slice(0, 10) + "T00:00")
    .toLocaleDateString(undefined, { month: "short", day: "numeric" });
  const href = past && it.season != null
    ? `#/show/${it.show_id}/e/${it.season}/${it.number}` : `#/show/${it.show_id}`;
  return `<a class="wcard${past ? " past" : ""}" href="${href}">
    <div class="wc-shot"><img loading="lazy" src="${POSTER(it.poster)}" alt="">
      ${by && it.by ? `<span class="wc-by">${avatarHTML(it.by, "tiny")}</span>` : ""}
      ${it.count > 1 ? `<span class="wc-count">${it.count}</span>` : ""}
      ${past ? `<span class="wc-date">${shortDate(it.watched_at)}</span>` : ""}</div>
    <div class="wc-t">${esc(it.title)}</div>
    <div class="wc-s">${it.season ? sxe(it.season, it.number) : ""}${it.count > 1 ? ` +${it.count - 1}` : ""}</div>
    ${by && it.by ? `<div class="wc-who">${esc(it.by.display_name)} · ${fmtDate(it.watched_at.slice(0,10))}</div>` : ""}
  </a>`;
}
/* history strip that lives off-screen to the LEFT of Up Next: oldest → newest in DOM
   order, each time-bucket capped on its right by a vertical divider naming it, so
   scrolling back (leftward) reads "Today ‹ Yesterday ‹ Last week ‹ Last month" */
function pastStrip(recent) {
  if (!recent || !recent.length) return "";
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const bucket = it => {
    const days = Math.round((today - new Date(it.watched_at.slice(0, 10) + "T00:00")) / 864e5);
    return days <= 0 ? "Today" : days === 1 ? "Yesterday" : days < 7 ? "This week"
      : days < 14 ? "Last week" : days < 31 ? "Last month" : "Earlier";
  };
  const groups = [];          // recent arrives newest→oldest
  for (const it of recent) {
    const b = bucket(it);
    if (!groups.length || groups[groups.length - 1].label !== b) groups.push({ label: b, items: [] });
    groups[groups.length - 1].items.push(it);
  }
  return groups.reverse().map(g =>
    g.items.reverse().map(x => watchedCard(x, { past: true })).join("") +
    `<div class="tdiv"><b>${g.label}</b></div>`).join("");
}
/* park the Up Next rail so the first queue card sits at the gutter and history is
   off-screen left. iOS Safari clobbers programmatic scrollLeft on scroll-snap
   containers back to 0 after layout, so: snap off while positioning, then re-assert
   over a few frames — backing off forever once the user touches the rail. */
function anchorUpRail() {
  const up = $(".hrail.up");
  if (!up) return;
  const place = () => {
    if (up._touched || !up.isConnected) return;
    const first = $(".bcard", up);
    const target = first
      ? first.getBoundingClientRect().left - up.getBoundingClientRect().left
        + up.scrollLeft - parseFloat(getComputedStyle(up).paddingLeft)
      : up.scrollWidth;
    if (Math.abs(up.scrollLeft - target) < 1) return;
    up.style.scrollSnapType = "none";
    up.scrollLeft = target;
    requestAnimationFrame(() => { up.style.scrollSnapType = ""; });
  };
  ["pointerdown", "touchstart", "wheel"].forEach(ev =>
    up.addEventListener(ev, () => { up._touched = true; }, { passive: true, once: true }));
  place();
  requestAnimationFrame(place);
  setTimeout(place, 150);
  setTimeout(place, 500);
}
/* redraw the history strip in place after a punch, shifting scrollLeft by the width
   delta so whatever is on screen doesn't move */
function refreshPastStrip() {
  const up = $(".hrail.up");
  const rec = (CACHE["/dashboard"] || {}).recent;
  if (!up || !rec) return;
  const before = up.scrollWidth;
  $$(".wcard.past,.tdiv", up).forEach(n => n.remove());
  up.insertAdjacentHTML("afterbegin", pastStrip(rec));
  up.style.scrollSnapType = "none";
  up.scrollLeft += up.scrollWidth - before;
  requestAnimationFrame(() => { up.style.scrollSnapType = ""; });
}
function calCard(e) {
  return `<a class="wcard" href="#/show/${e.show_id}/e/${e.season}/${e.number}">
    <div class="wc-shot"><img loading="lazy" src="${POSTER(e.poster)}" alt="">
      <span class="wc-date">${fmtDate(e.air_date).replace(/,.*/, "")}</span></div>
    <div class="wc-t">${esc(e.show_title)}</div>
    <div class="wc-s">${sxe(e.season, e.number)}</div></a>`;
}

function renderHome(d, animate = true) {
  const rv = animate ? "reveal" : "";
  const railOf = (title, arr, render, more) => arr && arr.length ? `
    ${railHead(title, more)}<div class="hrail ${rv}">${arr.map(render).join("")}</div>` : "";
  const greeting = (() => { const h = new Date().getHours();
    return h < 5 ? "Late show" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Tonight’s feature"; })();
  view.innerHTML = `
    <div class="home-hi"><h1>${greeting}, ${esc((ME.display_name || ME.username).split(" ")[0])}</h1></div>
    ${d.up_next.length || (d.recent || []).length ? `${railHead("Up Next")}
      <div class="hrail up ${rv}">${pastStrip(d.recent)}${d.up_next.map(x => bigCard(x)).join("")}</div>` : ""}
    ${d.up_next.length ? "" : `<div class="empty">Nothing in the queue — everything is crossed off.</div>`}
    ${railOf("Haven’t watched in a while", d.stale, x => bigCard(x))}
    ${railOf("On the calendar", d.calendar, calCard, "#/upcoming")}
    <div id="home-recs"></div>
    ${railOf("Around the house", d.social, x => watchedCard(x, { by: true }))}
    ${d.reviews && d.reviews.length ? `${railHead("Fresh reviews")}
      <div class="home-revs ${rv}">${d.reviews.slice(0, 4).map(r => `
        <a class="hrev" href="#/${r.type}/${r.id}">
          <img loading="lazy" src="${POSTER(r.poster)}" alt="">
          <div class="hrev-b"><div class="hrev-top">${avatarHTML(r.by, "tiny")}
            <b>${esc(r.by.display_name)}</b>${r.rating ? `<span class="hrev-rate">${I.star}${r.rating}</span>` : ""}</div>
            <div class="hrev-t">${esc(r.title)}</div>
            ${r.body ? `<div class="hrev-x">${esc(r.body)}</div>` : ""}</div></a>`).join("")}</div>` : ""}`;

  anchorUpRail();

  homePunchHandler();
  // lazy Recommended rail from discover
  const rc = CACHE["/discover"];
  const paintRecs = dd => {
    const sec = (dd.sections || []).find(s => /because you watched/i.test(s.title)) || (dd.sections || [])[0];
    if (sec && sec.items.length && $("#home-recs")) {
      $("#home-recs").innerHTML = `${railHead(sec.title, "#/search")}
        <div class="hrail">${sec.items.slice(0, 14).map(posterTile).join("")}</div>`;
      wireTiles($("#home-recs"), () => routes.home());
    }
  };
  if (rc) paintRecs(rc);
  else api("/discover").then(dd => { CACHE["/discover"] = dd; if (seg()[0] === "") paintRecs(dd); }).catch(() => {});
}

function homePunchHandler() {
  view.onclick = async e => {
    const b = e.target.closest(".punch");
    if (!b) return;
    e.preventDefault();
    const card = b.closest(".bcard");
    const showId = card.dataset.id, mS = +b.dataset.s, mN = +b.dataset.n;
    // grab the episode being marked (for the toast) before the card swaps to the next one
    const dash = CACHE["/dashboard"] || {};
    let item;
    for (const k of ["up_next", "stale", "not_started", "archived"]) {
      item = (dash[k] || []).find(x => String(x.id) === String(showId)); if (item) break;
    }
    b.classList.add("done"); b.disabled = true; sparks(b);
    episodeDoneToast(showId, mS, mN, item?.next_ep?.title || "",
      pickImg(item?.next_ep?.still, item?.backdrop, item?.poster, card.querySelector(".poster")?.getAttribute("src")));
    try {
      const r = await api(`/show/${card.dataset.id}/watch`,
        { body: { season: +b.dataset.s, number: +b.dataset.n } });
      const s = r.show;
      ["up_next", "stale"].forEach(k => {
        const arr = (CACHE["/dashboard"] || {})[k] || [];
        const i = arr.findIndex(x => x.id === s.id);
        if (i >= 0) { if (s.next_ep) arr[i] = s; else arr.splice(i, 1); }
      });
      // fold this watch into the cached recent feed so the history strip updates live
      const rec = (CACHE["/dashboard"] || {}).recent;
      if (rec) {
        const ts = nowStamp();
        let h = rec.find(x => String(x.show_id) === String(showId)
          && x.watched_at.slice(0, 10) === ts.slice(0, 10));
        if (h) { h.count++; h.season = mS; h.number = mN; h.watched_at = ts;
                 h.ep_title = item?.next_ep?.title || h.ep_title; }
        else if (item) h = { show_id: +showId, title: item.title, poster: item.poster,
          season: mS, number: mN, ep_title: item.next_ep?.title || "", watched_at: ts, count: 1 };
        if (h) {
          const i = rec.indexOf(h); if (i > -1) rec.splice(i, 1);
          rec.unshift(h);
          refreshPastStrip();
        }
      }
      if (s.next_ep) {
        const info = $(".info", card);
        const tmp = document.createElement("div");
        tmp.innerHTML = bigCard(s);
        info.classList.add("swapout");
        setTimeout(() => {
          info.innerHTML = tmp.querySelector(".info").innerHTML;
          const np = tmp.querySelector(".punch");
          b.dataset.s = np.dataset.s; b.dataset.n = np.dataset.n; b.title = np.title;
          b.disabled = false; b.classList.remove("done");
          info.classList.remove("swapout"); info.classList.add("swapin");
          const fill = $(".pbar-fill", info);
          if (fill) { const p = fill.style.getPropertyValue("--p"); fill.style.setProperty("--p", "0%");
            requestAnimationFrame(() => fill.style.setProperty("--p", p)); }
          setTimeout(() => info.classList.remove("swapin"), 320);
        }, 190);
      } else {
        toast(`${s.title} — all caught up`);
        card.classList.add("gone");
        setTimeout(() => card.remove(), 380);
      }
    } catch { b.disabled = false; b.classList.remove("done"); }
  };
}
routes.home = () => {
  const c = cached("/dashboard");
  if (c.stale) renderHome(c.stale);
  else view.innerHTML = `<div class="home-hi"><h1>Loading…</h1></div>
    <div class="hrail">${Array.from({ length: 5 }, () => `<div class="sk" style="width:168px;aspect-ratio:2/3;flex:none;border-radius:14px"></div>`).join("")}</div>`;
  c.refresh(() => seg()[0] === "", d => renderHome(d, !c.stale));
};

/* ---------- upcoming ---------- */
function renderUpcoming(d, animate = true) {
  const items = [
    ...d.episodes.map(e => ({ date: e.air_date, html: `
      <a class="up-row" href="#/show/${e.show_id}/e/${e.season}/${e.number}">
        <img loading="lazy" src="${POSTER(e.poster)}" alt="">
        <div class="mid"><div class="t">${esc(e.show_title)}</div>
        <div class="s">${sxe(e.season, e.number)} · ${esc(e.title || "TBA")}</div></div>
        <span class="tag">EPISODE</span><span class="go">${I.chevS}</span></a>` })),
    ...d.movies.map(m => ({ date: m.release_date, html: `
      <a class="up-row" href="#/movies">
        <img loading="lazy" src="${POSTER(m.poster)}" alt="">
        <div class="mid"><div class="t">${esc(m.title)}</div><div class="s">release day</div></div>
        <span class="tag">MOVIE</span><span class="go">${I.chevS}</span></a>` })),
  ].sort((a, b) => a.date.localeCompare(b.date));
  if (!items.length) { view.innerHTML = `<h1>Upcoming</h1><div class="empty">Nothing scheduled in the next 90 days.</div>`; return; }
  const days = {};
  items.forEach(i => (days[i.date] = days[i.date] || []).push(i.html));
  const today = nowStamp().slice(0, 10);
  const label = d0 => {
    const diff = Math.round((new Date(d0) - new Date(today)) / 864e5);
    if (diff <= 0) return "Tonight"; if (diff === 1) return "Tomorrow";
    if (diff < 7) return new Date(d0 + "T00:00").toLocaleDateString(undefined, { weekday: "long" });
    return fmtDate(d0);
  };
  view.innerHTML = `<h1>Upcoming</h1><div class="${animate ? "reveal" : ""}">` + Object.entries(days).map(([d0, rows]) =>
    `<div class="day"><h3>${label(d0)} <small>· ${fmtDate(d0)}</small></h3>${rows.join("")}</div>`).join("") + "</div>";
}
routes.upcoming = () => {
  const c = cached("/upcoming");
  if (c.stale) renderUpcoming(c.stale);
  else view.innerHTML = `<h1>Upcoming</h1>${skRows(7)}`;
  c.refresh(() => seg()[0] === "upcoming", d => renderUpcoming(d, !c.stale));
};

/* ---------- show page ---------- */
function seasonHTML(se, today, showId) {
  return `<div class="eps">${se.episodes.map(e => `
    <div class="ep-row ${e.watched ? "w" : ""} ${e.air_date && e.air_date > today ? "future" : ""}"
         data-s="${e.season}" data-n="${e.number}">
      <span class="n">${e.number}</span>
      <a class="et" href="#/show/${showId}/e/${e.season}/${e.number}"><span class="nm">${esc(e.title || "Episode " + e.number)}</span>
        <span class="ews">${e.watched && e.watched_at ? "Watched " + fmtDate(e.watched_at.slice(0, 10)) : ""}</span></a>
      <span class="date">${e.air_date ? fmtDate(e.air_date) : "TBA"}</span>
      <button class="tick" aria-label="toggle watched">${I.check}</button>
    </div>`).join("")}</div>`;
}

function episodeEditor(showId, defaultSeason) {
  return new Promise(resolve => {
    const el = document.createElement("div");
    el.className = "sheetwrap";
    el.innerHTML = `<div class="sheet editor">
      <div class="sh-t">Add missing episodes</div>
      <div class="hint" style="margin:-4px 0 8px">For fan edits or gaps in TMDB. If TMDB later adds these
        same numbers, its titles and artwork take over automatically — your watch marks stay.</div>
      <label>Season number</label><input id="ce-season" type="number" min="0" value="${defaultSeason}">
      <label>How many episodes <span class="hint">(numbering continues after the last existing one)</span></label>
      <input id="ce-count" type="number" min="1" max="200" placeholder="e.g. 8">
      <label>…or paste titles, one per line <span class="hint">(overrides the count)</span></label>
      <textarea id="ce-titles" rows="4" placeholder="Romance Dawn 01&#10;Romance Dawn 02"></textarea>
      <label>Air date for these <span class="hint">(optional — defaults to today so they count as aired)</span></label>
      <input id="ce-date" type="date">
      <button class="btn pri" data-v="save">Add episodes</button>
      <button class="btn ghost" data-v="cancel">Cancel</button></div>`;
    document.body.appendChild(el);
    requestAnimationFrame(() => el.classList.add("show"));
    const done = v => { el.classList.remove("show"); setTimeout(() => el.remove(), 220); resolve(v); };
    el.onclick = async e => {
      const b = e.target.closest("[data-v]");
      if (!b && e.target === el) return done(null);
      if (!b) return;
      if (b.dataset.v === "cancel") return done(null);
      const payload = {
        season: +$("#ce-season", el).value,
        count: +$("#ce-count", el).value || 0,
        titles: $("#ce-titles", el).value,
        air_date: $("#ce-date", el).value,
      };
      try {
        const r = await api(`/show/${showId}/episodes/custom`, { body: payload });
        toast(`Added ${r.added} episode${r.added === 1 ? "" : "s"} to season ${r.season}`);
        done(r);
      } catch { /* toast already shown */ }
    };
  });
}

/* bottom sheet asking how to mark when skipping ahead */
function ask(title, primary, secondary) {
  return new Promise(resolve => {
    const el = document.createElement("div");
    el.className = "sheetwrap";
    el.innerHTML = `<div class="sheet">
      <div class="sh-t">${title}</div>
      <button class="btn pri" data-v="primary">${primary}</button>
      <button class="btn" data-v="secondary">${secondary}</button>
      <button class="btn ghost" data-v="cancel">Cancel</button></div>`;
    document.body.appendChild(el);
    requestAnimationFrame(() => el.classList.add("show"));
    const done = v => { el.classList.remove("show"); setTimeout(() => el.remove(), 220); resolve(v); };
    el.onclick = e => {
      const b = e.target.closest("[data-v]");
      if (b) done(b.dataset.v);
      else if (e.target === el) done("cancel");
    };
  });
}

async function ratingsPanel(id) {
  const host = $("#show-ratings"); if (!host) return;
  let d;
  try { d = await api(`/show/${id}/ratings`); } catch { return; }
  const eps = d.episodes || [];
  if (eps.length < 4) { host.innerHTML = ""; return; }
  const rs = eps.map(e => e.rating);
  let lo = Math.max(0, Math.floor(Math.min(...rs)));
  let hi = Math.min(10, Math.ceil(Math.max(...rs)));
  if (hi - lo < 2) { lo = Math.max(0, lo - 1); hi = Math.min(10, hi + 1); }
  const avg = (rs.reduce((a, b) => a + b, 0) / rs.length).toFixed(1);
  const sa = d.season_avg || [];
  const bySeason = {};
  eps.forEach(e => (bySeason[e.season] = bySeason[e.season] || []).push(e));
  const seasons = Object.keys(bySeason).map(Number).sort((a, b) => a - b);
  const grade = v => `hsl(38 ${Math.round(45 + (v - lo) / (hi - lo) * 42)}% ${Math.round(40 + (v - lo) / (hi - lo) * 18)}%)`;
  let active = seasons[0];

  // rendered at the container's true pixel width (W) so axis text is never down-scaled
  function seasonSvg(sn, W) {
    const es = bySeason[sn].slice().sort((a, b) => a.number - b.number);
    const H = 138, pl = 26, pr = 12, pt = 12, pb = 22, pw = W - pl - pr, ph = H - pt - pb, N = es.length;
    const X = i => pl + (N === 1 ? pw / 2 : (i / (N - 1)) * pw);
    const Y = r => pt + (1 - (r - lo) / (hi - lo)) * ph;
    // faint gridline at each integer; y-labels only at the extremes to keep it clean
    let grid = "";
    for (let g = Math.ceil(lo); g <= Math.floor(hi); g++)
      grid += `<line class="grid-l" x1="${pl}" x2="${W - pr}" y1="${Y(g).toFixed(1)}" y2="${Y(g).toFixed(1)}"/>`;
    const labels = [lo, hi].map(g => `<text class="ax" x="${pl - 6}" y="${(Y(g) + 3.5).toFixed(1)}" text-anchor="end">${g}</text>`).join("");
    // dashed season-average reference line
    const savg = (sa.find(x => x.season === sn) || {}).avg;
    const avgLine = savg != null ? `<line class="ravg" x1="${pl}" x2="${W - pr}" y1="${Y(savg).toFixed(1)}" y2="${Y(savg).toFixed(1)}"/>` : "";
    // x-labels spaced for legibility (~min px gap), always show first & last
    let xl = "";
    const step = Math.max(1, Math.ceil((N - 1) / Math.max(1, Math.floor(pw / 40))));
    es.forEach((e, i) => { if (i % step === 0 || i === N - 1) xl += `<text class="ax" x="${X(i).toFixed(1)}" y="${H - 5}" text-anchor="middle">${e.number}</text>`; });
    const line = es.map((e, i) => `${i ? "L" : "M"}${X(i).toFixed(1)} ${Y(e.rating).toFixed(1)}`).join(" ");
    const area = `M${X(0).toFixed(1)} ${H - pb} ` + es.map((e, i) => `L${X(i).toFixed(1)} ${Y(e.rating).toFixed(1)}`).join(" ") + ` L${X(N - 1).toFixed(1)} ${H - pb} Z`;
    const r = N <= 24 ? 2.4 : 1.8;
    const dots = es.map((e, i) => `<circle class="pt" cx="${X(i).toFixed(1)}" cy="${Y(e.rating).toFixed(1)}" r="${r}"><title>E${e.number}${e.title ? " · " + e.title.replace(/"/g, "") : ""} · ${e.rating}</title></circle>`).join("");
    const peak = es.reduce((m, e, i) => e.rating > es[m].rating ? i : m, 0);
    return `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" class="ratspark">${grid}${avgLine}` +
      `<path class="rarea" d="${area}"/><path class="rline" d="${line}"/>${dots}` +
      `<circle class="rpeak" cx="${X(peak).toFixed(1)}" cy="${Y(es[peak].rating).toFixed(1)}" r="3"/>${labels}${xl}</svg>`;
  }

  const capHTML = sn => `Season ${sn}${bySeason[sn] ? " · " + bySeason[sn].length + " episodes" : ""}
    <span class="rat-savg">avg ${(sa.find(x => x.season === sn) || {}).avg ?? "–"}</span>`;

  host.innerHTML = `<div class="section"><h2>Ratings</h2><div class="rule"></div>
      <span class="cnt">${avg} avg${sa.length ? " · " + SRC_LOGO.TMDB : ""}</span></div>
    <div class="ratings">
      ${sa.length > 1 ? `<div class="savg-strip">${sa.map(s => `
        <button class="savg ${s.season === active ? "on" : ""}" data-s="${s.season}" title="Season ${s.season} average: ${s.avg}">
          <span class="savg-s">S${s.season}</span><span class="savg-v">${s.avg}</span>
          <span class="savg-u"><i style="width:${Math.round((s.avg - lo) / (hi - lo) * 100)}%;background:${grade(s.avg)}"></i></span>
        </button>`).join("")}</div>` : ""}
      <div class="rat-cap" id="ratcap">${capHTML(active)}</div>
      <div class="seasvg" id="seasvg"></div>
    </div>`;
  const capEl = $("#ratcap", host), svgEl = $("#seasvg", host);
  const draw = () => { svgEl.innerHTML = seasonSvg(active, Math.max(260, Math.round(svgEl.clientWidth) || 600)); };
  draw();
  // keep the chart crisp across viewport resizes; detach the listener once the panel is gone
  const onResize = () => { if (document.body.contains(svgEl)) draw(); else removeEventListener("resize", onResize); };
  addEventListener("resize", onResize);
  $$(".savg", host).forEach(b => b.onclick = () => {
    const sn = +b.dataset.s;
    if (sn === active) return;
    active = sn;
    $$(".savg", host).forEach(x => x.classList.toggle("on", +x.dataset.s === sn));
    capEl.innerHTML = capHTML(sn);
    draw();                                    // swap only the graph — instant, no flash
  });
}


/* ---------- where to watch: streaming availability (TMDB / JustWatch) ---------- */
// Lazy, non-blocking: fetched after the main detail render. Plex-first — if the title is
// already on the household server we lead with that, then surface streaming/rent/buy.
async function watchNow(itemType, id, hostId) {
  const host = document.getElementById(hostId); if (!host) return;
  let d;
  try { d = await api(`/watch_providers/${itemType}/${id}`); } catch { return; }
  // Does Plex already have it? Reuse the Overseerr status (only when a server is configured).
  let onPlex = false;
  if (SEER === null) { try { SEER = await api("/request/config"); } catch { SEER = { enabled: false }; } }
  if (SEER && SEER.enabled) {
    try { const st = await api(`/request/status/${itemType}/${id}`); onPlex = st.status === "available"; } catch {}
  }
  const groups = [
    ["flatrate", onPlex ? "Also streaming" : "Stream"],
    ["rent", "Rent"],
    ["buy", "Buy"],
  ].filter(([k]) => (d[k] || []).length);
  if (!onPlex && !groups.length) { host.innerHTML = ""; return; }   // nothing worth showing
  const link = d.link || "";
  const prov = p => {
    const inner = `<span class="wn-logo">${p.logo
        ? `<img loading="lazy" src="${p.logo}" alt="${esc(p.name || "")}">`
        : `<span class="wn-ph">${esc((p.name || "?").trim()[0] || "?")}</span>`}</span>
      <span class="wn-name">${esc(p.name || "")}</span>`;
    return link
      ? `<a class="wn-prov" href="${esc(link)}" target="_blank" rel="noopener" title="${esc(p.name || "")} — open on JustWatch">${inner}</a>`
      : `<span class="wn-prov">${inner}</span>`;
  };
  const groupHTML = ([k, label]) => `<div class="wn-group">
      <div class="wn-glabel"><span class="wn-dot ${k}"></span>${esc(label)}</div>
      <div class="wn-logos">${d[k].map(prov).join("")}</div></div>`;
  const plexLead = onPlex ? `<div class="wn-plex">${PLEX_LOGO}
      <div class="wn-plex-t"><b>On your Plex</b>
        <span>Ready to play now${groups.length ? " — also streaming below" : ""}</span></div>
      ${I.check}</div>` : "";
  const bodyGroups = groups.map(groupHTML).join("")
    || `<div class="hint wn-none">No streaming, rent, or buy options listed for the US right now.</div>`;
  host.innerHTML = `<div class="section"><h2>Where to watch</h2><div class="rule"></div>
      <span class="cnt">${link
        ? `<a class="wn-jw" href="${esc(link)}" target="_blank" rel="noopener">US · JustWatch ${I.chevR}</a>`
        : "US"}</span></div>
    <div class="watchnow">${plexLead}${bodyGroups}</div>`;
}


routes.show = async id => {
  const stop = deferSkeleton(`<div class="backdrop"><div class="hero">
      <div class="sk" style="width:136px;aspect-ratio:2/3"></div>
      <div style="flex:1"><div class="sk line-sk" style="max-width:260px;height:26px"></div>
      <div class="sk line-sk" style="max-width:180px;margin-top:12px"></div></div></div></div>${skRows(4)}`);
  const s = await api(`/show/${id}`);
  stop();
  s.seasons = s.seasons.filter(se => se.episodes.length);   // hide empty (unproduced) seasons
  const today = nowStamp().slice(0, 10);
  const watchable = s.seasons.flatMap(se => se.episodes)
    .filter(e => e.season > 0 && e.air_date && e.air_date <= today);
  let watched = watchable.filter(e => e.watched).length;
  const nextEp = watchable.find(e => !e.watched);
  const openSeason = nextEp ? nextEp.season : (s.seasons.at(-1)?.season ?? 1);
  const stars = r => [1, 2, 3, 4, 5].map(i =>
    `<span data-v="${i * 2}" class="${(r || 0) >= i * 2 ? "b" : ""}">${I.star}</span>`).join("");

  const info = s.info || {};
  const yearsSpan = info.first_air ? info.first_air.slice(0, 4) +
    (info.last_air && info.last_air.slice(0, 4) !== info.first_air.slice(0, 4)
      ? "–" + (s.status === "Returning Series" ? "" : info.last_air.slice(0, 4)) : "") : s.year || "";
  const ended = isEnded(s.status);
  const endYear = info.last_air ? info.last_air.slice(0, 4) : "";
  // progress-bar colour: red if the user stopped watching, purple if a finished series is 100% done
  const pbarCls = s.archived ? "stopped" : (watchable.length > 0 && watched >= watchable.length && ended) ? "done" : "";
  const chips = [
    ended ? `<span class="chip ended">${I.flag} Ended${endYear ? " · " + endYear : ""}</span>` : "",
    info.content_rating && `<span class="chip">${esc(info.content_rating)}</span>`,
    info.vote ? `<span class="chip star">${I.star} ${info.vote}</span>` : "",
    info.networks?.length && `<span class="chip">${esc(info.networks.join(" · "))}</span>`,
    info.n_episodes && `<span class="chip">${info.n_seasons} season${info.n_seasons > 1 ? "s" : ""} · ${info.n_episodes} eps</span>`,
    info.origin && `<span class="chip">${esc(info.origin)}</span>`,
  ].filter(Boolean).join("");
  view.innerHTML = `
    <div class="backdrop">${s.backdrop ? `<div class="bg" style="background-image:url('${s.backdrop}')"></div>` : ""}
      <div class="hero">
        <img class="poster" src="${POSTER(s.poster)}" alt="">
        <div class="hbody"><h1>${esc(s.title)}</h1>
          ${info.tagline ? `<div class="tagline">${esc(info.tagline)}</div>` : ""}
          <div class="chips">${chips}</div>
          <div class="facts">
            ${esc(s.status || "")}${yearsSpan ? " · " + yearsSpan : ""}
            ${esc(s.genres ? " · " + s.genres : "")}${info.created_by?.length ? ` · by ${esc(info.created_by.join(", "))}` : ""}<br>
            <span class="stars" id="stars">${stars(s.rating)}</span>
          </div>
        </div>
        <div class="hextra">
          <div class="showprog">
            <div class="pbar-track big"><div class="pbar-fill ${pbarCls}" style="--p:${watchable.length ? Math.round(100 * watched / watchable.length) : 0}%"></div></div>
            <div class="showprog-lbl"><b id="progline">${watched}</b> / ${watchable.length} watched
              ${watchable.length - watched > 0 ? `<span class="dim">· ${watchable.length - watched} to go</span>` : `<span class="done-tag">${I.check} complete</span>`}</div>
          </div>
          <div class="actions">
            <div class="act-main">
              ${s.followed ? `<button class="btn pri" id="arch">${s.archived ? "Resume" : "Watching"}</button>`
                : `<button class="btn pri" id="follow">${I.plus} Follow</button>`}
              <span id="reqslot"></span>
            </div>
            <div class="act-row">
              <button class="chip-btn fav-chip" id="favchip" aria-pressed="false">${I.star}<span id="favchiplbl">Favorite</span></button>
              <button class="chip-btn" id="addlist">${I.listadd}<span>List</span></button>
              <button class="chip-btn" id="shareshow">${I.share}<span>Share</span></button>
              ${ME.is_admin ? `<button class="chip-btn" id="epedit">${I.edit}<span>Episodes</span></button>` : ""}
              ${info.imdb_id ? `<a class="chip-btn imdb" href="https://www.imdb.com/title/${info.imdb_id}/" target="_blank" rel="noopener"><b>IMDb</b></a>` : ""}
              ${s.followed ? `<button class="chip-btn danger" id="unfollow">${I.trash}<span>Remove</span></button>` : ""}
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="dbody">
    ${info.overview ? `<p class="overview clamp" id="ov">${esc(info.overview)}</p>` : ""}
    <div id="upnext-host"></div>
    <div id="watch-now"></div>
    ${info.cast?.length ? `<div class="section"><h2>Cast</h2><div class="rule"></div></div>${castStrip(info.cast)}` : ""}
    <div id="show-ratings"></div>
    <div class="reveal">
    ${s.seasons.map(se => {
      const eps = se.episodes, w = eps.filter(e => e.watched).length;
      const open = se.season === openSeason;
      const sname = (info.season_names || {})[se.season]
        || (se.season === 0 ? "Specials" : "Season " + se.season);
      return `<div class="season ${open ? "open" : ""} ${w === eps.length && eps.length ? "done" : ""}" data-season="${se.season}" data-total="${eps.length}">
      <header>
        <div class="s-top">${I.chev}
          <h3>${esc(sname)}</h3>
          <span class="prog"><b class="wc">${w}</b>/${eps.length}</span>
          <button class="all" data-un="${w === eps.length ? 1 : ""}">${w === eps.length ? "unmark all" : "mark all"}</button>
        </div>
        <div class="s-bot"><span class="mini"><i style="--p:${eps.length ? Math.round(100 * w / eps.length) : 0}%"></i></span>
          <span class="seas-state" data-reqs="${se.season}"></span></div>
      </header>
      ${open ? seasonHTML(se, today, id) : ""}
      </div>`;
    }).join("")}</div>
    <div id="show-reviews"></div>
    </div>`;

  // "continue watching" — a swipeable carousel of episodes around your current spot
  function unBadge(e, isNext) { return e.watched ? "Watched" : isNext ? "Continue watching" : "Up next"; }
  function upNextCard(e, isNext) {
    const img = pickImg(e.still, s.info?.season_posters?.[e.season], s.backdrop, s.poster);
    return `<div class="upnext un-slide${e.watched ? " done" : ""}" data-s="${e.season}" data-n="${e.number}">
      <div class="un-still" style="${img ? `background-image:url('${img}')` : ""}">
        <div class="un-holes"></div><div class="un-holes r"></div><div class="un-scrim"></div>
        <span class="un-badge"><i></i>${unBadge(e, isNext)}</span>
      </div>
      <div class="un-body">
        <div class="un-text">
          <div class="un-sxe">${sxe(e.season, e.number)}${e.air_date ? ` · ${fmtDate(e.air_date)}` : ""}</div>
          <a class="un-title" href="#/show/${id}/e/${e.season}/${e.number}">${esc(e.title || "Episode " + e.number)}</a>
        </div>
        <div class="un-actions">
          <button class="btn ${e.watched ? "" : "pri"} un-toggle">${I.check} ${e.watched ? "Watched" : "Mark watched"}</button>
          <a class="btn" href="#/show/${id}/e/${e.season}/${e.number}">Details</a>
        </div>
      </div></div>`;
  }
  let unWindow = null;
  function nextIndex() { return watchable.findIndex(x => !x.watched); }
  function renderUpNext() {
    const host = $("#upnext-host"); if (!host) return;
    const nx = nextIndex();
    if (watched === 0 || nx < 0) { host.innerHTML = ""; unWindow = null; return; }   // not in progress
    const lo = Math.max(0, nx - 12), hi = Math.min(watchable.length, nx + 13);
    unWindow = { lo, hi };
    host.innerHTML = `<div class="un-carousel">${watchable.slice(lo, hi)
      .map((e, i) => upNextCard(e, lo + i === nx)).join("")}</div>`;
    $$(".un-slide", host).forEach(slide => $(".un-toggle", slide).onclick = () => {
      const season = +slide.dataset.s, number = +slide.dataset.n, e = epIndex.get(`${season}:${number}`);
      const on = !(e && e.watched);
      if (on) { sparks($(".un-toggle", slide));
        episodeDoneToast(id, season, number, e?.title, pickImg(e?.still, s.info?.season_posters?.[season], s.backdrop, s.poster)); }
      toggleEpisode(season, number, on);
      syncUpNext();
    });
    scrollUpNextToNext(host, false);
  }
  function scrollUpNextToNext(host, smooth) {
    const track = $(".un-carousel", host), ne = watchable[nextIndex()]; if (!track || !ne) return;
    const slide = $(`.un-slide[data-s="${ne.season}"][data-n="${ne.number}"]`, track);
    if (slide) track.scrollTo({ left: slide.offsetLeft - track.offsetLeft, behavior: smooth ? "smooth" : "auto" });
  }
  // keep the carousel in sync when episodes are (un)marked from anywhere (list, sheet, itself)
  function syncUpNext() {
    const host = $("#upnext-host"); if (!host) return;
    const nx = nextIndex();
    if (watched === 0 || nx < 0) { host.innerHTML = ""; unWindow = null; return; }
    if (!unWindow || nx < unWindow.lo + 2 || nx > unWindow.hi - 3 || !$(".un-carousel", host)) { renderUpNext(); return; }
    $$(".un-slide", host).forEach(slide => {
      const e = epIndex.get(`${+slide.dataset.s}:${+slide.dataset.n}`); if (!e) return;
      slide.classList.toggle("done", !!e.watched);
      $(".un-badge", slide).innerHTML = `<i></i>${unBadge(e, watchable[nx] === e)}`;
      const t = $(".un-toggle", slide);
      t.className = `btn ${e.watched ? "" : "pri"} un-toggle`;
      t.innerHTML = `${I.check} ${e.watched ? "Watched" : "Mark watched"}`;
    });
    scrollUpNextToNext(host, true);
  }
  function toggleEpisode(season, number, on) {
    const row = view.querySelector(`.ep-row[data-s="${season}"][data-n="${number}"]`);
    if (row) { const d = setRow(row, on); patchTotals(d); patchSeasonHeader(row.closest(".season")); }
    else {
      const e = epIndex.get(`${season}:${number}`);
      if (e && e.watched !== on) { e.watched = on; if (on && !e.watched_at) e.watched_at = nowStamp(); patchTotals(on ? 1 : -1); }
      const box = view.querySelector(`.season[data-season="${season}"]`); if (box) patchSeasonHeader(box);
    }
    delete CACHE["/dashboard"];
    api(`/show/${id}/watch`, { body: { season, number, unwatch: !on } }).catch(() => routes.show(id));
  }
  ratingsPanel(id);
  watchNow("show", +id, "watch-now");
  // show-level reviews stay veiled until you're caught up on every aired episode
  reviewsBlock("show", +id, { watched: watchable.length > 0 && watched === watchable.length })
    .then(el => { const c = $("#show-reviews"); if (c) c.appendChild(el); });
  mountRequest($("#reqslot"), "show", +id);
  if ($("#shareshow")) $("#shareshow").onclick = () => share(s.title, `show/${id}`);
  wireFavChip("show", +id);
  if ($("#addlist")) $("#addlist").onclick = () => addToListMenu("show", +id, s.title);

  const seasonsByNum = Object.fromEntries(s.seasons.map(se => [se.season, se]));
  const epIndex = new Map();
  s.seasons.forEach(se => se.episodes.forEach(e => epIndex.set(`${e.season}:${e.number}`, e)));
  const earlierUnwatched = (season, number) => [...epIndex.values()].filter(e =>
    e.season > 0 && !e.watched && e.air_date && e.air_date <= today &&
    (e.season < season || (e.season === season && e.number < number))).length;
  function patchSeasonHeader(box) {
    const rows = $$(".ep-row", box);
    if (!rows.length) return;
    const w = rows.filter(r => r.classList.contains("w")).length;
    const total = +box.dataset.total;
    $(".wc", box).textContent = w;
    $(".mini i", box).style.setProperty("--p", (total ? Math.round(100 * w / total) : 0) + "%");
    box.classList.toggle("done", w === total && total > 0);
    const all = $(".all", box);
    all.dataset.un = w === total ? 1 : "";
    all.textContent = w === total ? "unmark all" : "mark all";
  }
  function patchTotals(delta) {
    watched = Math.max(0, watched + delta);
    const pl = $("#progline");
    if (pl) {
      pl.textContent = watched;
      const lbl = pl.parentElement;
      const left = watchable.length - watched;
      const tail = lbl.querySelector(".dim, .done-tag");
      if (tail) tail.outerHTML = left > 0
        ? `<span class="dim">· ${left} to go</span>`
        : `<span class="done-tag">${I.check} complete</span>`;
      const fill = $(".showprog .pbar-fill");
      if (fill) fill.style.setProperty("--p", (watchable.length ? Math.round(100 * watched / watchable.length) : 0) + "%");
    }
  }
  const setRow = (row, on) => {
    const e = epIndex.get(`${+row.dataset.s}:${+row.dataset.n}`);
    if (e) { e.watched = on; if (on && !e.watched_at) e.watched_at = nowStamp(); }
    const ews = $(".ews", row);
    if (ews) ews.textContent = on && e?.watched_at ? "Watched " + fmtDate(e.watched_at.slice(0, 10)) : "";
    if (row.classList.contains("w") === on) return 0;
    row.classList.toggle("w", on);
    return on ? 1 : -1;
  };
  function openEpSheet(row) {
    const season = +row.dataset.s, number = +row.dataset.n;
    const e = epIndex.get(`${season}:${number}`);
    const watched = row.classList.contains("w");
    const s = sheet(`<div class="sh-t">${sxe(season, number)} · ${esc(e?.title || "Episode " + number)}</div>
      <button class="btn" data-a="toggle">${watched ? "Mark unwatched" : "Mark watched"}</button>
      ${watched ? `<label>Watched on</label>
        <input type="date" id="wd" value="${(e?.watched_at || "").slice(0, 10)}" max="${nowStamp().slice(0,10)}">
        <button class="btn pri" data-a="savedate">Save date</button>` : ""}
      <a class="btn" href="#/show/${id}/e/${season}/${number}" data-a="open">Episode details</a>
      <button class="btn ghost" data-a="cancel">Close</button>`, { cls: "editor" });
    s.el.addEventListener("click", async ev => {
      const a = ev.target.closest("[data-a]"); if (!a) return;
      const act = a.dataset.a;
      if (act === "cancel" || act === "open") return s.close();
      if (act === "toggle") {
        const on = !watched;
        setRow(row, on); if (season > 0) patchTotals(on ? 1 : -1);
        patchSeasonHeader(row.closest(".season"));
        if (on) sparks(row.querySelector(".tick"));
        delete CACHE["/dashboard"];
        api(`/show/${id}/watch`, { body: { season, number, unwatch: !on } }).catch(() => routes.show(id));
        syncUpNext();
        s.close();
      }
      if (act === "savedate") {
        const d = $("#wd", s.el).value; if (!d) return;
        const iso = d + "T12:00:00";
        if (e) e.watched_at = iso;
        const ews = $(".ews", row); if (ews) ews.textContent = "Watched " + fmtDate(d);
        await api(`/show/${id}/watch`, { body: { season, number, set_date: iso } });
        delete CACHE["/dashboard"];
        toast("Watched date updated"); s.close();
      }
    });
  }
  // long-press (touch) / right-click (desktop) an episode row -> action sheet
  let lpT = null, lpFired = false;
  view.onpointerdown = ev => {
    const row = ev.target.closest(".ep-row");
    if (!row || ev.target.closest(".tick")) return;
    lpFired = false;
    lpT = setTimeout(() => { lpFired = true; if (navigator.vibrate) navigator.vibrate(8); openEpSheet(row); }, 480);
  };
  const cancelLp = () => clearTimeout(lpT);
  view.onpointerup = cancelLp; view.onpointermove = cancelLp; view.onpointercancel = cancelLp;
  view.oncontextmenu = ev => {
    const row = ev.target.closest(".ep-row");
    if (row) { ev.preventDefault(); openEpSheet(row); }
  };
  const markEarlier = (season, number) => {
    let delta = 0;
    // update data for every earlier ep (rendered or not), then patch rendered rows
    epIndex.forEach(e => {
      if (e.season > 0 && !e.watched && e.air_date && e.air_date <= today &&
          (e.season < season || (e.season === season && e.number < number))) {
        e.watched = true; delta++;
      }
    });
    $$(".season", view).forEach(sb => {
      $$(".ep-row", sb).forEach(r => {
        const e = epIndex.get(`${+r.dataset.s}:${+r.dataset.n}`);
        if (e) r.classList.toggle("w", !!e.watched);
      });
      patchSeasonHeader(sb);
    });
    return delta;
  };

  if ($("#ov")) $("#ov").onclick = () => $("#ov").classList.toggle("clamp");
  if ($("#epedit")) $("#epedit").onclick = async () => {
    const maxSeason = Math.max(...s.seasons.map(se => se.season), 1);
    const r = await episodeEditor(id, maxSeason);
    if (r) { delete CACHE["/dashboard"]; routes.show(id); }
  };
  if ($("#follow")) $("#follow").onclick = async () => { await api(`/show/${id}/follow`, { body: {} }); delete CACHE["/dashboard"]; routes.show(id); };
  if ($("#arch")) $("#arch").onclick = async () => {
    await api(`/show/${id}/follow`, { body: { archived: !s.archived } }); delete CACHE["/dashboard"]; routes.show(id); };
  if ($("#unfollow")) $("#unfollow").onclick = async () => {
    if (confirm(`Remove ${s.title} and all its watch history?`)) {
      await api(`/show/${id}/follow`, { body: { unfollow: true } }); delete CACHE["/dashboard"]; location.hash = "#/"; } };
  $("#stars").onclick = e => {
    const v = e.target.closest("[data-v]")?.dataset.v;
    if (!v) return;
    $("#stars").innerHTML = stars(+v);
    api(`/show/${id}/follow`, { body: { rating: +v } }).catch(() => {});
  };

  view.onclick = async e => {
    if (lpFired) { lpFired = false; e.preventDefault(); return; }   // swallow the click after a long-press
    const box = e.target.closest(".season");
    if (!box) return;
    const season = +box.dataset.season;
    if (e.target.closest(".all")) {
      const un = !!$(".all", box).dataset.un;
      if (!$(".eps", box)) box.insertAdjacentHTML("beforeend", seasonHTML(seasonsByNum[season], today, id));
      let delta = 0;
      $$(".ep-row", box).forEach(r => { if (!r.classList.contains("future") || un) delta += setRow(r, !un); });
      patchSeasonHeader(box); if (season > 0) patchTotals(delta);
      if (!un) sparks($(".all", box));
      delete CACHE["/dashboard"];
      api(`/show/${id}/season/${season}/watch`, { body: { unwatch: un } }).catch(() => routes.show(id));
      syncUpNext();
      return;
    }
    const row = e.target.closest(".ep-row");
    if (row && e.target.closest(".custdel")) {
      if (!confirm(`Delete custom episode ${sxe(season, row.dataset.n)}?`)) return;
      await api(`/show/${id}/episodes/custom/delete`,
        { body: { season, number: +row.dataset.n } });
      const ep = epIndex.get(`${season}:${+row.dataset.n}`);
      if (ep?.watched) patchTotals(-1);
      epIndex.delete(`${season}:${+row.dataset.n}`);
      row.remove(); box.dataset.total = +box.dataset.total - 1;
      patchSeasonHeader(box);
      delete CACHE["/dashboard"];
      return;
    }
    if (row && e.target.closest(".tick")) {
      const on = !row.classList.contains("w");
      const number = +row.dataset.n;
      const tick = e.target.closest(".tick");
      if (on && season > 0) {
        const behind = earlierUnwatched(season, number);
        if (behind > 0) {
          const v = await ask(`You're ahead — ${behind} earlier episode${behind > 1 ? "s aren't" : " isn't"} marked yet.`,
            `Mark all ${behind + 1} up to here`, "Just this episode");
          if (v === "cancel") return;
          if (v === "primary") {
            let delta = markEarlier(season, number) + setRow(row, true);
            patchSeasonHeader(box); patchTotals(delta); sparks(tick);
            delete CACHE["/dashboard"];
            api(`/show/${id}/watch`, { body: { season, number, previous: true } })
              .catch(() => routes.show(id));
            syncUpNext();
            return;
          }
        }
      }
      const delta = setRow(row, on);
      if (season > 0) patchTotals(delta);
      patchSeasonHeader(box);
      if (on) {
        sparks(tick);
        const ep = epIndex.get(`${season}:${number}`);
        episodeDoneToast(id, season, number, ep?.title,
          pickImg(ep?.still, s.info?.season_posters?.[season], s.backdrop, s.poster));
      }
      delete CACHE["/dashboard"];
      api(`/show/${id}/watch`, { body: { season, number, unwatch: !on } })
        .catch(() => routes.show(id));
      syncUpNext();
      return;
    }
    if (e.target.closest("header") && !e.target.closest(".all")) {
      const willOpen = !box.classList.contains("open");
      if (willOpen && !$(".eps", box)) box.insertAdjacentHTML("beforeend", seasonHTML(seasonsByNum[season], today, id));
      box.classList.toggle("open", willOpen);
    }
  };
  renderUpNext();
};

/* ---------- episode page ---------- */
routes.episode = async (id, season, number) => {
  const stop = deferSkeleton(`<div class="ephero"><div class="sk" style="aspect-ratio:16/8.2;border-radius:0"></div></div>
    <div class="sk line-sk" style="max-width:280px;height:24px"></div>`);
  const e = await api(`/show/${id}/episode/${season}/${number}`);
  stop();
  const dur = e.runtime ? `${e.runtime} min · ` : "";
  const x = e.extra || {};
  view.innerHTML = `
    <div class="ephero">${(() => {
      const img = pickImg(e.still, e.season_poster, e.show_backdrop, e.show_poster);
      return img ? `<img class="still" src="${img}" alt="">` : `<div class="nostill"></div>`;
    })()}</div>
    <div class="epbody reveal">
      <a class="crumb" href="#/show/${id}">${I.chevS} ${esc(e.show_title)}</a>
      <h1>${esc(e.title || "Episode " + e.number)}</h1>
      <div class="epmeta"><b>${sxe(e.season, e.number)}</b> · ${dur}${e.air_date ? fmtDate(e.air_date) : "TBA"}
        ${x.vote ? ` · <span class="chip star">${I.star} ${x.vote}</span>` : ""}
        ${e.watched && e.watched_at ? ` · watched ${fmtDate(e.watched_at)}` : ""}</div>
      ${e.overview ? veil(`<p class="overview">${esc(e.overview)}</p>`,
        { watched: e.watched, cls: "sp-overview", label: "Episode spoilers" }) : ""}
      ${x.directors?.length || x.writers?.length ? `<div class="credits">
        ${x.directors?.length ? `<span><b>Directed by</b> ${esc(x.directors.join(", "))}</span>` : ""}
        ${x.writers?.length ? `<span><b>Written by</b> ${esc(x.writers.join(", "))}</span>` : ""}</div>` : ""}
      <div class="ep-actions">
        <button class="bigmark ${e.watched ? "on" : ""}" id="mark">${I.check}
          <span>${e.watched ? "Watched" : "Mark watched"}</span></button>
        <button class="iconbtn lg" id="epshare" title="Share">${I.share}</button>
      </div>
      <div id="ep-reviews"></div>
      ${x.guests?.length ? `<div class="sub-h">Guest stars</div>${castStrip(x.guests)}` : ""}
      <div class="epnav">
        ${e.prev ? `<a class="btn" href="#/show/${id}/e/${e.prev.season}/${e.prev.number}">Previous</a>` : ""}
        <span class="spacer"></span>
        ${e.next ? `<a class="btn" href="#/show/${id}/e/${e.next.season}/${e.next.number}">Next episode</a>` : ""}
      </div>
    </div>`;
  const epKey = (+id) * 1000000 + (+season) * 1000 + (+number);
  reviewsBlock("episode", epKey, { watched: !!e.watched }).then(el => { const c = $("#ep-reviews"); if (c) c.appendChild(el); });
  $("#epshare").onclick = () => share(`${e.show_title} — ${sxe(e.season, e.number)}`, `show/${id}/e/${season}/${number}`);
  $("#mark").onclick = async () => {
    const b = $("#mark");
    const on = !b.classList.contains("on");
    let previous = false;
    if (on && +season > 0 && e.earlier_unwatched > 0) {
      const v = await ask(`You're ahead — ${e.earlier_unwatched} earlier episode${e.earlier_unwatched > 1 ? "s aren't" : " isn't"} marked yet.`,
        `Mark all ${e.earlier_unwatched + 1} up to here`, "Just this episode");
      if (v === "cancel") return;
      previous = v === "primary";
    }
    b.classList.toggle("on", on);
    $("span", b).textContent = on ? "Watched" : "Mark watched";
    if (on) {
      sparks(b);
      episodeDoneToast(id, season, number, e.title,
        pickImg(e.still, e.season_poster, e.show_backdrop, e.show_poster));
    }
    if (previous) e.earlier_unwatched = 0;
    delete CACHE["/dashboard"];
    api(`/show/${id}/watch`, { body: { season: +season, number: +number, unwatch: !on, previous } }).catch(() => {});
  };
};

/* ---------- movies ---------- */
function renderMovies(d, tab, animate = true) {
  const grid = arr => arr.length ? `<div class="pgrid ${animate ? "reveal" : ""}">${arr.map(m => `
    <div class="pcard" data-id="${m.id}">
      <div class="pshot"><a href="#/movie/${m.id}"><img class="poster" loading="lazy" src="${POSTER(m.poster)}" alt=""></a>
        ${m.rating ? `<span class="badge">${m.rating}/10</span>` : ""}
        <div class="act">
          ${tab === "watchlist" ? `<button title="Mark watched" data-a="watched">${I.check}</button>` : ""}
          <button title="Remove" data-a="none">${I.x}</button>
        </div>
      </div>
      <a class="t" href="#/movie/${m.id}">${esc(m.title)}</a><div class="y">${m.year || ""}${m.watched_at ? " · " + fmtDate(m.watched_at) : ""}</div>
    </div>`).join("")}</div>` : `<div class="empty">Nothing here yet — find something in Search.</div>`;
  view.innerHTML = `<h1>Movies</h1>
    <div class="tabs">
      <button data-t="watched" class="${tab === "watched" ? "on" : ""}">Watched · ${d.watched.length}</button>
      <button data-t="watchlist" class="${tab === "watchlist" ? "on" : ""}">Watchlist · ${d.watchlist.length}</button>
    </div>${grid(d[tab])}`;
  $$(".tabs button", view).forEach(b => b.onclick = () => routes.movies(b.dataset.t));
  $$(".pcard .act button", view).forEach(b => b.onclick = async () => {
    const card = b.closest(".pcard");
    const idx = d[tab].findIndex(m => m.id === +card.dataset.id);
    const [m] = d[tab].splice(idx, 1);
    if (b.dataset.a === "watched") { m.state = "watched"; m.watched_at = nowStamp(); d.watched.unshift(m); sparks(b); }
    api(`/movie/${card.dataset.id}/state`, { body: { state: b.dataset.a } }).catch(() => routes.movies(tab));
    renderMovies(d, tab);
  });
}
routes.movies = (tab = "watched") => {
  const c = cached("/movies");
  if (c.stale) renderMovies(c.stale, tab);
  else view.innerHTML = `<h1>Movies</h1><div class="pgrid">${Array.from({ length: 12 }, () => `<div class="sk pcard-sk"></div>`).join("")}</div>`;
  c.refresh(() => seg()[0] === "movies", d => renderMovies(d, tab, !c.stale));
};

/* ---------- reading (books + manga/manhwa/manhua) — per-user opt-in ---------- */
const BOOK_ICO = `<svg viewBox="0 0 24 24"><path d="M4 5.5C6.7 4.6 9.6 4.9 12 6.6c2.4-1.7 5.3-2 8-1.1v12.9c-2.7-.9-5.6-.6-8 1.1-2.4-1.7-5.3-2-8-1.1z" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><path d="M12 6.6v12.9" stroke="currentColor" stroke-width="1.9"/></svg>`;
// the Reading destination only exists in the DOM for users who switched a tracking
// feature on — everyone else's nav is untouched
function applyFeatureNav() {
  $$('a[data-r="reading"]').forEach(a => a.remove());
  const f = (ME && ME.features) || {};
  if (!f.books && !f.manga) return;
  const label = f.books && f.manga ? "Reading" : f.books ? "Books" : "Manga";
  const link = `<a href="#/reading" data-r="reading">${BOOK_ICO}<span>${label}</span></a>`;
  const moviesPill = $('#nav a[data-r="movies"]');
  if (moviesPill) moviesPill.insertAdjacentHTML("afterend", link);
  const tabAvatar = $("#tabavatar");
  if (tabAvatar) tabAvatar.insertAdjacentHTML("beforebegin", link);
}

function rdCard(it, kind, section) {
  const total = kind === "book" ? it.pages : it.chapters;
  const unit = kind === "book" ? "p" : "ch";
  const pct = total && it.progress ? Math.min(100, Math.round(100 * it.progress / total)) : 0;
  const sub = kind === "book" ? esc(it.author || "") :
    `<span class="o-chip">${esc(it.origin || "manga")}</span>${it.status ? " " + esc(it.status) : ""}`;
  const acts =
    section === "reading" ? (kind === "manga" ? `<button title="+1 chapter" data-a="plus">${I.plus}</button>` : "")
      + `<button title="Finished it" data-a="finish">${I.check}</button>`
    : section === "want" ? `<button title="Start ${kind === "book" ? "reading" : "it"}" data-a="start">${I.eye}</button>
        <button title="Remove" data-a="none">${I.x}</button>`
    : `<button title="Remove" data-a="none">${I.x}</button>`;
  return `<div class="pcard rdcard" data-id="${it.id}" data-kind="${kind}">
    <div class="pshot"><img class="poster" loading="lazy" src="${POSTER(it.cover)}" alt="">
      ${it.rating ? `<span class="badge">${it.rating}/10</span>` : ""}
      <div class="act">${acts}</div>
      ${section === "reading" ? `<div class="rd-prog" title="${it.progress || 0}${total ? " of " + total : ""} ${unit}"><i style="width:${pct}%"></i></div>` : ""}
    </div>
    <a class="t" href="#/reading">${esc(it.title)}</a>
    <div class="y">${sub}${section === "reading" ? ` · ${it.progress || 0}${total ? "/" + total : ""} ${unit}` : ""}
      ${section === "finished" && it.finished_at ? esc(fmtDate(it.finished_at.slice(0, 10))) : ""}</div>
  </div>`;
}

function rdSheet(it, kind, refresh) {
  const total = kind === "book" ? it.pages : it.chapters;
  const unit = kind === "book" ? "pages" : "chapters";
  const stars = r => Array.from({ length: 5 }, (_, k) => `<span data-v="${(k + 1) * 2}"
    class="${(r || 0) >= (k + 1) * 2 ? "b" : ""}">${I.star}</span>`).join("");
  const links = kind === "book"
    ? `<a class="chip-btn" target="_blank" rel="noopener" href="https://openlibrary.org/works/${it.olid}">Open Library</a>
       <a class="chip-btn" target="_blank" rel="noopener" href="https://www.goodreads.com/search?q=${encodeURIComponent(it.title + " " + (it.author || ""))}"><b>goodreads</b></a>`
    : `<a class="chip-btn" target="_blank" rel="noopener" href="https://anilist.co/manga/${it.id}">AniList</a>`;
  const s = sheet(`<div class="rd-sheet">
    <div class="rd-top"><img src="${POSTER(it.cover)}" alt="">
      <div class="rd-meta"><b>${esc(it.title)}</b>
        <span>${kind === "book" ? esc(it.author || "") : `<span class="o-chip">${esc(it.origin || "manga")}</span> ${esc(it.status || "")}`}${it.year ? ` · ${it.year}` : ""}</span>
        ${total ? `<span class="hint">${total} ${unit}</span>` : ""}</div></div>
    <div class="rd-states">${["want", "reading", "finished"].map(st =>
      `<button class="rd-st ${it.state === st ? "on" : ""}" data-st="${st}">${st === "want" ? (kind === "book" ? "Want to read" : "Want to read") : st === "reading" ? "Reading" : "Finished"}</button>`).join("")}</div>
    <div class="rd-progrow"><label>Progress</label>
      <button class="iconbtn" id="rdminus">−</button>
      <input id="rdprog" type="number" min="0" ${total ? `max="${total}"` : ""} value="${it.progress || 0}">
      <button class="iconbtn" id="rdplus">+</button>
      <span class="hint">${total ? "of " + total : ""} ${unit}</span></div>
    <div class="rd-raterow"><label>My rating</label><span class="stars" id="rdstars">${stars(it.rating)}</span></div>
    <div class="rdw-dates">
      <label>Started<input type="date" id="rdstart"
        value="${(it.started_at || "").slice(0, 10)}" max="${nowStamp().slice(0, 10)}"></label>
      <label>Finished<input type="date" id="rdfin"
        value="${(it.finished_at || "").slice(0, 10)}" max="${nowStamp().slice(0, 10)}"></label></div>
    <div class="act-row">${links}</div>
    <button class="btn danger ghost" id="rdremove">${I.x} Remove from my ${kind === "book" ? "books" : "shelf"}</button>
  </div>`);
  const post = body => api(`/${kind}/${it.id}/state`, { body })
    .then(() => { delete CACHE["/reading"]; }).catch(() => {});
  $$(".rd-st", s.el).forEach(b => b.onclick = () => {
    $$(".rd-st", s.el).forEach(x => x.classList.remove("on")); b.classList.add("on");
    it.state = b.dataset.st;
    if (it.state === "finished" && total) { it.progress = total; $("#rdprog", s.el).value = total; }
    post({ state: it.state, progress: it.progress });
  });
  const setProg = v => { it.progress = Math.max(0, total ? Math.min(total, v) : v);
    $("#rdprog", s.el).value = it.progress; post({ progress: it.progress }); };
  $("#rdminus", s.el).onclick = () => setProg((it.progress || 0) - 1);
  $("#rdplus", s.el).onclick = () => setProg((it.progress || 0) + 1);
  $("#rdprog", s.el).onchange = () => setProg(+$("#rdprog", s.el).value || 0);
  $("#rdstars", s.el).onclick = e => {
    const t = e.target.closest("[data-v]"); if (!t) return;
    it.rating = it.rating === +t.dataset.v ? null : +t.dataset.v;
    $$("#rdstars span", s.el).forEach(sp => sp.classList.toggle("b", (it.rating || 0) >= +sp.dataset.v));
    post({ rating: it.rating });
  };
  $("#rdstart", s.el).onchange = () => { it.started_at = $("#rdstart", s.el).value || null;
    post({ started_at: it.started_at }); };
  $("#rdfin", s.el).onchange = () => { it.finished_at = $("#rdfin", s.el).value || null;
    post({ finished_at: it.finished_at }); };
  $("#rdremove", s.el).onclick = async () => { await post({ state: "none" }); s.close(); refresh(); };
  s.el.addEventListener("click", e => { if (e.target === s.el) refresh(); });
}

/* fill-in-dates wizard: steps through titles missing read dates (imports carry a
   Goodreads finish date at best — Goodreads never exports start dates) */
function rdNeedsDates(it) {
  const s10 = v => (v || "").slice(0, 10);
  if (it.state === "reading") return !it.started_at;
  if (it.state === "finished")
    return !it.finished_at || !it.started_at || s10(it.started_at) === s10(it.finished_at);
  return false;
}
function rdDatesWizard(items, kind, refresh) {
  let i = 0, saved = 0;
  const s = sheet(`<div class="rd-sheet rdw"><div id="rdwbody"></div></div>`);
  const step = () => {
    if (i >= items.length) {
      toast(saved ? `Dates saved for ${saved} title${saved > 1 ? "s" : ""}` : "All done");
      s.close(); if (saved) refresh(); return;
    }
    const it = items[i];
    const s10 = v => (v || "").slice(0, 10);
    const startVal = s10(it.started_at) === s10(it.finished_at) ? "" : s10(it.started_at);
    $("#rdwbody", s.el).innerHTML = `
      <div class="rd-top"><img src="${POSTER(it.cover)}" alt="">
        <div class="rd-meta"><b>${esc(it.title)}</b>
          <span>${kind === "book" ? esc(it.author || "") : `<span class="o-chip">${esc(it.origin || "manga")}</span>`}</span>
          <span class="hint">${it.state === "finished" ? "When did you read it?" : "When did you start it?"}</span></div></div>
      <div class="rdw-dates">
        <label>Started<input type="date" id="rdws" value="${startVal}" max="${nowStamp().slice(0, 10)}"></label>
        ${it.state === "finished" ? `<label>Finished<input type="date" id="rdwf"
          value="${s10(it.finished_at)}" max="${nowStamp().slice(0, 10)}"></label>` : ""}</div>
      <div class="rdw-nav">
        <button class="btn ghost" id="rdwskip">Skip</button>
        <span class="hint">${i + 1} of ${items.length}</span>
        <button class="btn pri" id="rdwsave">${I.check} Save${i + 1 < items.length ? " & next" : ""}</button>
      </div>`;
    $("#rdwskip", s.el).onclick = () => { i++; step(); };
    $("#rdwsave", s.el).onclick = async () => {
      const body = {};
      const sv = $("#rdws", s.el).value, fv = $("#rdwf", s.el)?.value;
      if (sv) body.started_at = sv;
      if (fv) body.finished_at = fv;
      if (Object.keys(body).length) {
        await api(`/${kind}/${it.id}/state`, { body }).catch(() => {});
        Object.assign(it, body); saved++;
        delete CACHE["/reading"];
      }
      i++; step();
    };
  };
  step();
}

function renderReading(d, tab, animate = true) {
  const f = (ME && ME.features) || {};
  const both = f.books && f.manga;
  if (!f[tab]) tab = f.books ? "books" : "manga";
  const kind = tab === "books" ? "book" : "manga";
  const dd = d[tab];
  const rv = animate ? "reveal" : "";
  const section = (title, arr, sec) => arr.length
    ? `<div class="sub-h">${title} · ${arr.length}</div><div class="pgrid ${rv}">${arr.map(x => rdCard(x, kind, sec)).join("")}</div>` : "";
  view.innerHTML = `<h1>${both ? "Reading" : tab === "books" ? "Books" : "Manga"}</h1>
    ${both ? `<div class="tabs">
      <button data-t="books" class="${tab === "books" ? "on" : ""}">Books</button>
      <button data-t="manga" class="${tab === "manga" ? "on" : ""}">Manga</button></div>` : ""}
    <div class="rd-search"><input id="rdq" type="search" enterkeyhint="search"
        placeholder="${tab === "books" ? "Add a book — search Open Library" : "Add manga · manhwa · manhua — search AniList"}">
      <button class="btn" id="rdgo">${I.plus} Add</button></div>
    <div id="rdresults"></div>
    ${(() => { const n = [...dd.reading, ...dd.finished].filter(rdNeedsDates).length;
      return n ? `<div class="rd-banner"><span><svg viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="15" rx="2.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M8 3v4M16 3v4M3.5 10.3h17" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>
        ${n} title${n > 1 ? "s are" : " is"} missing read dates — they power your stats</span>
        <button class="btn pri" id="rddates">Fill in</button></div>` : ""; })()}
    ${section("Reading now", dd.reading, "reading")}
    ${section("Want to read", dd.want, "want")}
    ${section("Finished", dd.finished, "finished")}
    ${dd.reading.length + dd.want.length + dd.finished.length ? "" :
      `<div class="empty">Nothing on the shelf yet — search above to add your first ${tab === "books" ? "book" : "series"}.</div>`}`;

  const refresh = () => { delete CACHE["/reading"]; routes.reading(tab); };
  if ($("#rddates")) $("#rddates").onclick = () =>
    rdDatesWizard([...dd.reading, ...dd.finished].filter(rdNeedsDates), kind, refresh);
  $$(".tabs button", view).forEach(b => b.onclick = () => routes.reading(b.dataset.t));
  const doSearch = async () => {
    const q = $("#rdq").value.trim(); if (!q) return;
    $("#rdresults").innerHTML = `<div class="hint" style="margin:10px 0">Searching…</div>`;
    const r = await api(`/${tab === "books" ? "books" : "manga"}/search?q=${encodeURIComponent(q)}`).catch(() => ({ results: [] }));
    $("#rdresults").innerHTML = r.results.length ? `<div class="sub-h">Results</div>
      <div class="pgrid reveal">${r.results.map((x, i) => `
        <div class="pcard rdres" data-i="${i}">
          <div class="pshot"><img class="poster" loading="lazy" src="${POSTER(x.cover)}" alt="">
            ${x.score ? `<span class="badge">${x.score}</span>` : ""}
            <div class="act"><button title="Want to read" data-a="want">${I.bookmark}</button>
              <button title="Start now" data-a="reading">${I.eye}</button></div></div>
          <span class="t">${esc(x.title)}</span>
          <div class="y">${tab === "books" ? esc(x.author || "") : `<span class="o-chip">${esc(x.origin)}</span>`}${x.year ? ` · ${x.year}` : ""}</div>
        </div>`).join("")}</div>`
      : `<div class="empty">No matches for “${esc(q)}”.</div>`;
    $$(".rdres .act button", view).forEach(b => b.onclick = async () => {
      const x = r.results[+b.closest(".rdres").dataset.i];
      b.disabled = true; sparks(b);
      await api(tab === "books" ? "/books/add" : "/manga/add",
        { body: { ...x, state: b.dataset.a } }).catch(() => {});
      toast(`${x.title} — ${b.dataset.a === "want" ? "on the shelf" : "started"}`);
      refresh();
    });
  };
  $("#rdgo").onclick = doSearch;
  $("#rdq").onkeydown = e => { if (e.key === "Enter") doSearch(); };

  $$(".rdcard", view).forEach(card => {
    const it = [...dd.reading, ...dd.want, ...dd.finished].find(x => x.id === +card.dataset.id);
    card.onclick = e => {
      const b = e.target.closest(".act button");
      e.preventDefault();
      if (!b) { rdSheet(it, kind, refresh); return; }
      const a = b.dataset.a;
      const total = kind === "book" ? it.pages : it.chapters;
      const body = a === "plus" ? { progress: Math.min(total || 1e9, (it.progress || 0) + 1) }
        : a === "finish" ? { state: "finished", progress: total || it.progress }
        : a === "start" ? { state: "reading" } : { state: "none" };
      if (a === "plus" || a === "finish") sparks(b);
      api(`/${kind}/${it.id}/state`, { body }).then(() => {
        if (a === "plus") { it.progress = body.progress;
          const y = card.querySelector(".y"), pr = card.querySelector(".rd-prog i");
          if (y) y.innerHTML = y.innerHTML.replace(/\d+(?=\/|\s)/, it.progress);
          if (pr && total) pr.style.width = Math.min(100, Math.round(100 * it.progress / total)) + "%";
          if (total && it.progress >= total) { delete CACHE["/reading"]; routes.reading(tab); }
          delete CACHE["/reading"];
        } else { refresh(); }
      }).catch(() => refresh());
    };
  });
}
routes.reading = (tab) => {
  const f = (ME && ME.features) || {};
  if (!f.books && !f.manga) { location.hash = "#/"; return; }
  tab = tab || (f.books ? "books" : "manga");
  const c = cached("/reading");
  if (c.stale) renderReading(c.stale, tab);
  else view.innerHTML = `<h1>Reading</h1><div class="pgrid">${Array.from({ length: 6 }, () => `<div class="sk pcard-sk"></div>`).join("")}</div>`;
  c.refresh(() => seg()[0] === "reading", d => renderReading(d, tab, !c.stale));
};

/* ---------- lists ---------- */
// one list summary card (reused on /lists and, via renderProfileLists, on profiles)
function listCard(l) {
  return `<a class="listcard" href="#/list/${l.id}">
    <div class="lc-covers">${(l.posters.length
      ? l.posters.slice(0, 4).map(p => `<img loading="lazy" src="${p}" alt="">`).join("")
      : `<div class="lc-empty">${I.bookmark}</div>`)}
      ${l.visibility === "public" ? `<span class="lc-vis">${I.globe}Public</span>`
        : l.visibility === "collab" ? `<span class="lc-vis collab">${I.users}Collab</span>` : ""}</div>
    <div class="lc-body"><div class="lc-name">${l.is_default ? I.bookmarkfill : ""} ${esc(l.name)}</div>
      <div class="lc-count">${l.count} ${l.count === 1 ? "title" : "titles"}${l.owner ? ` · ${esc(l.owner)}’s` : ""}</div></div>
  </a>`;
}
function renderLists(d) {
  const shared = d.shared || [];
  view.innerHTML = `<div class="page-head"><h1>Lists</h1>
    <button class="btn pri" id="newlist">${I.plus} New list</button></div>
    <div class="list-grid reveal">${d.lists.map(listCard).join("")}</div>
    ${shared.length ? `<div class="section" style="margin-top:26px"><h2>Shared with the house</h2><div class="rule"></div></div>
    <div class="list-grid reveal">${shared.map(listCard).join("")}</div>` : ""}`;
  $("#newlist").onclick = async () => {
    const s = sheet(`<div class="sh-t">New list</div>
      <input id="ln" placeholder="e.g. Weekend binges" maxlength="60" autofocus>
      <div class="vis-choice" id="vc">
        <button type="button" class="vis-opt on" data-vis="private">
          <span class="vis-ic">${I.lock}</span>
          <span class="vis-txt"><b>Private</b><i>Only you can see this list</i></span>
          <span class="vis-dot"></span>
        </button>
        <button type="button" class="vis-opt" data-vis="public">
          <span class="vis-ic">${I.globe}</span>
          <span class="vis-txt"><b>Public</b><i>Household members can see it on your profile</i></span>
          <span class="vis-dot"></span>
        </button>
        <button type="button" class="vis-opt" data-vis="collab">
          <span class="vis-ic">${I.users}</span>
          <span class="vis-txt"><b>Collaborative</b><i>Everyone in the household can add &amp; remove titles</i></span>
          <span class="vis-dot"></span>
        </button>
      </div>
      <div class="aud-row" id="nlaud" hidden><span class="aud-lbl">Shared with</span>
        <select id="nlaudsel" class="aud-sel">
          <option value="all">Everyone in the household</option>
          <option value="some">Specific people…</option>
        </select></div>
      <div id="nlaudpick" class="aud-pick" hidden></div>
      <button class="btn pri" data-v="save">Create list</button>
      <button class="btn ghost" data-v="cancel">Cancel</button>`, { cls: "editor listnew" });
    setTimeout(() => $("#ln", s.el)?.focus(), 60);
    let nlPicked = [];
    const nlMembers = () => {
      const box = $("#nlaudpick", s.el);
      if (box.dataset.done) return;
      audChips(box, nlPicked, ids => { nlPicked = ids; });
      box.dataset.done = 1;
    };
    $("#nlaudsel", s.el).onchange = e => {
      const some = e.target.value === "some";
      $("#nlaudpick", s.el).hidden = !some;
      if (some) nlMembers();
    };
    s.el.addEventListener("click", async e => {
      const opt = e.target.closest(".vis-opt");
      if (opt) {
        $$(".vis-opt", s.el).forEach(o => o.classList.toggle("on", o === opt));
        const shared = opt.dataset.vis !== "private";
        $("#nlaud", s.el).hidden = !shared;
        $("#nlaudpick", s.el).hidden = !shared || $("#nlaudsel", s.el).value !== "some";
        return;
      }
      if (e.target.closest('[data-v="cancel"]')) return s.close();
      if (e.target.closest('[data-v="save"]')) {
        const name = $("#ln", s.el).value.trim();
        if (!name) return;
        const visibility = $(".vis-opt.on", s.el)?.dataset.vis || "private";
        const shared_with = visibility !== "private" && $("#nlaudsel", s.el).value === "some"
          ? nlPicked : [];
        await api("/lists", { body: { name, visibility, shared_with } });
        delete CACHE["/lists"]; s.close(); routes.lists();
      }
    });
  };
}
routes.lists = () => {
  const c = cached("/lists");
  if (c.stale) renderLists(c.stale);
  else view.innerHTML = `<div class="page-head"><h1>Lists</h1></div>
    <div class="list-grid">${Array.from({ length: 4 }, () => `<div class="sk" style="height:150px;border-radius:14px"></div>`).join("")}</div>`;
  c.refresh(() => seg()[0] === "lists", d => renderLists(d, !c.stale));
};

// search-and-add sheet for putting titles onto a list (used by owners + collaborators)
function listAddSheet(listId, onDone) {
  const s = sheet(`<div class="sh-t">Add titles</div>
    <div class="fav-search"><input id="lq" placeholder="Search shows & movies…" autocapitalize="none" autocomplete="off"></div>
    <div id="lres" class="fav-results"><div class="fav-hint">Type to search TMDB.</div></div>
    <button class="btn ghost" data-v="done">Done</button>`, { cls: "favpicker" });
  const q = $("#lq", s.el), res = $("#lres", s.el);
  let t = null, last = "", added = false;
  q.oninput = () => {
    clearTimeout(t); const v = q.value.trim();
    if (v.length < 2) { res.innerHTML = `<div class="fav-hint">Keep typing…</div>`; return; }
    t = setTimeout(async () => {
      if (v === last) return; last = v;
      res.innerHTML = skRows(3);
      let data; try { data = await api("/search?q=" + encodeURIComponent(v)); } catch { return; }
      if ($("#lq", s.el)?.value.trim() !== v) return;
      const items = (data.results || []).filter(r => r.poster);
      res.innerHTML = items.length ? items.map(r => `
        <button class="fav-opt" data-t="${r.type}" data-id="${r.id}">
          <img loading="lazy" src="${POSTER(r.poster)}" alt="">
          <span class="fo-mid"><b>${esc(r.title)}</b><span class="fo-sub">${r.type === "show" ? "TV" : "Movie"}${r.year ? " · " + r.year : ""}</span></span>
          <span class="fo-add">${I.plus}</span></button>`).join("")
        : `<div class="fav-hint">No matches.</div>`;
    }, 260);
  };
  res.addEventListener("click", async e => {
    const opt = e.target.closest(".fav-opt"); if (!opt) return;
    opt.classList.add("busy");
    try {
      await api(`/list/${listId}/item`, { body: { item_type: opt.dataset.t, item_id: +opt.dataset.id } });
      sparks(opt); toast("Added"); added = true; delete CACHE["/lists"];
      opt.querySelector(".fo-add").innerHTML = I.check;
      onDone && onDone();   // live-update the list behind the sheet so items appear immediately
    } catch { opt.classList.remove("busy"); }
  });
  s.el.addEventListener("click", e => {
    if (e.target.closest('[data-v="done"]')) { s.close(); if (added) onDone && onDone(); }
  });
  setTimeout(() => q.focus(), 80);
}

// Compact toggle chips for the shared-list audience picker (avatar + name in a
// wrapping row; tap to include/exclude). `wire` gets the array of selected ids
// after each toggle. Members are cached so re-opening the picker is instant.
let _membersCache = null;
async function audChips(box, selected, wire) {
  if (!_membersCache) _membersCache = (await api("/members")).members;
  const sel = new Set(selected || []);
  const others = _membersCache.filter(m => !m.is_me);
  box.innerHTML = `<div class="aud-chips">${others.map(m =>
    `<button type="button" class="aud-chip ${sel.has(m.id) ? "on" : ""}" data-id="${m.id}">
       ${avatarHTML(m, "xs")}<span>${esc(m.display_name)}</span></button>`).join("")}</div>
    <i class="aud-hint">No one picked = everyone.</i>`;
  $$(".aud-chip", box).forEach(c => c.onclick = () => {
    c.classList.toggle("on");
    wire($$(".aud-chip.on", box).map(x => +x.dataset.id));
  });
}

// list sorting (client-side; keys survive across list navigations)
let LISTSORT = "added";
const LIST_SORTS = [
  ["added", "Recently added", (a, b) => (b.added_at || "").localeCompare(a.added_at || "")],
  ["watched", "Recently watched", (a, b) => (b.last_watched || "").localeCompare(a.last_watched || "")],
  ["first", "First watched", (a, b) => (a.first_watched || "~").localeCompare(b.first_watched || "~")],
  ["released", "Newest release", (a, b) => (b.year || 0) - (a.year || 0)],
  ["title", "Title A–Z", (a, b) => (a.title || "").localeCompare(b.title || "")],
];
const listSortLabel = () => (LIST_SORTS.find(s => s[0] === LISTSORT) || LIST_SORTS[0])[1];
const listSortFn = () => (LIST_SORTS.find(s => s[0] === LISTSORT) || LIST_SORTS[0])[2];

// per-item progress: amber bar (in progress) · purple (complete + ended) · red (stopped watching)
function listSortSheet(onPick) {
  const s = sheet(`<div class="sh-t">Sort by</div>
    <div class="sortopts">${LIST_SORTS.map(([k, lab]) =>
      `<button class="sortopt ${k === LISTSORT ? "on" : ""}" data-k="${k}"><span>${lab}</span>${k === LISTSORT ? I.check : ""}</button>`).join("")}</div>`,
    { cls: "editor" });
  s.el.addEventListener("click", e => {
    const o = e.target.closest(".sortopt"); if (!o) return;
    LISTSORT = o.dataset.k; s.close(); onPick();
  });
}

routes.list = async (id, quiet) => {
  if (!quiet) view.innerHTML = `<div class="sk line-sk" style="width:200px;height:26px;margin-bottom:16px"></div>${skRows(4)}`;
  const l = await api(`/list/${id}`);
  const owner = l.is_owner, canEdit = l.can_edit ?? owner, vis = l.visibility || "private";
  const crumb = owner || vis === "collab"
    ? `<a class="crumb" href="#/lists">${I.chevS} Lists</a>`
    : `<a class="crumb" href="#/u/${encodeURIComponent(l.owner.username)}">${I.chevS} ${esc(l.owner.display_name)}</a>`;
  const VIS = [["private", "Private", I.lock], ["public", "Public", I.globe], ["collab", "Collab", I.users]];
  const visNote = { private: "Only you can see this list.",
    public: "Household members can see this on your profile.",
    collab: "Household members can see it and add or remove titles." };
  // list items use the Watch-Next card look: poster + scrim + bottom info overlay w/ progress
  const itemCard = it => {
    const isShow = it.type === "show", total = it.total || 0;
    const watched = Math.min(it.watched || 0, total || (it.watched || 0));
    const complete = total > 0 && watched >= total;
    const pcls = it.archived ? "stopped" : (complete && it.ended) ? "done" : "";
    let line = "", bar = "";
    if (!isShow) {
      line = it.watched ? `${I.check} Watched` : (it.year ? "" + it.year : "");
    } else if (it.archived) {
      const pct = total ? Math.round(100 * watched / total) : 0;
      line = "Stopped watching";
      bar = `<div class="pbar"><div class="pbar-track"><div class="pbar-fill stopped" style="--p:${pct}%"></div></div><div class="pbar-num stopped">${pct}%</div></div>`;
    } else if (total) {
      const pct = Math.round(100 * watched / total);
      line = complete ? (it.ended ? "Series complete" : "All caught up") : `${watched} / ${total} watched`;
      bar = `<div class="pbar"><div class="pbar-track"><div class="pbar-fill ${pcls}" style="--p:${pct}%"></div></div><div class="pbar-num ${pcls}">${pct}%</div></div>`;
    } else {
      line = it.year ? "" + it.year : "";
    }
    return `<div class="bcard listcard" data-type="${it.type}" data-id="${it.id}">
      <img class="poster" loading="lazy" src="${POSTER(it.poster)}" alt="">
      <div class="scrim"></div>
      <a class="fill" href="#/${it.type}/${it.id}" aria-label="${esc(it.title)}"></a>
      ${it.ended ? `<span class="ended-tag">${I.flag} Ended</span>` : `<span class="badge">${isShow ? "TV" : "FILM"}</span>`}
      ${canEdit ? `<button class="lc-rm rmlist" title="Remove from list">${I.x}</button>` : ""}
      <div class="info">
        <div class="t">${esc(it.title)}</div>
        ${line ? `<div class="ep">${line}</div>` : ""}
        ${bar}
      </div>
    </div>`;
  };
  const gridHTML = () => [...l.items].sort(listSortFn()).map(itemCard).join("");
  view.innerHTML = `<div class="page-head">
      ${crumb}
      <div class="ph-actions">
        ${canEdit ? `<button class="iconbtn" id="addtitles" title="Add titles">${I.plus}</button>` : ""}
        <button class="iconbtn" id="sharelist" title="Share">${I.share}</button>
        ${owner && !l.is_default ? `<button class="iconbtn" id="dellist" title="Delete list">${I.trash}</button>` : ""}
      </div>
    </div>
    <h1>${l.is_default ? I.bookmarkfill : ""} ${esc(l.name)} <span class="cnt">· ${l.items.length}</span></h1>
    ${owner
      ? `<div class="vis-seg" id="visseg" role="group" aria-label="List visibility">
           ${VIS.map(([v, lab, ic]) => `<button class="vs-opt ${vis === v ? "on" : ""}" data-vis="${v}">${ic}<span>${lab}</span></button>`).join("")}
         </div>
         <div class="vis-note">${visNote[vis]}</div>
         ${vis !== "private" ? `
         <div class="aud-row"><span class="aud-lbl">Shared with</span>
           <select id="audsel" class="aud-sel">
             <option value="all"${l.shared_with?.length ? "" : " selected"}>Everyone in the household</option>
             <option value="some"${l.shared_with?.length ? " selected" : ""}>Specific people…</option>
           </select></div>
         <div id="audpick" class="aud-pick" ${l.shared_with?.length ? "" : "hidden"}></div>` : ""}`
      : `<div class="list-owner">${avatarHTML(l.owner, "sm")}
           <span class="lo-txt">Shared by <b>@${esc(l.owner.username)}</b></span>
           <span class="vis-pill ${vis}">${vis === "collab" ? `${I.users} Collaborative` : `${I.globe} Public`}</span></div>
         ${vis === "collab" ? `<div class="vis-note">You can add &amp; remove titles on this shared list.</div>` : ""}`}
    ${l.items.length ? `
      ${l.items.length > 1 ? `<div class="list-tools"><button class="ls-btn" id="lsort">${I.sort}<span id="lsortlbl">${listSortLabel()}</span></button></div>` : ""}
      <div class="pgrid reveal" id="listgrid">${gridHTML()}</div>`
      : `<div class="empty">${canEdit ? "This list is empty. Tap + to add titles, or add from any show or movie page." : "This list is empty."}</div>`}`;
  const wireItems = () => {
    if (!canEdit) return;
    $$(".rmlist", view).forEach(b => b.onclick = async e => {
      e.preventDefault(); e.stopPropagation();
      const c = b.closest(".bcard");
      await api(`/list/${id}/item`, { body: { item_type: c.dataset.type, item_id: +c.dataset.id, remove: true } });
      c.style.opacity = ".3"; c.querySelector(".rmlist").disabled = true;
      delete CACHE["/lists"];
      setTimeout(() => routes.list(id, true), 220);
    });
  };
  $("#sharelist").onclick = () => share(l.name, `list/${id}`);
  if ($("#addtitles")) $("#addtitles").onclick = () => listAddSheet(id, () => routes.list(id, true));
  if ($("#lsort")) $("#lsort").onclick = () => listSortSheet(() => {
    const g = $("#listgrid"); if (g) g.innerHTML = gridHTML(); wireItems();
    const lbl = $("#lsortlbl"); if (lbl) lbl.textContent = listSortLabel();
  });
  if ($("#dellist")) $("#dellist").onclick = async () => {
    if (confirm(`Delete the list “${l.name}”?`)) {
      await api(`/list/${id}`, { method: "DELETE" }); delete CACHE["/lists"]; location.hash = "#/lists";
    }
  };
  if ($("#visseg")) $$(".vs-opt", view).forEach(b => b.onclick = async () => {
    const next = b.dataset.vis; if (next === vis) return;
    try {
      await api(`/list/${id}/visibility`, { body: { visibility: next } });
      delete CACHE["/lists"];
      toast(next === "collab" ? "Now collaborative" : next === "public" ? "Now public" : "Now private");
      routes.list(id);
    } catch {}
  });
  const renderAudPick = () => {
    const box = $("#audpick"); if (!box) return;
    audChips(box, l.shared_with, async ids => {
      await api(`/list/${id}/visibility`, { body: { visibility: vis, shared_with: ids } });
      l.shared_with = ids; delete CACHE["/lists"];
    });
  };
  if ($("#audsel")) {
    if (!$("#audpick").hidden) renderAudPick();
    $("#audsel").onchange = async e => {
      if (e.target.value === "all") {
        $("#audpick").hidden = true;
        await api(`/list/${id}/visibility`, { body: { visibility: vis, shared_with: [] } });
        l.shared_with = []; delete CACHE["/lists"];
        toast("Shared with everyone");
      } else { $("#audpick").hidden = false; renderAudPick(); }
    };
  }
  wireItems();
};

/* ---------- profile lists integration ----------
   Contract for the profile agent: window.renderProfileLists(username, isMe) -> Promise<htmlString>.
   Renders that user's lists (own → all; others → public only) as a self-contained section
   the profile page can drop into a #profile-lists slot. Cards are <a href> links, so no
   handler wiring is needed by the host. Returns "" when there's nothing to show. */
window.renderProfileLists = async (username, isMe) => {
  let data;
  try { data = await api(`/user/${encodeURIComponent(username)}/lists`); }
  catch { return ""; }
  const lists = data.lists || [];
  const label = isMe ? "My lists" : "Shared lists";
  if (!lists.length) {
    return isMe
      ? `<section class="prof-lists"><div class="section"><h2>${label}</h2><div class="rule"></div></div>
           <div class="empty">You haven't made any lists yet. <a class="tlink" href="#/lists">Create one</a></div></section>`
      : "";
  }
  return `<section class="prof-lists">
    <div class="section"><h2>${label}</h2><div class="rule"></div>
      <span class="cnt">${lists.length}</span></div>
    <div class="list-grid">${lists.map(listCard).join("")}</div></section>`;
};

/* ---------- movie detail ---------- */
routes.movie = async id => {
  const stop = deferSkeleton(`<div class="backdrop"><div class="hero">
    <div class="sk" style="width:136px;aspect-ratio:2/3"></div>
    <div style="flex:1"><div class="sk line-sk" style="max-width:240px;height:26px"></div></div></div></div>`);
  const m = await api(`/movie/${id}`);
  stop();
  const i = m.info || {};
  const chips = [
    i.content_rating && `<span class="chip">${esc(i.content_rating)}</span>`,
    i.vote ? `<span class="chip star">${I.star} ${i.vote}</span>` : "",
    i.runtime && `<span class="chip">${Math.floor(i.runtime / 60)}h ${i.runtime % 60}m</span>`,
    (i.genres || []).length && `<span class="chip">${esc(i.genres.slice(0, 2).join(" · "))}</span>`,
  ].filter(Boolean).join("");
  view.innerHTML = `
    <div class="backdrop">${i.backdrop ? `<div class="bg" style="background-image:url('${i.backdrop}')"></div>` : ""}
      <div class="hero">
        <img class="poster" src="${POSTER(m.poster)}" alt="">
        <div class="hbody"><h1>${esc(m.title)}</h1>
          ${i.tagline ? `<div class="tagline">${esc(i.tagline)}</div>` : ""}
          <div class="chips">${chips}</div>
          <div class="facts">${m.year || ""}${i.directors?.length ? ` · dir. ${esc(i.directors.join(", "))}` : ""}</div>
          <div class="actions">
            <div class="act-main">
              <button class="btn ${m.state === "watched" ? "" : "pri"}" id="mwatch">${I.check} ${m.state === "watched" ? "Watched" : "Mark watched"}</button>
              <span id="reqslot"></span>
            </div>
            <div class="act-row">
              <button class="chip-btn fav-chip" id="favchip" aria-pressed="false">${I.star}<span id="favchiplbl">Favorite</span></button>
              <button class="chip-btn" id="maddlist">${I.listadd}<span>List</span></button>
              <button class="chip-btn" id="mshare">${I.share}<span>Share</span></button>
              ${i.imdb_id ? `<a class="chip-btn imdb" href="https://www.imdb.com/title/${i.imdb_id}/" target="_blank" rel="noopener"><b>IMDb</b></a>` : ""}
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="dbody">
    ${i.overview ? `<p class="overview clamp" id="ov">${esc(i.overview)}</p>` : ""}
    <div id="watch-now"></div>
    ${i.cast?.length ? `<div class="section"><h2>Cast</h2><div class="rule"></div></div>${castStrip(i.cast)}` : ""}
    <div id="movie-reviews"></div>
    </div>`;
  if ($("#ov")) $("#ov").onclick = () => $("#ov").classList.toggle("clamp");
  $("#mwatch").onclick = async () => {
    const to = m.state === "watched" ? "none" : "watched";
    m.state = to === "watched" ? "watched" : null;
    const b = $("#mwatch");
    b.innerHTML = `${I.check} ${to === "watched" ? "Watched" : "Mark watched"}`;
    b.classList.toggle("pri", to !== "watched");
    if (to === "watched") sparks(b);
    delete CACHE["/movies"]; delete CACHE["/dashboard"];
    api(`/movie/${id}/state`, { body: { state: to } }).catch(() => {});
  };
  $("#maddlist").onclick = () => addToListMenu("movie", +id, m.title);
  $("#mshare").onclick = () => share(m.title, `movie/${id}`);
  wireFavChip("movie", +id);
  mountRequest($("#reqslot"), "movie", +id);
  watchNow("movie", +id, "watch-now");
  $("#movie-reviews").appendChild(await reviewsBlock("movie", +id, { watched: m.state === "watched" }));
};

/* ---------- person / actor ---------- */
routes.person = async id => {
  view.innerHTML = `<div class="perhero"><div class="sk" style="width:120px;height:120px;border-radius:50%"></div>
    <div style="flex:1"><div class="sk line-sk" style="max-width:220px;height:26px"></div></div></div>${skRows(2)}`;
  const p = await api(`/person/${id}`);
  const age = (b, d) => {
    if (!b) return "";
    const end = d ? new Date(d) : new Date();
    let a = end.getFullYear() - new Date(b).getFullYear();
    const m = end.getMonth() - new Date(b).getMonth();
    if (m < 0 || (m === 0 && end.getDate() < new Date(b).getDate())) a--;
    return a;
  };
  const meta = [
    p.known_for && `Known for ${esc(p.known_for)}`,
    p.birthday && `Born ${fmtDate(p.birthday)}${p.deathday ? "" : ` · ${age(p.birthday)}`}`,
    p.deathday && `Died ${fmtDate(p.deathday)} · ${age(p.birthday, p.deathday)}`,
    p.place && esc(p.place),
  ].filter(Boolean).join(" · ");
  view.innerHTML = `
    <div class="perhero reveal">
      <div class="per-face">${p.img ? `<img src="${p.img}" alt="">` : personGlyph()}</div>
      <div class="per-body"><h1>${esc(p.name)}</h1>
        <div class="per-meta">${meta}</div>
        <div class="actions">
          <button class="iconbtn lg" id="pshare" title="Share">${I.share}</button>
          ${p.imdb_id ? `<a class="btn" href="https://www.imdb.com/name/${p.imdb_id}/" target="_blank" rel="noopener">IMDb</a>` : ""}
        </div>
      </div>
    </div>
    ${p.bio ? `<p class="overview clamp" id="ov">${esc(p.bio)}</p>` : ""}
    <div class="section"><h2>Filmography</h2><div class="rule"></div><span class="cnt">${p.credits.length}</span></div>
    <div class="pgrid reveal">${p.credits.map(c => `
      <div class="pcard"><div class="pshot"><a href="#/${c.type}/${c.id}"><img class="poster" loading="lazy" src="${POSTER(c.poster)}" alt=""></a>
        <span class="badge">${c.type === "show" ? "TV" : "FILM"}</span>
        ${c.vote ? `<span class="votebadge">${I.star} ${c.vote}</span>` : ""}</div>
        <div class="t">${esc(c.title)}</div>
        <div class="y">${c.character ? esc(c.character) : (c.year || "")}</div></div>`).join("")}</div>`;
  if ($("#ov")) $("#ov").onclick = () => $("#ov").classList.toggle("clamp");
  $("#pshare").onclick = () => share(p.name, `person/${id}`);
};

/* ---------- profile hub ---------- */
/* ---------- profile hub (identity · favorites · stats · recap · other members) ---------- */
const STAR_O = `<svg viewBox="0 0 24 24" fill="none"><path d="M12 3.6l2.5 5.2 5.7.7-4.2 4 1.1 5.7L12 16.4l-5.1 2.8 1.1-5.7-4.2-4 5.7-.7z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`;
const PIN_ICON = `<svg viewBox="0 0 24 24" fill="none"><path d="M9 3h6l-1 6 3 3v2H7v-2l3-3-1-6z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M12 14v7" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>`;
const backIcon = `<svg viewBox="0 0 24 24" fill="none"><path d="M15 5.5 8 12l7 6.5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

let FAVSET = null;
async function ensureFavSet() {
  if (FAVSET) return FAVSET;
  try { FAVSET = new Set((await api("/favorites")).favorites.map(f => f.type + ":" + f.id)); }
  catch { FAVSET = new Set(); }
  return FAVSET;
}
function syncFavSet(favs) { FAVSET = new Set(favs.map(f => f.type + ":" + f.id)); }

const headPill = (v, l) => `<div class="hp"><div class="hp-v">${v}</div><div class="hp-l">${l}</div></div>`;
function headPills(h) {
  return `<div class="headrow">
    ${headPill((h.shows || 0).toLocaleString(), "shows")}
    ${headPill((h.episodes || 0).toLocaleString(), "episodes")}
    ${headPill((h.movies || 0).toLocaleString(), "movies")}
    ${headPill((h.hours || 0).toLocaleString(), "hours")}</div>`;
}

function favCardHTML(f, me) {
  return `<div class="favcard" data-fk="${f.type}:${f.id}"${me ? ' draggable="true"' : ""}>
    <a class="favcard-link" href="#/${f.type}/${f.id}" aria-label="${esc(f.title)}">
      <span class="favposter"><img loading="lazy" src="${POSTER(f.poster)}" alt=""></span>
      <span class="fav-t">${esc(f.title)}</span>
      <span class="fav-y">${f.year || ""}</span></a>
    ${me ? `<div class="fav-edit">
      <button class="fav-pin" title="Pin to front" aria-label="Pin to front">${PIN_ICON}</button>
      <button class="fav-x" title="Remove favorite" aria-label="Remove favorite">${I.x}</button></div>` : ""}
  </div>`;
}
function favStripHTML(favs, me) {
  if (!favs.length && !me)
    return `<div class="fav-empty">No favorites picked yet.</div>`;
  return favs.map(f => favCardHTML(f, me)).join("") +
    (me ? `<button class="favadd" id="favadd"><span class="favadd-plus">${I.plus}</span><span>Add favorite</span></button>` : "");
}

function wireFavorites(host, me) {
  if (!me) return;
  const strip = $("#favstrip", host);
  const repaint = favs => { syncFavSet(favs); strip.innerHTML = favStripHTML(favs, me); wireFavAdd(); };
  const wireFavAdd = () => { const a = $("#favadd", strip); if (a) a.onclick = () => favPicker(repaint); };
  wireFavAdd();
  strip.addEventListener("click", async e => {
    const card = e.target.closest(".favcard"); if (!card) return;
    const [t, id] = card.dataset.fk.split(":");
    if (e.target.closest(".fav-x")) {
      e.preventDefault();
      try { repaint((await api(`/favorites/${t}/${id}`, { method: "DELETE" })).favorites); } catch {}
    } else if (e.target.closest(".fav-pin")) {
      e.preventDefault();
      const order = [[t, id], ...[...strip.querySelectorAll(".favcard")]
        .filter(c => c !== card).map(c => c.dataset.fk.split(":"))];
      try { repaint((await api("/favorites/reorder", { body: { order } })).favorites); } catch {}
    }
  });
  /* drag-to-reorder (desktop) */
  let dragging = null;
  strip.addEventListener("dragstart", e => { dragging = e.target.closest(".favcard"); if (dragging) dragging.classList.add("drag"); });
  strip.addEventListener("dragend", async () => {
    if (!dragging) return;
    dragging.classList.remove("drag");
    const order = [...strip.querySelectorAll(".favcard")].map(c => c.dataset.fk.split(":"));
    dragging = null;
    try { syncFavSet((await api("/favorites/reorder", { body: { order } })).favorites); } catch {}
  });
  strip.addEventListener("dragover", e => {
    if (!dragging) return; e.preventDefault();
    const after = [...strip.querySelectorAll(".favcard:not(.drag)")].find(c => {
      const r = c.getBoundingClientRect(); return e.clientX < r.left + r.width / 2;
    });
    if (after) strip.insertBefore(dragging, after);
    else strip.insertBefore(dragging, $("#favadd", strip));
  });
}

function favPicker(onDone) {
  const s = sheet(`<div class="sh-t">Add a favorite</div>
    <div class="fav-search"><span class="fs-ic">${I.eye && ""}</span>
      <input id="fq" placeholder="Search shows & movies…" autocapitalize="none" autocomplete="off"></div>
    <div id="fres" class="fav-results"><div class="fav-hint">Type to search TMDB.</div></div>`, { cls: "favpicker" });
  const q = $("#fq", s.el), res = $("#fres", s.el);
  let t = null, last = "";
  q.oninput = () => {
    clearTimeout(t); const v = q.value.trim();
    if (v.length < 2) { res.innerHTML = `<div class="fav-hint">Keep typing…</div>`; return; }
    t = setTimeout(async () => {
      if (v === last) return; last = v;
      res.innerHTML = skRows(3);
      let data; try { data = await api("/search?q=" + encodeURIComponent(v)); } catch { return; }
      if ($("#fq", s.el)?.value.trim() !== v) return;
      const items = (data.results || []).filter(r => r.poster);
      res.innerHTML = items.length ? items.map(r => `
        <button class="fav-opt" data-t="${r.type}" data-id="${r.id}">
          <img loading="lazy" src="${POSTER(r.poster)}" alt="">
          <span class="fo-mid"><b>${esc(r.title)}</b><span class="fo-sub">${r.type === "show" ? "TV" : "Movie"}${r.year ? " · " + r.year : ""}</span></span>
          <span class="fo-add">${I.plus}</span></button>`).join("")
        : `<div class="fav-hint">No matches.</div>`;
    }, 260);
  };
  res.addEventListener("click", async e => {
    const opt = e.target.closest(".fav-opt"); if (!opt) return;
    opt.classList.add("busy");
    try {
      const r = await api("/favorites", { body: { item_type: opt.dataset.t, item_id: +opt.dataset.id } });
      toast("Added to favorites"); s.close();
      delete CACHE["/profile"]; onDone && onDone(r.favorites);
    } catch { opt.classList.remove("busy"); }
  });
  setTimeout(() => q.focus(), 80);
}

/* expose for future detail-page use (not wired into detail pages here — integration contract) */
window.favoriteBtn = (itemType, itemId, isFav) =>
  `<button class="favbtn ${isFav ? "on" : ""}" data-fav="${itemType}:${itemId}" aria-pressed="${!!isFav}"
     title="${isFav ? "In favorites" : "Add to favorites"}">${isFav ? I.star : STAR_O}</button>`;
window.toggleFavorite = async (itemType, itemId) => {
  const key = itemType + ":" + itemId, set = await ensureFavSet(), on = set.has(key);
  try {
    if (on) { await api(`/favorites/${itemType}/${itemId}`, { method: "DELETE" }); set.delete(key); toast("Removed from favorites"); }
    else { await api("/favorites", { body: { item_type: itemType, item_id: itemId } }); set.add(key); toast("Added to favorites"); }
  } catch { return; }
  delete CACHE["/profile"];
  $$(`[data-fav="${key}"]`).forEach(b => {
    const nowOn = set.has(key);
    b.classList.toggle("on", nowOn); b.setAttribute("aria-pressed", nowOn);
    b.innerHTML = nowOn ? I.star : STAR_O;
  });
  return set.has(key);
};

// well-integrated favorite chip for show / movie detail pages (id="favchip" in the action row)
async function wireFavChip(type, id) {
  const chip = $("#favchip"); if (!chip) return;
  const key = type + ":" + id;
  const paint = on => {
    chip.classList.toggle("on", on);
    chip.setAttribute("aria-pressed", on);
    const lbl = $("#favchiplbl"); if (lbl) lbl.textContent = on ? "Favorited" : "Favorite";
  };
  paint((await ensureFavSet()).has(key));
  chip.onclick = async () => { await toggleFavorite(type, id); paint((FAVSET || new Set()).has(key)); };
}

function recapTeaser(me, p) {
  const years = p.recap_years || [];
  const first = me ? "Your" : esc((p.username || "").split(" ")[0] || "Their") + "’s";
  if (years.length) {
    const y = years[0];
    const href = me ? `#/recap/${y}` : `#/u/${encodeURIComponent(p.username)}/recap/${y}`;
    return `<a class="recap-teaser reveal" href="${href}">
      <div class="rt-glow"></div>
      <div class="rt-body">
        <div class="rt-kicker">Year in Review</div>
        <div class="rt-title">${first} ${y}, wrapped</div>
        <div class="rt-sub">A slideshow of everything watched in ${y}</div>
      </div>
      <div class="rt-go">${I.chevR}</div></a>`;
  }
  if (me && p.recap_soon) {
    return `<div class="recap-teaser locked reveal">
      <div class="rt-glow"></div>
      <div class="rt-body">
        <div class="rt-kicker">Year in Review</div>
        <div class="rt-title">${p.recap_year || new Date().getFullYear()} is still being written</div>
        <div class="rt-sub">Your Wrapped slideshow unlocks in December ${I.lock}</div>
      </div>
      <div class="rt-go">${I.lock}</div></div>`;
  }
  return "";
}

async function loadMembers(host) {
  const slot = $("#members-strip", host); if (!slot) return;
  let data; try { data = await api("/members"); } catch { return; }
  const others = data.members;
  if (others.length <= 1) { slot.remove(); return; }
  slot.innerHTML = `<div class="section"><h2>Household</h2><div class="rule"></div>
      <span class="cnt">${others.length}</span></div>
    <div class="member-strip">${others.map(m => `
      <a class="member ${m.is_me ? "me" : ""}" href="#/${m.is_me ? "profile" : "u/" + encodeURIComponent(m.username)}">
        ${avatarHTML(m, "md")}<span class="mem-n">${esc(m.display_name)}${m.is_me ? " (you)" : ""}</span></a>`).join("")}</div>`;
}

async function loadProfileStats(statsPath, advPath, host) {
  const box = $("#prof-stats", host); if (!box) return;
  const c = cached(statsPath);
  const paint = d => { if ($("#prof-stats", host)) { box.innerHTML = statsSection(d); wireStats(box); } };
  if (c.stale) paint(c.stale);
  c.refresh(() => !!$("#prof-stats", host), paint);
  /* advanced stats stream in under the core numbers */
  try {
    const a = await api(advPath);
    const adv = $("#prof-adv", host);
    if (adv && a) { adv.innerHTML = advancedSection(a); wireStats(adv); }
  } catch { /* advanced is best-effort */ }
}

// Profile banner as a *true* progressive blur: several copies of the same image at
// stepped blur radii, each revealed by a feathered gradient mask so neighbouring
// blur levels crossfade into one continuous ramp — sharp at the top, dissolving
// (blur + dark) into the page by the bottom. A uniform filter:blur() can't do this.
function bannerLayers(url) {
  if (!url) return "";
  const u = `url('${esc(url)}')`;
  return `<div class="pb-stack" style="--img:${u}">
    <div class="pb-l pb-l0"></div><div class="pb-l pb-l1"></div><div class="pb-l pb-l2"></div>
    <div class="pb-l pb-l3"></div><div class="pb-l pb-l4"></div><div class="pb-tint"></div></div>`;
}

routes.profile = async (username) => {
  const me = !username || username.toLowerCase() === (ME.username || "").toLowerCase();
  const ppath = me ? "/profile" : "/profile/" + encodeURIComponent(username);
  const c = cached(ppath);
  const render = p => {
    syncFavSet(p.favorites || []);
    const statsPath = me ? "/stats" : `/profile/${encodeURIComponent(username)}/stats`;
    const advPath = me ? "/stats/advanced" : `/profile/${encodeURIComponent(username)}/stats/advanced`;
    view.innerHTML = `
      ${me ? "" : `<div class="page-head"><a class="crumb" href="#/profile">${backIcon} Your profile</a></div>`}
      <div class="prof-hero reveal${p.banner ? " has-banner" : ""}">
        <div class="prof-banner" id="banner">${bannerLayers(p.banner)}</div>
        ${me ? `<a class="prof-gear" href="#/settings" title="Settings & Plex" aria-label="Settings">${gearIcon()}</a>
        <button class="banner-edit" id="banneredit" title="Change banner" aria-label="Change banner">${I.image}</button>` : ""}
        <div class="prof-av" id="avwrap">${avatarHTML(p, "xl")}
          ${me ? `<button class="av-edit" id="avedit" title="Change photo">${I.camera}</button>
          <input type="file" id="avfile" accept="image/png,image/jpeg,image/webp" hidden>` : ""}</div>
        <div class="prof-name">${esc(p.display_name)}</div>
        <div class="prof-sub">@${esc(p.username)}${p.is_admin ? " · admin" : ""}${p.member_since ? ` · since ${fmtDate(p.member_since.slice(0, 10))}` : ""}</div>
        ${headPills(p.headline || {})}
        ${me ? `<button class="btn" id="editprof">${I.edit} Edit profile</button>` : ""}
      </div>

      <div class="section reveal"><h2>Favorites</h2><div class="rule"></div></div>
      <div class="fav-shelf reveal"><div class="fav-strip" id="favstrip">${favStripHTML(p.favorites || [], me)}</div></div>

      ${recapTeaser(me, p)}

      <div id="profile-lists"></div>

      ${me ? `<div class="hublinks reveal">
        <a class="hublink" href="#/lists">${I.bookmark}<span>My Lists</span>${I.chevR}</a>
        <a class="hublink" href="#/history">${I.ticket}<span>History</span>${I.chevR}</a>
      </div>` : ""}

      <div id="members-strip"></div>

      <div class="section reveal"><h2>${me ? "Your numbers" : esc(p.display_name.split(" ")[0]) + "’s numbers"}</h2><div class="rule"></div></div>
      <div id="prof-stats">${statsSkeleton()}</div>
      <div id="prof-adv"></div>

      ${me ? `<button class="btn signout" id="signout">Sign out</button>` : ""}`;

    if (me) {
      $("#avedit").onclick = () => $("#avfile").click();
      $("#avfile").onchange = async () => {
        const f = $("#avfile").files[0]; if (!f) return;
        $("#avfile").value = "";
        const blob = await cropImage(f);
        if (!blob) return;
        const fd = new FormData(); fd.append("file", new File([blob], "avatar.jpg", { type: "image/jpeg" }));
        const r = await api("/profile/avatar", { method: "POST", body: fd });
        ME.avatar = r.avatar; p.avatar = r.avatar; delete CACHE["/profile"];
        $("#avwrap").querySelector(".avatar").outerHTML = avatarHTML({ ...p, avatar: r.avatar }, "xl");
        paintAvatars(); toast("Photo updated");
      };
      $("#editprof").onclick = () => editProfile(p);
      $("#banneredit").onclick = () => bannerSheet(p, url => {
        p.banner = url; delete CACHE[ppath];
        const bn = $("#banner");
        if (bn) bn.innerHTML = bannerLayers(url);
        $(".prof-hero")?.classList.toggle("has-banner", !!url);
      });
      $("#signout").onclick = async () => { await api("/logout", { body: {} }); ME = null; routes.login(); };
    }
    wireFavorites(view, me);
    loadMembers(view);
    loadProfileStats(statsPath, advPath, view);
    if (window.renderProfileLists) {
      window.renderProfileLists(p.username, me)
        .then(html => { const s = $("#profile-lists"); if (s) s.innerHTML = html; })
        .catch(() => { /* lists feature unavailable — leave the slot empty */ });
    }
  };

  if (c.stale) render(c.stale);
  else view.innerHTML = `<div class="prof-hero"><div class="sk" style="width:104px;height:104px;border-radius:50%;margin:12px auto"></div></div>${statsSkeleton()}`;
  c.refresh(() => { const s = seg(); return s[0] === "profile" || s[0] === "u"; }, render);
};

function editProfile(p) {
  const s = sheet(`<div class="sh-t">Edit profile</div>
    <label>Display name</label><input id="dn" value="${esc(p.display_name)}" maxlength="40">
    <label>Username</label><input id="un" value="${esc(p.username)}" autocapitalize="none">
    <label>New password <span class="hint">(leave blank to keep current)</span></label>
    <input id="pw" type="password" placeholder="••••••••" autocomplete="new-password">
    <button class="btn pri" data-v="save">Save changes</button>
    <button class="btn ghost" data-v="cancel">Cancel</button>`, { cls: "editor" });
  s.el.addEventListener("click", async e => {
    if (e.target.closest('[data-v="cancel"]')) return s.close();
    if (e.target.closest('[data-v="save"]')) {
      const body = { display_name: $("#dn", s.el).value, username: $("#un", s.el).value };
      if ($("#pw", s.el).value) body.password = $("#pw", s.el).value;
      try {
        await api("/profile", { body });
        ME.display_name = body.display_name || body.username;
        ME.username = body.username;
        delete CACHE["/profile"];
        s.close(); toast("Profile saved"); routes.profile();
      } catch {}
    }
  });
}
// Banner picker — upload your own, or riffle a Rolodex-style deck of curated
// widescreen stills from shows you watch. Drag/flick the top card to flip through
// on mobile; the deck fans open on hover on desktop. onSet(urlOrNull) applies.
async function bannerSheet(p, onSet) {
  const s = sheet(`<div class="sh-t">Profile banner</div>
    <div class="bn-actions">
      <button class="btn" id="bnupload">${I.camera} Upload your own</button>
      ${p.banner ? `<button class="btn ghost" id="bnclear">Remove banner</button>` : ""}
    </div>
    <input type="file" id="bnfile" accept="image/png,image/jpeg,image/webp" hidden>
    <div class="bn-cap">From shows you watch <span class="bn-hint">hold &amp; slide · tap to use</span></div>
    <div class="stack" id="stack"><div class="bn-load">Loading suggestions…</div></div>
    <button class="btn pri deck-use" id="duse" hidden>Use this banner</button>`,
    { cls: "editor bannersheet" });

  const stack = $("#stack", s.el);
  let opts = [], cards = [], active = null;

  const pick = async o => {
    try { await api("/profile/banner", { body: { url: o.backdrop } }); onSet(o.backdrop); s.close(); }
    catch { toast("Couldn't set banner"); }
  };
  const setActive = c => {
    if (c === active) return;
    active?.classList.remove("active");
    active = c; c.classList.add("active");
    const use = $("#duse", s.el); if (use) use.textContent = `Use ${c.dataset.title}`;
  };

  // Size the stack so N cards fill the fixed height exactly — no scroll. --ah is the
  // open card, --ch the shingled strips; N is capped so strips stay tappable/readable.
  const OV = 12;
  const sizeStack = render => {
    const H = Math.max(200, (stack.clientHeight || Math.round(innerHeight * 0.5)) - 20);  // 18px pad + 2px slack
    const ah = Math.max(128, Math.min(220, Math.round(H * 0.42)));
    if (render) {
      const maxN = Math.max(4, Math.floor((H - ah) / 26) + 1);
      opts = opts.slice(0, Math.min(opts.length, maxN, 16));
    }
    const n = opts.length;
    const ch = n > 1 ? OV + (H - ah) / (n - 1) : ah;
    stack.style.setProperty("--ov", OV + "px");
    stack.style.setProperty("--ah", ah + "px");
    stack.style.setProperty("--ch", ch.toFixed(1) + "px");
  };

  api("/profile/banner/options").then(({ options }) => {
    if (!stack.isConnected) return;
    opts = options;
    if (!opts.length) { stack.innerHTML = `<div class="bn-empty">Watch a few shows and their artwork shows up here.</div>`; return; }
    $("#duse", s.el).hidden = false;                            // unhide first so it's in the layout we measure
    requestAnimationFrame(() => {
      if (!stack.isConnected) return;
      sizeStack(true);                                          // decides how many fit + sets sizes
      stack.innerHTML = opts.map((o, i) => `<button class="stack-card" data-i="${i}" data-title="${esc(o.title)}">
        <img loading="lazy" src="${esc(o.backdrop)}" alt="" draggable="false"><span class="sc-bar"><span class="sc-t">${esc(o.title)}</span></span></button>`).join("");
      cards = $$(".stack-card", stack);
      if (matchMedia("(hover:hover)").matches)                  // desktop: hover pops a card open
        cards.forEach(c => c.addEventListener("pointerenter", () => setActive(c)));
      setActive(cards[0]);
    });

    // Press-and-drag scrub: the card under your finger opens as you slide up/down,
    // buzzing on every change, until you lift. A tap on the already-open card selects it.
    let scrub = null;
    const cardAt = (x, y) => document.elementFromPoint(x, y)?.closest?.(".stack-card");
    stack.addEventListener("pointerdown", e => {
      const c = cardAt(e.clientX, e.clientY) || active; if (!c) return;
      scrub = { y: e.clientY, i: cards.indexOf(c), moved: false, wasActive: c === active };
      setActive(c);
      try { stack.setPointerCapture(e.pointerId); } catch { /* synthetic */ }
    });
    stack.addEventListener("pointermove", e => {
      if (!scrub) return;
      const dy = e.clientY - scrub.y;
      if (Math.abs(dy) < 30) return;                            // one card per ~30px of travel
      const ni = Math.max(0, Math.min(cards.length - 1, scrub.i + (dy > 0 ? 1 : -1)));
      scrub.y = e.clientY;
      if (ni === scrub.i) return;
      scrub.i = ni; scrub.moved = true;
      setActive(cards[ni]);
      hapticTick();
    });
    const endScrub = () => {
      if (!scrub) return;
      const sc = scrub; scrub = null;
      if (!sc.moved && sc.wasActive) pick(opts[sc.i]);          // tapped the open card = choose it
    };
    stack.addEventListener("pointerup", endScrub);
    stack.addEventListener("pointercancel", endScrub);

    const use = $("#duse", s.el);
    use.onclick = () => { if (active) pick(opts[+active.dataset.i]); };
    const onResize = () => {                                     // keep it fitting on rotate/resize
      if (!stack.isConnected) return removeEventListener("resize", onResize);
      if (cards.length) sizeStack(false);
    };
    addEventListener("resize", onResize);
  }).catch(() => { if (stack.isConnected) stack.innerHTML = `<div class="bn-empty">Couldn't load suggestions.</div>`; });

  $("#bnupload", s.el).onclick = () => $("#bnfile", s.el).click();
  $("#bnfile", s.el).onchange = async () => {
    const f = $("#bnfile", s.el).files[0]; if (!f) return;
    try {
      const fd = new FormData(); fd.append("file", f);
      const r = await api("/profile/banner/upload", { method: "POST", body: fd });
      onSet(r.banner); s.close(); toast("Banner updated");
    } catch (e) { toast(e.message || "Upload failed"); }
  };
  if ($("#bnclear", s.el)) $("#bnclear", s.el).onclick = async () => {
    try { await api("/profile/banner", { body: { clear: true } }); onSet(null); s.close(); } catch {}
  };
}

const statsIcon = () => `<svg class="ico" viewBox="0 0 24 24"><path d="M5 20V11M12 20V4.5M19 20v-6.5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>`;
const gearIcon = () => `<svg class="ico" viewBox="0 0 24 24"><path d="M12 8.6a3.4 3.4 0 1 0 0 6.8 3.4 3.4 0 0 0 0-6.8Zm8.6 3.4c0 .6-.05 1.1-.15 1.65l2 1.55-2 3.45-2.35-.95c-.85.7-1.5 1.1-2.5 1.45L15.2 21.7H8.8l-.4-2.55c-1-.35-1.65-.75-2.5-1.45l-2.35.95-2-3.45 2-1.55A9.2 9.2 0 0 1 3.4 12c0-.6.05-1.1.15-1.65l-2-1.55 2-3.45 2.35.95c.85-.7 1.5-1.1 2.5-1.45L8.8 2.3h6.4l.4 2.55c1 .35 1.65.75 2.5 1.45l2.35-.95 2 3.45-2 1.55c.1.55.15 1.05.15 1.65Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>`;

/* ---------- notifications ---------- */
const NOTIF_ICON = { reply: I.reply, comment: I.edit, airing: I.bell, available: I.check, new_season: I.star, plex: I.eye };
async function refreshBell() {
  const el = $("#topbell"); if (!el) return;
  let n = 0;
  try { n = (await api("/notifications")).unread || 0; } catch { /* ignore */ }
  el.innerHTML = `${I.bell}${n ? `<span class="ndot">${n > 9 ? "9+" : n}</span>` : ""}`;
}
routes.inbox = async () => {
  view.innerHTML = `<div class="page-head"><a class="crumb" href="#/">${I.chevS} Home</a></div>
    <div class="section"><h2>Notifications</h2><div class="rule"></div><span class="cnt" id="ncnt"></span></div>
    <div id="nlist">${skRows(3)}</div>`;
  let data;
  try { data = await api("/notifications"); } catch { return; }
  const host = $("#nlist"); if (!host) return;
  $("#ncnt").textContent = data.items.length || "";
  if (!data.items.length)
    host.innerHTML = `<div class="empty" style="padding:26px">Nothing yet. When someone replies to your reviews, or a followed show has news, it'll land here.<br><a href="#/settings" style="color:var(--amber)">Choose what you get notified about →</a></div>`;
  else
    host.innerHTML = data.items.map(n => `
      <a class="notif ${n.read ? "" : "unread"}" href="#/${n.link || ""}">
        <span class="n-ico">${NOTIF_ICON[n.type] || I.bell}</span>
        <span class="n-main"><b>${esc(n.title)}</b>${n.body ? `<span class="n-sub">${esc(n.body)}</span>` : ""}
          <span class="n-time">${fmtDate(n.created_at.slice(0, 10))}</span></span></a>`).join("");
  if (data.unread) api("/notifications/read", { body: {} }).then(refreshBell).catch(() => {});
};

/* ---------- web push (real OS notifications for the installed PWA) ---------- */
const pushSupported = () => "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
function urlB64ToUint8(b64) {
  const pad = "=".repeat((4 - (b64.length % 4)) % 4);
  const raw = atob((b64 + pad).replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}
async function currentPushSub() {
  if (!pushSupported()) return null;
  try { return await (await navigator.serviceWorker.ready).pushManager.getSubscription(); } catch { return null; }
}
async function enablePush() {
  const perm = await Notification.requestPermission();
  if (perm !== "granted") { toast("Notifications are blocked — allow them in your device settings"); return false; }
  const { enabled, key } = await api("/push/pubkey");
  if (!enabled || !key) { toast("Push isn't set up on the server"); return false; }
  const reg = await navigator.serviceWorker.ready;
  const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: urlB64ToUint8(key) });
  await api("/push/subscribe", { body: sub.toJSON() });
  return true;
}
async function disablePush() {
  const sub = await currentPushSub();
  if (!sub) return;
  await api("/push/unsubscribe", { body: { endpoint: sub.endpoint } }).catch(() => {});
  await sub.unsubscribe().catch(() => {});
}
async function wirePush() {
  const hint = $("#pushhint"), toggle = $("#pushtoggle"), test = $("#pushtest");
  if (!hint) return;
  if (!pushSupported()) { hint.textContent = "This browser can't send push notifications. On iOS, add Marquee to your Home Screen first."; return; }
  const cfg = await api("/push/pubkey").catch(() => ({ enabled: false }));
  if (!cfg.enabled) { hint.textContent = "Push isn't available on the server right now."; return; }
  let on = !!(await currentPushSub());
  const paint = () => {
    toggle.hidden = false; toggle.classList.toggle("on", on); toggle.setAttribute("aria-checked", on);
    hint.textContent = on ? "On — you'll get alerts on this device even when Marquee is closed."
                          : "Off — turn on to get alerts on this device even when the app is closed.";
    test.hidden = !on;
  };
  paint();
  toggle.onclick = async () => {
    toggle.style.opacity = ".5";
    try {
      if (!on) { if (await enablePush()) { on = true; toast("Notifications on for this device"); } }
      else { await disablePush(); on = false; toast("Turned off for this device"); }
    } catch { toast("Couldn't change that — try again"); }
    toggle.style.opacity = ""; paint();
  };
  test.onclick = async () => {
    const r = await api("/push/test", { body: {} }).catch(() => ({ ok: false }));
    toast(r.ok ? "Test sent — check your notifications" : "Turn on push for this device first");
  };
}

function paintAvatars() {
  const ta = $("#tabavatar .ta-ico");
  if (ta) ta.outerHTML = `<span class="ta-ico">${avatarHTML(ME).replace('class="avatar', 'class="avatar tiny')}</span>`;
  const top = $("#topavatar");
  if (top) top.innerHTML = avatarHTML(ME).replace('class="avatar', 'class="avatar tiny');
}

/* ---------- discover / search ---------- */
function posterTile(r) {
  return `<div class="pcard" data-id="${r.id}" data-type="${r.type}">
    <div class="pshot">
      <a href="#/${r.type}/${r.id}"><img class="poster" loading="lazy" src="${POSTER(r.poster)}" alt=""></a>
      <span class="badge">${r.type === "show" ? "TV" : "FILM"}</span>
      ${r.vote ? `<span class="votebadge">${I.star} ${r.vote}</span>` : ""}
      <div class="act">
        ${r.type === "show"
          ? (r.followed ? `<div class="have">${I.check}</div>` : `<button title="Follow" data-a="follow">${I.plus}</button>`)
          : (r.state ? `<div class="have">${I.check}</div>` : `<button title="Add to watchlist" data-a="watchlist">${I.plus}</button>
             <button title="Mark watched" data-a="watched">${I.check}</button>`)}
      </div>
    </div>
    <div class="t">${esc(r.title)}</div>
    <div class="y">${r.year || ""}${r.followed ? " · following" : r.state ? " · " + r.state : ""}</div>
  </div>`;
}
function wireTiles(root, after) {
  $$(".act button", root).forEach(b => b.onclick = async e => {
    e.preventDefault();
    const c = b.closest(".pcard");
    const isShow = c.dataset.type === "show";
    const watched = b.dataset.a === "watched";
    b.disabled = true; sparks(b);
    try {
      await api("/add", { body: { type: isShow ? "show" : "movie", id: +c.dataset.id,
        state: watched ? "watched" : "watchlist" } });
    } catch { b.disabled = false; return; }
    delete CACHE["/dashboard"]; delete CACHE["/movies"]; delete CACHE["/discover"]; delete CACHE["/lists"];
    // optimistic confirmation on the tile itself — no stale re-render
    const act = $(".act", c), y = $(".y", c);
    if (act) act.innerHTML = `<div class="have" title="${isShow ? "Following" : watched ? "Watched" : "On your watchlist"}">${I.check}</div>`;
    if (y) y.innerHTML = (y.textContent.split(" · ")[0]) + (isShow ? " · following" : watched ? " · watched" : " · watchlist");
    toast(isShow ? "Added to your shows — it’s in Watch Next" : watched ? "Marked watched" : "Added to watchlist");
  });
}

function renderDiscover(d) {
  const box = $("#res");
  box.innerHTML = d.sections.map(sec => `
    <div class="drow">
      <div class="drow-h">${esc(sec.title)}</div>
      <div class="rail">${sec.items.map(posterTile).join("")}</div>
    </div>`).join("") || `<div class="empty">Nothing to suggest yet — follow a few shows first.</div>`;
  wireTiles(box, () => routes.search());
}

routes.search = () => {
  view.innerHTML = `<h1>Discover</h1>
    <div class="searchbar"><span class="s-ico"><svg viewBox="0 0 24 24"><circle cx="10.6" cy="10.6" r="6.1" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="m15.4 15.4 5.2 5.2" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/></svg></span>
      <input id="q" placeholder="Search shows & movies…" autocomplete="off"></div>
    <div id="res"></div>`;
  const q = $("#q");
  const box = $("#res");
  let t;

  const showDiscover = () => {
    const c = cached("/discover");
    if (c.stale) renderDiscover(c.stale);
    else box.innerHTML = Array.from({ length: 3 }, () => `<div class="drow">
      <div class="sk line-sk" style="width:200px;margin-bottom:10px"></div>
      <div class="rail">${Array.from({ length: 6 }, () => `<div class="sk pcard-sk" style="width:120px;flex:none"></div>`).join("")}</div></div>`).join("");
    c.refresh(() => seg()[0] === "search" && !q.value.trim(), renderDiscover);
  };
  const runSearch = async () => {
    box.innerHTML = `<div class="pgrid">${Array.from({ length: 12 }, () => `<div class="sk pcard-sk"></div>`).join("")}</div>`;
    const d = await api(`/search?q=${encodeURIComponent(q.value.trim())}`);
    box.innerHTML = d.results.length
      ? `<div class="pgrid reveal">${d.results.map(posterTile).join("")}</div>`
      : `<div class="empty">No matches for “${esc(q.value.trim())}”.</div>`;
    wireTiles(box, runSearch);
  };
  q.oninput = () => {
    clearTimeout(t);
    if (q.value.trim().length < 2) { showDiscover(); return; }
    t = setTimeout(runSearch, 320);
  };
  showDiscover();
};

/* ---------- history ---------- */
function epRuns(eps) {
  /* [[s,n,title?],...] -> "S2 E4–9 · S3 E1" */
  const bySeason = {};
  eps.forEach(([s, n]) => (bySeason[s] = bySeason[s] || []).push(n));
  return Object.entries(bySeason).map(([s, nums]) => {
    nums.sort((a, b) => a - b);
    const runs = [];
    let a = nums[0], b = nums[0];
    for (let i = 1; i <= nums.length; i++) {
      if (nums[i] === b + 1) b = nums[i];
      else { runs.push(a === b ? `E${a}` : `E${a}–${b}`); a = b = nums[i]; }
    }
    return `S${s} ${runs.join(", ")}`;
  }).join(" · ");
}
function epLine(eps) {
  /* range + episode name(s): single -> "S1 E5 · Title", run -> "S1 E5–9 · First → Last" */
  const sorted = [...eps].sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  const range = epRuns(eps);
  const first = sorted[0][2], last = sorted[sorted.length - 1][2];
  if (sorted.length === 1) return first ? `${range} · ${esc(first)}` : range;
  if (first && last) return `${range} · ${esc(first)} → ${esc(last)}`;
  return range;
}
const dayLabel = d0 => {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const diff = Math.round((today - new Date(d0 + "T00:00")) / 864e5);
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  return new Date(d0 + "T00:00").toLocaleDateString(undefined,
    { weekday: "short", month: "short", day: "numeric" });
};
const monthLabel = d0 => new Date(d0 + "T00:00").toLocaleDateString(undefined,
  { month: "long", year: "numeric" });

function historyChunkHTML(items, type, state) {
  let html = "";
  for (const it of items) {
    const day = type === "movie" ? it.watched_at.slice(0, 10) : it.day;
    const mon = day.slice(0, 7);
    if (mon !== state.mon) {
      state.mon = mon;
      html += `<div class="month-div"><span>${monthLabel(day)}</span></div>`;
    }
    if (day !== state.day) {
      state.day = day;
      html += `<div class="h-day">${dayLabel(day)}</div>`;
    }
    if (type === "movie") {
      html += `<a class="h-row" href="#/movies">
        <img loading="lazy" src="${POSTER(it.poster)}" alt="">
        <div class="mid"><div class="t">${esc(it.title)}</div>
          <div class="s">${it.year || ""}${it.runtime ? ` · ${Math.round(it.runtime / 60 * 10) / 10} hrs` : ""}</div></div>
        ${it.rating ? `<span class="h-rate">${it.rating}<small>/10</small></span>` : ""}</a>`;
    } else {
      const n = it.eps.length;
      html += `<a class="h-row" data-k="${it.day}:${it.show_id}" href="#/show/${it.show_id}">
        <img loading="lazy" src="${POSTER(it.poster)}" alt="">
        <div class="mid"><div class="t">${esc(it.title)}</div>
          <div class="s">${epLine(it.eps)}</div></div>
        <div class="h-meta">${n} ep${n > 1 ? "s" : ""}<small>${(it.minutes / 60).toFixed(1)} hrs</small></div></a>`;
    }
  }
  return html;
}

routes.history = (tab = "tv") => {
  view.innerHTML = `<h1>History</h1>
    <div class="tabs">
      <button data-t="tv" class="${tab === "tv" ? "on" : ""}">Shows</button>
      <button data-t="movie" class="${tab === "movie" ? "on" : ""}">Movies</button>
    </div>
    <div id="hlist" class="hlist">${skRows(8)}</div>
    <div id="hmore"></div>`;
  $$(".tabs button", view).forEach(b => b.onclick = () => routes.history(b.dataset.t));
  const state = { mon: null, day: null, cursor: "", done: false, loading: false, first: true };
  const seen = new Map();   // day:show -> element (merge split groups across pages)
  async function loadMore() {
    if (state.done || state.loading) return;
    state.loading = true;
    const d = await api(`/history?type=${tab}${state.cursor ? "&cursor=" + encodeURIComponent(state.cursor) : ""}`);
    let items = d.items;
    if (tab === "tv") {
      items = items.filter(it => {
        const k = it.day + ":" + it.show_id;
        if (seen.has(k)) {   // merge continuation of a split giant day
          const prev = seen.get(k);
          prev.eps = prev.eps.concat(it.eps);
          prev.minutes += it.minutes;
          const el = $(`#hlist [data-k="${CSS.escape(k)}"]`);
          if (el) { $(".s", el).innerHTML = epLine(prev.eps);
            $(".h-meta", el).innerHTML = `${prev.eps.length} eps<small>${(prev.minutes / 60).toFixed(1)} hrs</small>`; }
          return false;
        }
        seen.set(k, it);
        return true;
      });
    }
    if (state.first) { $("#hlist").innerHTML = ""; state.first = false; }
    $("#hlist").insertAdjacentHTML("beforeend", historyChunkHTML(items, tab, state));
    state.cursor = d.cursor;
    state.done = !d.cursor;
    state.loading = false;
    $("#hmore").innerHTML = state.done
      ? (seen.size || tab === "movie" ? `<div class="empty">That's everything.</div>` : `<div class="empty">Nothing here yet.</div>`)
      : "";
  }
  loadMore();
  const sentinel = new IntersectionObserver(es => {
    if (es.some(e => e.isIntersecting)) loadMore();
  }, { rootMargin: "600px" });
  sentinel.observe($("#hmore"));
};

/* ---------- stats ---------- */
/* ---------- data viz primitives (axis · grid · area fill · interactive hover) ---------- */
// Shared floating tooltip. Labels can be untrusted (show titles, genre names from
// TMDB) so every string goes in via textContent, never innerHTML concatenation.
let _vtip;
function vtipEl() {
  if (!_vtip) { _vtip = document.createElement("div"); _vtip.className = "viztip"; _vtip.hidden = true; document.body.appendChild(_vtip); }
  return _vtip;
}
function vtipShow(x, y, title, rows) {
  const t = vtipEl(); t.textContent = "";
  const h = document.createElement("div"); h.className = "vt-h"; h.textContent = title; t.appendChild(h);
  (rows || []).forEach(r => {
    const row = document.createElement("div"); row.className = "vt-r";
    if (r.color) { const k = document.createElement("span"); k.className = "vt-k"; k.style.background = r.color; row.appendChild(k); }
    const l = document.createElement("span"); l.className = "vt-l"; l.textContent = r.label; row.appendChild(l);
    const v = document.createElement("span"); v.className = "vt-v"; v.textContent = r.value; row.appendChild(v);
    t.appendChild(row);
  });
  t.hidden = false;
  const w = t.offsetWidth, hh = t.offsetHeight, pad = 8;
  let px = x + 14, py = y - hh - 14;
  if (px + w + pad > innerWidth) px = x - w - 14;
  px = Math.max(pad, Math.min(px, innerWidth - w - pad));
  if (py < pad) py = y + 20;
  t.style.left = px + "px"; t.style.top = py + "px";
}
function vtipHide() { if (_vtip) _vtip.hidden = true; }

// Light haptic tick. iOS Safari exposes no navigator.vibrate; a programmatic click
// on a <label> bound to a hidden <input switch> fires the system haptic (iOS 17.4+).
let _hapticLabel;
function hapticTick() {
  if (navigator.vibrate) { try { navigator.vibrate(8); } catch { /* denied */ } return; }  // Android / desktop
  // iOS Safari has no Vibration API. The only known trigger: toggle a hidden
  // <input type="checkbox" switch> via a *rendered* <label>. Key detail — hide the
  // INPUT (display:none), never the label, or no haptic fires. Works iOS 17.4–26.4
  // only (Apple patched it in 26.5). Must be clicked inside a user gesture.
  if (!_hapticLabel) {
    const label = document.createElement("label");
    label.setAttribute("aria-hidden", "true");
    label.style.cssText = "position:fixed;bottom:0;left:0;pointer-events:none";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.setAttribute("switch", "");
    input.setAttribute("style", "display:none!important");
    label.appendChild(input);
    document.body.appendChild(label);
    _hapticLabel = label;
  }
  _hapticLabel.click();
}

let _chartSeq = 0;
const niceStep = x => {
  const e = Math.floor(Math.log10(x || 1)), f = (x || 1) / Math.pow(10, e);
  return (f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10) * Math.pow(10, e);
};
function niceTicks(max, count = 3) {
  const step = niceStep(max / count), out = [];
  for (let t = step; t <= max + step * 0.01; t += step) out.push(Math.round(t));
  return out.length ? out : [max];
}
/* Interactive area/line chart: gridlines, gradient fill, amber line, and a
   crosshair + tooltip that snaps to the nearest point on hover/drag (wired by
   wireLineChart after mount). labelFmt/valFmt shape the tooltip readout. */
function lineChart(labels, vals, { yearMarks = false, series = "watches", labelFmt = null, valFmt = null } = {}) {
  const n = vals.length || 1;
  const max = Math.max(...vals, 1);
  const W = 720, H = 224, padL = 36, padR = 16, padT = 18, padB = 32;
  const iw = W - padL - padR, ih = H - padT - padB;
  const X = i => padL + (n <= 1 ? iw / 2 : iw * i / (n - 1));
  const Y = v => padT + ih * (1 - v / max);
  const ticks = niceTicks(max, 3);
  const grid = [0, ...ticks].map(t => `<line class="grid-l" x1="${padL}" x2="${W - padR}" y1="${Y(t).toFixed(1)}" y2="${Y(t).toFixed(1)}"/>`
    + (t ? `<text class="axis" x="${padL - 8}" y="${(Y(t) + 3.4).toFixed(1)}" text-anchor="end">${t}</text>` : "")).join("");
  const line = vals.map((v, i) => `${i ? "L" : "M"}${X(i).toFixed(1)} ${Y(v).toFixed(1)}`).join(" ");
  const area = `M${X(0).toFixed(1)} ${Y(0).toFixed(1)} `
    + vals.map((v, i) => `L${X(i).toFixed(1)} ${Y(v).toFixed(1)}`).join(" ")
    + ` L${X(n - 1).toFixed(1)} ${Y(0).toFixed(1)} Z`;
  const lbls = labels.map((m, i) => {
    const show = yearMarks ? String(m).endsWith("-01") : (n <= 12 || i % Math.ceil(n / 12) === 0 || i === n - 1);
    return show ? `<text class="axis" x="${X(i).toFixed(1)}" y="${H - 10}" text-anchor="middle">${yearMarks ? String(m).slice(0, 4) : m}</text>` : "";
  }).join("");
  const e = n - 1, gid = "ag" + (++_chartSeq);
  const peakI = vals.indexOf(max);
  // peak marker (bright dot at the all-time high) — the one point worth calling out
  const peak = `<circle class="pt-peak" cx="${X(peakI).toFixed(1)}" cy="${Y(max).toFixed(1)}" r="3.2"/>`;
  const pts = JSON.stringify(vals.map((v, i) => ({
    x: +X(i).toFixed(1), y: +Y(v).toFixed(1),
    label: labelFmt ? labelFmt(labels[i]) : String(labels[i]),
    disp: valFmt ? valFmt(v) : String(v),
  })));
  return `<svg class="linechart" viewBox="0 0 ${W} ${H}" data-pts='${esc(pts)}' data-series="${esc(series)}"><defs>
    <linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="var(--amber)" stop-opacity=".34"/>
      <stop offset="1" stop-color="var(--amber)" stop-opacity="0"/></linearGradient></defs>
    ${grid}<path class="area" d="${area}" fill="url(#${gid})"/>
    <path class="aline" d="${line}"/>${peak}${lbls}
    <line class="xhair" x1="0" x2="0" y1="${padT}" y2="${padT + ih}" style="display:none"/>
    <circle class="xdot" r="4.4" style="display:none"/></svg>`;
}
function wireLineChart(svg) {
  let pts; try { pts = JSON.parse(svg.dataset.pts); } catch { return; }
  if (!pts.length) return;
  const xhair = svg.querySelector(".xhair"), dot = svg.querySelector(".xdot");
  const series = svg.dataset.series || "";
  let lastX = null;
  const move = ev => {
    const rect = svg.getBoundingClientRect();
    const vx = (ev.clientX - rect.left) / rect.width * 720;
    let best = pts[0];
    for (const p of pts) if (Math.abs(p.x - vx) < Math.abs(best.x - vx)) best = p;
    if (best.x !== lastX) {
      if (lastX !== null && ev.pointerType !== "mouse") hapticTick();  // buzz when the drag snaps to a new point
      lastX = best.x;
    }
    xhair.setAttribute("x1", best.x); xhair.setAttribute("x2", best.x); xhair.style.display = "";
    dot.setAttribute("cx", best.x); dot.setAttribute("cy", best.y); dot.style.display = "";
    vtipShow(ev.clientX, ev.clientY, best.label, [{ label: series, value: best.disp, color: "var(--amber)" }]);
  };
  const hide = () => { xhair.style.display = "none"; dot.style.display = "none"; lastX = null; vtipHide(); };
  svg.addEventListener("pointermove", move);
  svg.addEventListener("pointerdown", move);
  svg.addEventListener("pointerleave", hide);
  svg.addEventListener("pointercancel", hide);
  svg.addEventListener("pointerup", e => { if (e.pointerType !== "mouse") hide(); });
}

/* One segmented horizontal bar — a "shelf" of colored states (finished / dropped …),
   each carrying its own hover tooltip; legend rows sit below. */
function segBar(segments) {
  const total = segments.reduce((a, s) => a + s.v, 0) || 1;
  const bar = segments.filter(s => s.v).map(s =>
    `<span class="seg" data-tip-title="${esc(s.label)}" data-tip-val="${s.v} of ${total} · ${Math.round(100 * s.v / total)}%"
       data-tip-color="${s.color}" style="flex:${s.v};background:${s.color}"></span>`).join("");
  const legend = segments.map(s =>
    `<span class="seg-lg ${s.v ? "" : "off"}"><span class="seg-dot" style="background:${s.color}"></span>
       <span class="seg-nm">${esc(s.label)}</span><span class="seg-ct">${s.v}</span></span>`).join("");
  return `<div class="segbar">${bar}</div><div class="seg-legend">${legend}</div>`;
}

/* Vertical column chart with a per-column color ramp — used for the ratings
   histogram so score maps to a red→amber→green quality color. */
function colBar(rows) {
  const max = Math.max(...rows.map(r => r.v), 1);
  return `<div class="colbars">${rows.map(r =>
    `<div class="colbar" data-tip-title="${esc(r.label)}" data-tip-val="${r.v} rated" data-tip-color="${r.color}">
       <span class="col-track"><i style="height:${Math.max(3, Math.round(100 * r.v / max))}%;background:${r.color}"></i></span>
       <span class="col-x">${esc(r.xlabel ?? r.label)}</span></div>`).join("")}</div>`;
}

/* Wire interactivity onto a freshly-rendered stats container: crosshair line charts
   plus one delegated hover handler for the mark-based charts (heat cells, ranked
   bars, shelf segments, rating columns). Data/labels ride in data-* attributes and
   are read back via dataset, so untrusted titles never touch innerHTML. */
function wireStats(box) {
  box.querySelectorAll(".linechart").forEach(wireLineChart);
  // watch-clock year selector: swap the grid + caption for the picked year (no refetch)
  const ysel = box.querySelector("#heatyr");
  if (ysel) ysel.onchange = () => {
    const hb = box.querySelector("#heatbox"); if (!hb) return;
    let years; try { years = JSON.parse(hb.dataset.heat); } catch { return; }
    const { grid, caption } = heatInner(years[ysel.value] || []);
    hb.innerHTML = grid;
    const cap = box.querySelector("#heatcap"); if (cap) cap.textContent = caption;
  };
  if (box._statsWired) return;
  box._statsWired = true;
  const marks = ".heat-c[data-tip-title],.rbar[data-tip-title],.seg[data-tip-title],.colbar[data-tip-title]";
  let hot = null;
  const onMove = ev => {
    // line charts run their own crosshair tooltip; this bubbles up to the box, so
    // bail before the vtipHide() below clobbers the tooltip the chart just set.
    if (ev.target.closest(".linechart")) return;
    const el = ev.target.closest(marks);
    if (!el) { if (hot) { hot.classList.remove("hot"); hot = null; } vtipHide(); return; }
    if (el !== hot) { if (hot) hot.classList.remove("hot"); hot = el; el.classList.add("hot"); }
    const c = el.dataset.tipColor;
    vtipShow(ev.clientX, ev.clientY, el.dataset.tipTitle,
      [{ label: "", value: el.dataset.tipVal, color: c }]);
  };
  const leave = () => { if (hot) { hot.classList.remove("hot"); hot = null; } vtipHide(); };
  box.addEventListener("pointermove", onMove);
  box.addEventListener("pointerdown", onMove);
  box.addEventListener("pointerleave", leave);
  box.addEventListener("pointercancel", leave);
  box.addEventListener("pointerup", e => { if (e.pointerType !== "mouse") leave(); });
}
/* horizontal ranked bars — optional rank + face image, hover tooltip. A single
   `hue` tints the whole list (one series = one color); pass `colors` to give each
   bar its own categorical hue (identity, e.g. genres). tipUnit names the value. */
function rankBars(rows, { face = false, hue = "amber", colors = null, tipUnit = "" } = {}) {
  const max = Math.max(...rows.map(r => r.v), 1);
  return `<div class="rbars" style="--barc:var(--c-${hue})">${rows.map((r, i) => {
    const c = colors ? colors[i % colors.length] : null;
    const disp = r.label ?? String(r.v);
    return `<div class="rbar" data-tip-title="${esc(r.name)}" data-tip-val="${esc(disp)}${tipUnit ? " " + esc(tipUnit) : ""}"${c ? ` data-tip-color="${c}"` : ""}>
      <span class="rb-rank"${c ? ` style="color:${c}"` : ""}>${i + 1}</span>
      ${face ? `<span class="rb-face">${r.img ? `<img loading="lazy" src="${r.img}" alt="">` : personGlyph()}</span>` : ""}
      <span class="rb-body">
        <span class="rb-top"><span class="rb-name">${esc(r.name)}</span><span class="rb-num">${esc(disp)}</span></span>
        <span class="rb-track"><i style="width:${Math.max(4, Math.round(100 * r.v / max))}%${c ? `;background:${c}` : ""}"></i></span>
      </span></div>`;
  }).join("")}</div>`;
}

function statsSkeleton() {
  return `<div class="tiles">${Array.from({ length: 4 }, () => `<div class="sk tile-sk"></div>`).join("")}</div>
    <div class="sk" style="height:210px;border-radius:var(--r-s);margin-bottom:16px"></div>`;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
// fixed categorical hue order (identity charts, e.g. genres) — matches CVD-validated slots
const CAT_HUES = ["var(--c-blue)", "var(--c-aqua)", "var(--c-yellow)", "var(--c-green)",
  "var(--c-violet)", "var(--c-red)", "var(--c-pink)", "var(--c-orange)"];
// red→amber→green quality ramp for a 1–10 score
const RATE_RAMP = ["#e0524a", "#e2664a", "#e58248", "#e89c46", "#ecb544",
  "#d8c13f", "#a9c247", "#7dc157", "#57c06a", "#3fbf6f"];
const rateColor = s => RATE_RAMP[Math.max(1, Math.min(10, Math.round(s))) - 1];
const hourLbl = c => c === 0 ? "12 AM" : c < 12 ? c + " AM" : c === 12 ? "12 PM" : (c - 12) + " PM";
const WD = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const WD_FULL = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

// Build the watch-clock grid + a "busiest…" caption for one set of [dow,hour,count]
// cells (one year or all-time). Reused on every year-selector change.
function heatInner(cells) {
  const hm = Array.from({ length: 7 }, () => Array(24).fill(0));
  (cells || []).forEach(([dow, h, c]) => { hm[dow][h] = c; });
  const total = hm.flat().reduce((a, b) => a + b, 0);
  const max = Math.max(...hm.flat(), 1);
  let peak = { d: 0, h: 0, c: 0 };
  hm.forEach((row, r) => row.forEach((v, c) => { if (v > peak.c) peak = { d: r, h: c, c: v }; }));
  const grid = `<div class="heat"><div class="heat-grid">
      ${WD.map((n, r) => `<div class="heat-lbl">${n}</div>` + hm[r].map((v, c) =>
        `<div class="heat-c${r === peak.d && c === peak.h && v ? " peak" : ""}" style="--a:${v ? (0.12 + 0.88 * v / max).toFixed(2) : 0}"
          data-tip-title="${WD_FULL[r]} · ${hourLbl(c)}" data-tip-val="${v} watched · ${total ? Math.round(100 * v / total) : 0}% of the total"></div>`).join("")).join("")}
      <div></div>${[0, 6, 12, 18].map(h => `<div class="heat-h" style="grid-column:${h + 2} / span 6">${hourLbl(h)}</div>`).join("")}
    </div>
    <div class="heat-legend"><span>quieter</span><i style="--a:.16"></i><i style="--a:.42"></i><i style="--a:.7"></i><i style="--a:1"></i><span>busier</span></div></div>`;
  const caption = total
    ? `when you watch${peak.c ? ` · busiest ${WD_FULL[peak.d]} around ${hourLbl(peak.h)}` : ""} · hover a square`
    : "no watches recorded for this range";
  return { grid, caption };
}

function statsSection(d) {
  const months = [];
  for (let i = 23; i >= 0; i--) {
    const dt = new Date(); dt.setDate(1); dt.setMonth(dt.getMonth() - i);
    months.push(dt.toISOString().slice(0, 7));
  }
  const byM = Object.fromEntries(d.monthly.map(m => [m.ym, m.count]));
  const mVals = months.map(m => byM[m] || 0);
  const m24 = mVals.reduce((a, b) => a + b, 0);
  const monLabel = ym => { const [y, mo] = ym.split("-"); return MONTHS[+mo - 1] + " " + y; };
  const peakM = months[mVals.indexOf(Math.max(...mVals))];

  const heatYears = d.heat_years || { all: d.heatmap || [] };
  const hYears = Object.keys(heatYears).filter(y => y !== "all").sort().reverse();
  const h0 = heatInner(heatYears.all || d.heatmap || []);

  const totalMin = d.tv_minutes + d.movie_minutes;
  const comp = d.completion || {};
  const compTotal = Object.values(comp).reduce((a, b) => a + b, 0) || 1;
  const compSegs = [
    { label: "Finished", v: comp.finished || 0, color: "var(--c-green)" },
    { label: "Up to date", v: comp.up_to_date || 0, color: "var(--c-blue)" },
    { label: "In progress", v: comp.in_progress || 0, color: "var(--c-amber)" },
    { label: "Dropped", v: comp.dropped || 0, color: "var(--c-red)" },
    { label: "Not started", v: comp.not_started || 0, color: "var(--c-neutral)" },
  ];
  const ratings = Object.entries(d.rating_hist || {});
  const ratedTotal = ratings.reduce((a, [, c]) => a + c, 0);
  const ratedAvg = ratedTotal ? (ratings.reduce((a, [r, c]) => a + r * c, 0) / ratedTotal) : 0;

  const tile = (cls, hue, v, l, sub) =>
    `<div class="tile ${cls}" style="--tc:var(--c-${hue})"><div class="v">${v}</div>
      <div class="l">${l}</div>${sub ? `<div class="sub">${sub}</div>` : ""}</div>`;

  return `<div class="stats-wrap">
    <div class="tiles reveal">
      ${tile("big", "amber", fmtHours(totalMin), "in front of the screen", `${Math.round(totalMin / 60).toLocaleString()} hours all told`)}
      ${tile("", "blue", d.episodes.toLocaleString(), "episodes", `${fmtHours(d.tv_minutes)} of TV`)}
      ${tile("", "violet", d.movies.toLocaleString(), "movies", `${fmtHours(d.movie_minutes)} of film`)}
      ${tile("", "aqua", d.shows, "shows followed", `${comp.finished || 0} finished`)}
    </div>

    <div class="statcols reveal">
      ${tile("stat-rec", "green", `${d.streak.current || 0}<small class="unit">days</small>`, "current streak",
        `best ${d.streak.longest} days${d.streak.longest_end ? " · ended " + fmtDate(d.streak.longest_end) : ""}`)}
      ${d.big_day ? tile("stat-rec", "orange", `${d.big_day.count}<small class="unit">eps</small>`, "biggest binge day",
        `${fmtDate(d.big_day.date)}${d.big_day.top ? " · mostly " + esc(d.big_day.top) : ""}`) : ""}
      ${tile("stat-rec", "blue", d.per_day, "watches / day",
        `since ${d.first_watch ? fmtDate(d.first_watch.watched_at) : "the start"}`)}
      ${d.first_watch ? `<div class="tile stat-rec" style="--tc:var(--c-pink)"><div class="v tt">${esc(d.first_watch.title)}</div>
        <div class="l">first ever watch</div><div class="sub">${fmtDate(d.first_watch.watched_at)}</div></div>` : ""}
    </div>

    <div class="chart reveal"><div class="ch-head"><h3>Month by month</h3>
      <span class="ch-badge">${m24.toLocaleString()} in 24 mo</span></div>
      <div class="sub">episodes + movies · ${peakM ? "busiest was " + monLabel(peakM) : "last 24 months"} · drag across to read any month</div>
      ${lineChart(months, mVals, { yearMarks: true, series: "watched", labelFmt: monLabel, valFmt: v => v + (v === 1 ? " watch" : " watches") })}</div>

    <div class="chart reveal"><div class="ch-head"><h3>Your watching life</h3>
      ${d.yearly.length ? `<span class="ch-badge">since ${d.yearly[0].y}</span>` : ""}</div>
      <div class="sub">episodes per year, all time · drag to read a year</div>
      ${lineChart(d.yearly.map(y => y.y), d.yearly.map(y => y.c), { series: "episodes", valFmt: v => v.toLocaleString() + " episodes" })}</div>

    <div class="chart reveal"><div class="ch-head"><h3>The watch clock</h3>
      ${hYears.length ? `<select class="yr-sel" id="heatyr" aria-label="Year">
        <option value="all">All time</option>
        ${hYears.map(y => `<option value="${y}">${y}</option>`).join("")}</select>` : ""}</div>
      <div class="sub" id="heatcap">${h0.caption}</div>
      <div id="heatbox" data-heat='${esc(JSON.stringify(heatYears))}'>${h0.grid}</div></div>

    <div class="charts2 reveal">
      <div class="chart"><h3>Top shows by time</h3><div class="sub">your biggest commitments</div>
        ${rankBars(d.top_shows.map(s => ({ name: s.title, v: s.mins, label: fmtHours(s.mins) })), { hue: "amber" })}</div>
      <div class="chart"><h3>Genres</h3><div class="sub">episodes watched, by genre</div>
        ${rankBars(d.genres.map(g => ({ name: g.name, v: g.count })), { colors: CAT_HUES, tipUnit: "episodes" })}</div>
      <div class="chart wide"><h3>Show shelf</h3><div class="sub">where your ${compTotal} followed shows stand</div>
        ${segBar(compSegs)}</div>
      <div class="chart"><h3>Movies by decade</h3><div class="sub">release decade of what you've seen</div>
        ${rankBars((d.movie_decades || []).map(x => ({ name: x.dec + "s", v: x.c })), { hue: "orange", tipUnit: "movies" })}</div>
      ${ratings.length ? `
      <div class="chart"><div class="ch-head"><h3>Your ratings</h3><span class="ch-badge">avg ${ratedAvg.toFixed(1)}</span></div>
        <div class="sub">${ratedTotal} scored · red low → green high</div>
        ${colBar(Array.from({ length: 10 }, (_, i) => {
          const s = i + 1, c = (d.rating_hist[s] || 0);
          return { label: s + "/10", xlabel: s, v: c, color: rateColor(s) };
        }))}</div>
      <div class="chart"><h3>All-timers</h3><div class="sub">your highest-rated</div>
        <div class="alltimers">${(d.top_rated || []).map(t => `<div class="at-row">
          <span class="at-name">${esc(t.title)}</span>
          <span class="at-score" style="color:${rateColor(t.rating)}">${t.rating}<small>/10</small></span></div>`).join("")}</div></div>` : ""}
    </div></div>`;
}

function advancedSection(a) {
  const has = k => (a[k] && a[k].length);
  if (!has("networks") && !has("studios") && !has("actors") && !has("directors") && !has("countries")) return "";
  const enrichNote = a.movies_total && a.movies_enriched < a.movies_total
    ? `<div class="adv-note">Studios, film countries &amp; movie cast fill in gradually — ${a.movies_enriched}/${a.movies_total} movies enriched so far.</div>` : "";
  const netStudio = (has("networks") || has("studios")) ? `
    <div class="charts2">
      ${has("networks") ? `<div class="chart"><h3>Networks</h3><div class="sub">TV homes, by episodes watched</div>
        ${rankBars(a.networks.map(n => ({ name: n.name, v: n.count })), { hue: "blue", tipUnit: "episodes" })}</div>` : ""}
      ${has("studios") ? `<div class="chart"><h3>Studios</h3><div class="sub">film production companies, by titles</div>
        ${rankBars(a.studios.map(n => ({ name: n.name, v: n.count })), { hue: "violet", tipUnit: "movies" })}</div>` : ""}
    </div>` : "";
  const people = (has("actors") || has("directors")) ? `
    <div class="charts2">
      ${has("actors") ? `<div class="chart"><h3>Most-watched faces</h3><div class="sub">actors across your shows &amp; films</div>
        ${rankBars(a.actors.map(p => ({ name: p.name, img: p.img, v: p.shows + p.movies,
          label: [p.shows ? p.shows + " show" + (p.shows > 1 ? "s" : "") : "", p.movies ? p.movies + " film" + (p.movies > 1 ? "s" : "") : ""].filter(Boolean).join(" · ") })), { face: true, hue: "pink" })}</div>` : ""}
      ${has("directors") ? `<div class="chart"><h3>Creators &amp; directors</h3><div class="sub">whose work you keep coming back to</div>
        ${rankBars(a.directors.map(n => ({ name: n.name, v: n.count, label: n.count + " title" + (n.count > 1 ? "s" : "") })), { hue: "aqua" })}</div>` : ""}
    </div>` : "";
  const country = has("countries") ? `
    <div class="chart"><h3>Around the world</h3><div class="sub">where your stories are made</div>
      ${rankBars(a.countries.map(c => ({ name: c.name, v: c.count })), { hue: "green", tipUnit: "titles" })}</div>` : "";
  return `<div class="stats-wrap"><div class="section reveal"><h2>Deeper cuts</h2><div class="rule"></div></div>
    ${enrichNote}${netStudio}${people}${country}</div>`;
}

/* stats now live on the profile — keep old #/stats links working */
routes.stats = () => { history.replaceState(null, "", "#/profile"); parseHash(); };

/* ---------- year in review (flagship recap — a Wrapped-style slideshow) ---------- */
// The recap only unlocks in December (current year) — see the backend. The route is the
// "history spot": a landing that plays the slideshow; the first-view December auto-popup
// is handled by checkRecapPopup() on boot.
routes.recap = async (username, year) => {
  const me = !username || username.toLowerCase() === (ME.username || "").toLowerCase();
  const yr = parseInt(year, 10) || new Date().getFullYear();
  const path = me ? `/recap/${yr}` : `/profile/${encodeURIComponent(username)}/recap/${yr}`;
  const who = me ? "profile" : "u/" + encodeURIComponent(username);
  view.innerHTML = `<div class="recap-load">${skRows(2)}</div>`;
  let d; try { d = await api(path); } catch { location.hash = "#/" + who; return; }
  if (seg()[0] !== "recap" && seg()[0] !== "u") return;
  renderRecapLanding(d, me, username, who, yr);
};

function yrSwitch(years, cur, me, who) {
  years = (years && years.length) ? years : [cur];
  return `<div class="rc-switch">${years.map(y =>
    `<a class="rc-yr ${y === cur ? "on" : ""}" href="#/${me ? "recap" : who + "/recap"}/${y}">${y}</a>`).join("")}</div>`;
}

function renderRecapLanding(d, me, username, who, yr) {
  const first = me ? "Your" : esc((username || "").split(" ")[0] || "Their") + "’s";
  if (d.locked) {
    view.innerHTML = `<div class="page-head"><a class="crumb" href="#/${who}">${backIcon} Profile</a></div>
      <div class="recap-gate">
        <div class="rg-lock">${I.lock}</div>
        <div class="rg-year">${yr}</div>
        <div class="rg-t">Not yet — check back in December</div>
        <div class="rg-s">A Year in Review only makes sense once the year's actually a wrap, so ${yr}'s unlocks this December.</div>
        ${d.years && d.years.length ? `<div class="rg-alt">Look back at a finished year:</div>${yrSwitch(d.years, -1, me, who)}` : ""}
      </div>`;
    return;
  }
  view.innerHTML = `<div class="page-head"><a class="crumb" href="#/${who}">${backIcon} Profile</a></div>
    <div class="recap-land">
      <div class="rl-glow"></div>
      <div class="rl-kick">Year in Review</div>
      <div class="rl-year">${d.year}</div>
      <div class="rl-sub">${first} year at the movies &amp; on the couch</div>
      ${d.has_data ? `
        <div class="rl-teasenums">
          <span><b>${fmtHours(d.minutes)}</b>watched</span>
          <span><b>${(d.episodes || 0).toLocaleString()}</b>episodes</span>
          <span><b>${d.movies || 0}</b>films</span></div>
        <button class="btn pri rl-play" id="rcplay">${I.recap} Play the slideshow</button>`
        : `<div class="empty" style="padding:22px 0">Nothing tracked in ${d.year}.</div>`}
      ${yrSwitch(d.years, d.year, me, who)}
    </div>`;
  if ($("#rcplay")) $("#rcplay").onclick = () => openRecap(d, { me, username });
}

// build the ordered slide markup for a recap (empty sections are skipped)
function recapSlides(d, me, username) {
  const whoCap = me ? "Your" : esc((username || "").split(" ")[0] || "Their") + "’s";
  const mS = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
  const topShow = (d.top_shows || [])[0];
  const runners = (d.top_shows || []).filter(s => s.poster).slice(1, 5);
  const S = [];
  S.push(`<div class="rs intro"><div class="rs-kick">Year in Review</div>
    <div class="rs-year">${d.year}</div>
    <div class="rs-lead">${whoCap} year on the couch — let's rewind it.</div>
    <div class="rs-hint">tap to begin ›</div></div>`);
  S.push(`<div class="rs"><div class="rs-cap">By the numbers</div>
    <div class="rs-nums">
      <div><b>${fmtHours(d.minutes)}</b><span>watched</span></div>
      <div><b>${(d.episodes || 0).toLocaleString()}</b><span>episodes</span></div>
      <div><b>${(d.movies || 0).toLocaleString()}</b><span>movies</span></div>
      <div><b>${d.new_shows || 0}</b><span>new shows</span></div></div></div>`);
  if (topShow) S.push(`<div class="rs show"><div class="rs-cap">Show of the year</div>
    ${topShow.poster ? `<img class="rs-poster" src="${POSTER(topShow.poster)}" alt="">` : ""}
    <div class="rs-title">${esc(topShow.title)}</div>
    <div class="rs-sub">${topShow.eps} episodes · ${fmtHours(topShow.mins)}</div>
    ${runners.length ? `<div class="rs-runners">${runners.map(s =>
      `<img src="${POSTER(s.poster)}" alt="${esc(s.title)}" title="${esc(s.title)}">`).join("")}</div>` : ""}</div>`);
  if ((d.months || []).some(v => v)) {
    const mx = Math.max(...d.months, 1);
    S.push(`<div class="rs"><div class="rs-cap">The shape of your year</div>
      <div class="rs-bars">${d.months.map((v, i) =>
        `<div class="rs-bcol"><i style="height:${Math.max(3, Math.round(100 * v / mx))}%"></i><span>${mS[i]}</span></div>`).join("")}</div>
      ${d.busiest_month ? `<div class="rs-foot">Busiest in <b>${d.busiest_month}</b> · ${d.busiest_month_count} watches</div>` : ""}</div>`);
  }
  if ((d.genres || []).length) S.push(`<div class="rs"><div class="rs-cap">Your top genres</div>
    <div class="rs-rank">${rankBars(d.genres.map(g => ({ name: g.name, v: g.count })))}</div></div>`);
  if ((d.top_movies || []).length) S.push(`<div class="rs"><div class="rs-cap">Films you loved</div>
    <div class="rs-films">${d.top_movies.slice(0, 5).map(m =>
      `<div class="rs-film"><img src="${POSTER(m.poster)}" alt=""><span>${esc(m.title)}</span>${m.rating ? `<b>${m.rating}/10</b>` : ""}</div>`).join("")}</div></div>`);
  const rec = [];
  if (d.binge) rec.push(`<div class="rs-rec"><span>Biggest binge</span><b>${d.binge.count} eps</b><i>${fmtDate(d.binge.date)}${d.binge.top ? " · mostly " + esc(d.binge.top) : ""}</i></div>`);
  if (d.first_watch) rec.push(`<div class="rs-rec"><span>Kicked off with</span><b>${esc(d.first_watch.title)}</b><i>${fmtDate(d.first_watch.watched_at)}</i></div>`);
  if (d.last_watch) rec.push(`<div class="rs-rec"><span>Most recently</span><b>${esc(d.last_watch.title)}</b><i>${fmtDate(d.last_watch.watched_at)}</i></div>`);
  if (rec.length) S.push(`<div class="rs"><div class="rs-cap">For the record</div><div class="rs-recs">${rec.join("")}</div></div>`);
  S.push(`<div class="rs outro"><div class="rs-year sm">${d.year}</div>
    <div class="rs-otitle">That's a wrap.</div>
    <div class="rs-osub">${fmtHours(d.minutes)} · ${(d.episodes || 0).toLocaleString()} episodes · ${d.movies || 0} films</div>
    <button class="btn pri rc-share" id="rcshare">${I.share} Share your ${d.year}</button></div>`);
  return S;
}

async function shareRecap(d, me, username) {
  const text = `${me ? "My" : esc((username || "").split(" ")[0]) + "’s"} ${d.year} on Marquee — ${fmtHours(d.minutes)} watched, ${d.episodes} episodes, ${d.movies} movies.`;
  const url = location.origin + "/#/recap/" + d.year;
  try {
    if (navigator.share) await navigator.share({ title: `Marquee ${d.year}`, text, url });
    else { await navigator.clipboard.writeText(text + " " + url); toast("Copied to clipboard"); }
  } catch { /* dismissed */ }
}

// full-screen story-style slideshow. Tap right/left, swipe, arrow keys; progress segments up top.
function openRecap(d, opts = {}) {
  const { me = true, username = "" } = opts;
  const slides = recapSlides(d, me, username);
  const n = slides.length;
  const ov = document.createElement("div");
  ov.className = "recap-show";
  ov.innerHTML = `
    <div class="rsx-top">
      <div class="rsx-bars">${slides.map((_, i) => `<span class="rsx-seg" data-i="${i}"><i></i></span>`).join("")}</div>
      <button class="rsx-close" aria-label="Close recap">${I.x}</button></div>
    <div class="rsx-stage">${slides.map((s, i) => `<div class="rsx-slide" data-i="${i}">${s}</div>`).join("")}</div>`;
  document.body.appendChild(ov);
  document.body.classList.add("recap-open");
  requestAnimationFrame(() => ov.classList.add("in"));
  let idx = -1;
  const show = i => {
    idx = Math.max(0, Math.min(n - 1, i));
    $$(".rsx-slide", ov).forEach(s => s.classList.toggle("on", +s.dataset.i === idx));
    $$(".rsx-seg", ov).forEach(s => {
      const j = +s.dataset.i; s.classList.toggle("done", j < idx); s.classList.toggle("cur", j === idx);
    });
    const sb = $("#rcshare", ov);
    if (sb) sb.onclick = () => shareRecap(d, me, username);
  };
  const onKey = e => {
    if (e.key === "ArrowRight" || e.key === " ") { e.preventDefault(); next(); }
    else if (e.key === "ArrowLeft") prev();
    else if (e.key === "Escape") close();
  };
  const close = () => {
    document.removeEventListener("keydown", onKey);
    ov.classList.remove("in");
    setTimeout(() => ov.remove(), 220);
    document.body.classList.remove("recap-open");
    opts.onClose && opts.onClose();
  };
  const next = () => { if (idx >= n - 1) close(); else show(idx + 1); };
  const prev = () => show(idx - 1);
  $(".rsx-close", ov).onclick = close;
  $$(".rsx-seg", ov).forEach(s => s.onclick = () => show(+s.dataset.i));
  const stage = $(".rsx-stage", ov);
  let sx = 0, moved = false;
  stage.addEventListener("touchstart", e => { sx = e.touches[0].clientX; moved = false; }, { passive: true });
  stage.addEventListener("touchmove", e => { if (Math.abs(e.touches[0].clientX - sx) > 10) moved = true; }, { passive: true });
  stage.addEventListener("touchend", e => { const dx = e.changedTouches[0].clientX - sx; if (Math.abs(dx) > 45) (dx < 0 ? next() : prev()); });
  stage.addEventListener("click", e => {   // tap right → next, left third → prev; let buttons/links work
    if (moved) { moved = false; return; }
    if (e.target.closest("a,button")) return;
    const r = stage.getBoundingClientRect();
    (e.clientX - r.left < r.width * 0.32) ? prev() : next();
  });
  document.addEventListener("keydown", onKey);
  show(0);
  return { close };
}

// on boot: if the current year's recap just unlocked (December) and hasn't been seen,
// auto-present it once, then mark it seen so it never pops again.
async function checkRecapPopup() {
  try {
    const r = await api("/recap");
    if (!r || !r.autoshow) return;
    const d = await api("/recap/" + r.autoshow);
    if (!d || !d.has_data) return;
    openRecap(d, { me: true, username: ME.username });
    api("/recap/" + r.autoshow + "/seen", { method: "POST", body: {} }).catch(() => {});
  } catch { /* never block boot on the recap */ }
}


/* ---------- settings ---------- */
const PLEX_LOGO = `<svg class="plexlogo" viewBox="0 0 24 24" aria-hidden="true">
  <rect x="1.5" y="1.5" width="21" height="21" rx="5" fill="#1a1a1a"/>
  <path d="M8.2 3.5h4.6L17.2 12l-4.4 8.5H8.2L12.6 12z" fill="#e5a00d"/></svg>`;

routes.settings = async () => {
  const plex = await api("/plex/status").catch(() => ({}));
  const oseer = await api("/overseerr/me").catch(() => ({ enabled: false }));
  const nprefs = (await api("/notifications/prefs").catch(() => ({ prefs: [] }))).prefs;
  const LEADS = [["0", "When it airs"], ["1", "1 day before"], ["3", "3 days before"], ["7", "1 week before"]];
  const notifPanel = `<div class="panel notif-panel"><h3><span class="h3-ic">${I.bell}</span> Notifications</h3>
    <p class="hint">Off by default — switch on only what you want. Alerts appear in your bell inbox, and as push if you enable it below.</p>
    <div class="push-block">
      <div class="push-head">
        <div class="pd-txt"><b>Push to this device</b><span class="hint" id="pushhint">Checking…</span></div>
        <button class="switch-btn" id="pushtoggle" role="switch" aria-checked="false" hidden><span></span></button>
      </div>
      <button class="btn ghost np-test" id="pushtest" hidden>${I.bell}<span>Send a test notification</span></button>
    </div>
    <div class="notif-prefs">${nprefs.map(p => {
      const leads = String(p.value ?? "").split(",").map(s => s.trim()).filter(Boolean);
      return `<div class="np-row ${p.enabled ? "on" : ""}" data-type="${p.type}">
        <div class="np-main">
          <div class="np-txt"><b class="np-label">${esc(p.label)}</b><span class="np-help">${esc(p.help)}</span></div>
          <button class="switch-btn ${p.enabled ? "on" : ""}" role="switch" aria-checked="${p.enabled}" data-np="${p.type}"><span></span></button>
        </div>
        ${p.has_days ? `<div class="np-opts ${p.enabled ? "" : "hidden"}">
          <span class="np-opts-lbl">Remind me</span>
          <div class="lead-chips">${LEADS.map(([v, l]) =>
            `<button type="button" class="lead-chip ${leads.includes(v) ? "on" : ""}" data-lead="${v}">${l}</button>`).join("")}</div>
        </div>` : ""}
      </div>`;
    }).join("")}</div></div>`;
  let usersHtml = "";
  if (ME.is_admin) {
    const users = await api("/users");
    const reg = await api("/admin/registration").catch(() => ({ closed: false }));
    usersHtml = `<div class="panel"><h3>Household</h3>
      <div class="userlist">${users.map(u => `
        <div class="userrow">
          ${avatarHTML({ display_name: u.display_name || u.username, username: u.username, avatar: u.avatar }, "md")}
          <div class="ur-mid"><b>${esc(u.display_name || u.username)}</b>
            <span class="ur-sub">@${esc(u.username)}${u.is_admin ? " · admin" : ""}${u.plex_username ? " · plex: " + esc(u.plex_username) : ""}</span></div>
        </div>`).join("")}</div>
      <label style="margin-top:14px">Add a family account</label>
      <div class="rowset">
        <input id="nu" placeholder="username" autocapitalize="none" style="max-width:150px">
        <input id="np" placeholder="password" style="max-width:150px">
        <button class="btn" id="mkuser">${I.plus} Create</button>
      </div>
      <label class="toggle-row"><span>Public sign-ups
        <span class="hint">${reg.closed ? "closed — only accounts you create can log in (safe for a public link)" : "OPEN — anyone with the link can register"}</span></span>
        <button class="switch-btn ${reg.closed ? "" : "on"}" id="regtoggle" role="switch" aria-checked="${!reg.closed}"><span></span></button>
      </label>
      <p class="hint">Everyone manages their own name, photo and password from their profile.
        Plex links itself when each person taps “Link with Plex”.</p>
    </div>`;
  }
  const plexPanel = `<div class="panel plexpanel">
    <div class="plexhead">${PLEX_LOGO}
      <div><h3>Plex sync</h3>
      <div class="hint">Anything you watch in Plex gets crossed off here automatically.</div></div>
    </div>
    <div class="plexbody" id="plexbody">
      ${plex.plex_username ? `
        <div class="linked">${I.check}<div>
          <b>Linked to ${esc(plex.plex_username)}</b>
          <div class="hint">${plex.direct_sync
              ? `Direct connection to the Plex server is active — history checked every minute.`
              : `Linked by name only — hit “Re-link” once to enable the direct server connection.`}
            ${plex.last_event ? `<br>Last sync event ${fmtDate(plex.last_event)}${plex.last_event_user ? " · " + esc(plex.last_event_user) : ""}` : ""}</div></div>
          ${plex.has_own_token ? "" : `<button class="btn" id="plexlink">Re-link</button>`}
          <button class="btn danger" id="plexunlink">Unlink</button></div>
         <div class="hint" id="plexwait"></div>`
      : `<button class="btn plexbtn" id="plexlink">${PLEX_LOGO} Link with Plex</button>
         <div class="hint" id="plexwait"></div>`}
    </div>
    ${oseer.enabled ? `<div class="ov-sub">
      <span class="ov-mark">${OV_ICON}</span>
      <div class="ov-txt"><b>Requests${oseer.linked ? ` · ${esc(oseer.account)}` : ""}</b>
        <span class="hint">${oseer.linked
          ? "Your requests are sent to Overseerr as you."
          : (oseer.reason || "link your Plex account to request media")}</span></div>
      ${oseer.linked ? `<span class="ov-ok">${I.check}</span>` : ""}
    </div>` : ""}
  </div>`;
  view.innerHTML = `<div class="page-head"><a class="crumb" href="#/profile">${I.chevS} Profile</a></div>
    <h1>Settings</h1><div class="reveal">
    ${plexPanel}
    ${notifPanel}
    <div class="panel"><h3><span class="h3-ic">${BOOK_ICO}</span> Tracking extras</h3>
      <p class="hint">Off by default. Switching one on adds a tab to your own menu — nobody else’s changes.</p>
      <label class="toggle-row"><span>Books
          <span class="hint">Reads, to-reads, page progress and ratings — search by Open Library, import your Goodreads library below.</span></span>
        <button class="switch-btn ${ME.features?.books ? "on" : ""}" data-feat="books" role="switch"
          aria-checked="${!!ME.features?.books}"><span></span></button></label>
      <label class="toggle-row"><span>Manga · manhwa · manhua
          <span class="hint">Chapter-by-chapter progress via AniList — covers Japanese, Korean and Chinese series.</span></span>
        <button class="switch-btn ${ME.features?.manga ? "on" : ""}" data-feat="manga" role="switch"
          aria-checked="${!!ME.features?.manga}"><span></span></button></label>
    </div>
    <div class="panel"><h3>Import</h3>
      <label>TV Time export (.zip)<span class="hint">Shows, movies, watch dates and ratings.</span></label>
      <input type="file" id="tvt" accept=".zip">
      <div class="hint" id="imps"></div>
      <div id="grblock" ${ME.features?.books ? "" : "hidden"}>
        <label style="margin-top:14px">Goodreads library (.csv)<span class="hint">From goodreads.com → My Books → Import/Export. Goodreads closed its API in 2020, so the CSV export is the official way out — shelves, ratings and read-dates come across.</span></label>
        <input type="file" id="grcsv" accept=".csv,text/csv">
        <div class="hint" id="grs"></div>
      </div>
    </div>${usersHtml}</div>
    <div class="build-tag">Marquee · build ${BUILD}</div>`;

  if ($("#plexlink")) $("#plexlink").onclick = async () => {
    const b = $("#plexlink");
    b.disabled = true;
    try {
      const pin = await api("/plex/pin", { body: {} });
      window.open(pin.url, "plexauth", "width=720,height=760");
      $("#plexwait").textContent = "Waiting for you to approve in the Plex window…";
      const t0 = Date.now();
      const poll = setInterval(async () => {
        if (Date.now() - t0 > 150000) { clearInterval(poll); b.disabled = false;
          $("#plexwait").textContent = "Timed out — try again."; return; }
        try {
          const r = await api(`/plex/pin/${pin.id}`);
          if (r.linked) { clearInterval(poll); toast(`Plex linked — ${r.username}`); routes.settings(); }
        } catch { clearInterval(poll); b.disabled = false; $("#plexwait").textContent = "Link expired — try again."; }
      }, 3000);
    } catch { b.disabled = false; }
  };
  if ($("#plexunlink")) $("#plexunlink").onclick = async () => {
    await api("/plex/unlink", { body: {} }); routes.settings();
  };
  $("#tvt").onchange = async () => {
    const f = $("#tvt").files[0]; if (!f) return;
    const fd = new FormData(); fd.append("file", f);
    await api("/import/tvtime", { method: "POST", body: fd });
    $("#imps").textContent = "Import running…";
    const poll = setInterval(async () => {
      const s = await api("/import/status");
      $("#imps").textContent = `${s.state} — ${s.done || 0}/${s.total || "?"}` +
        (s.errors?.length ? ` · ${s.errors.length} skipped` : "");
      if (s.state !== "running") { clearInterval(poll); Object.keys(CACHE).forEach(k => delete CACHE[k]); toast("Import " + s.state); }
    }, 2500);
  };
  $$(".switch-btn[data-feat]", view).forEach(btn => btn.onclick = async () => {
    const on = !btn.classList.contains("on");
    btn.classList.toggle("on", on); btn.setAttribute("aria-checked", on);
    const r = await api("/profile/features", { body: { [btn.dataset.feat]: on ? 1 : 0 } }).catch(() => null);
    if (!r) { btn.classList.toggle("on", !on); return; }
    ME.features = r.features;
    applyFeatureNav();
    if ($("#grblock")) $("#grblock").hidden = !ME.features.books;
    delete CACHE["/reading"];
    toast(on ? `${btn.dataset.feat === "books" ? "Books" : "Manga"} tracking is on — check your menu` : "Turned off");
  });
  if ($("#grcsv")) $("#grcsv").onchange = async () => {
    const f = $("#grcsv").files[0]; if (!f) return;
    const fd = new FormData(); fd.append("file", f);
    await api("/import/goodreads", { method: "POST", body: fd });
    $("#grs").textContent = "Matching your library against Open Library…";
    const poll = setInterval(async () => {
      const s = await api("/import/status");
      $("#grs").textContent = `${s.state} — ${s.done || 0}/${s.total || "?"}` +
        (s.errors?.length ? ` · ${s.errors.length} unmatched` : "");
      if (s.state !== "running") { clearInterval(poll); delete CACHE["/reading"]; toast("Goodreads import " + s.state); }
    }, 2500);
  };
  if ($("#mkuser")) $("#mkuser").onclick = async () => {
    const u = $("#nu").value.trim(), p = $("#np").value;
    if (!u || p.length < 4) { toast("Username + 4+ char password"); return; }
    try { await api("/users", { body: { username: u, password: p } }); toast(`Created ${u}`); routes.settings(); }
    catch {}
  };
  if ($("#regtoggle")) $("#regtoggle").onclick = async () => {
    const b = $("#regtoggle"), nowOn = b.classList.contains("on");   // on = sign-ups open
    await api("/admin/registration", { body: { closed: nowOn } });   // if currently open, close it
    SIGNUP_OPEN = !nowOn; routes.settings();
  };
  const saveNotif = (type) => {
    const row = view.querySelector(`.np-row[data-type="${type}"]`);
    const on = row.querySelector(".switch-btn[data-np]").classList.contains("on");
    let value;
    if (row.querySelector(".lead-chips"))
      value = [...row.querySelectorAll(".lead-chip.on")].map(c => c.dataset.lead).join(",");
    return api("/notifications/prefs", { body: { type, enabled: on, value } }).then(refreshBell);
  };
  $$(".switch-btn[data-np]", view).forEach(btn => btn.onclick = () => {
    const row = btn.closest(".np-row"), type = row.dataset.type, on = !btn.classList.contains("on");
    btn.classList.toggle("on", on); btn.setAttribute("aria-checked", on);
    row.classList.toggle("on", on);
    const opts = row.querySelector(".np-opts");
    if (opts) opts.classList.toggle("hidden", !on);
    saveNotif(type);
  });
  $$(".lead-chip", view).forEach(chip => chip.onclick = () => {
    const row = chip.closest(".np-row");
    chip.classList.toggle("on");
    if (!row.querySelector(".lead-chip.on")) chip.classList.add("on");   // keep at least one
    saveNotif(row.dataset.type);
  });
  wirePush();
};

/* ---------- boot ---------- */
// if the running JS is older than the server's build, clear caches and hard-reload once —
// permanently ends the "stale PWA didn't pick up new code" problem
async function checkBuild() {
  try {
    const { build } = await (await fetch("/api/build", { cache: "no-store" })).json();
    if (build && build !== BUILD && !sessionStorage.getItem("busted")) {
      sessionStorage.setItem("busted", "1");
      if (window.caches) { const ks = await caches.keys(); await Promise.all(ks.map(k => caches.delete(k))); }
      location.reload();
      return true;
    }
    if (build === BUILD) sessionStorage.removeItem("busted");
  } catch { /* offline — carry on with what we have */ }
  return false;
}
async function boot() {
  if (location.pathname !== "/")    // shared pretty URL (/list/3 …) → hash route
    history.replaceState(null, "", "/#/" + location.pathname.replace(/^\/+/, ""));
  if (await checkBuild()) return;   // stale build → reloading with fresh code
  try { ME = await api("/me"); } catch { return; }
  topbar.hidden = false; tabbar.hidden = false;
  paintAvatars();
  applyFeatureNav();
  parseHash();
  refreshBell();
  setInterval(refreshBell, 60000);
  setTimeout(checkRecapPopup, 1400);   // December: auto-present this year's recap once
  setTimeout(() => ["/dashboard", "/upcoming", "/movies", "/lists", "/stats"].forEach(p =>
    api(p).then(d => { CACHE[p] = d; }).catch(() => {})), 600);
}
/* Service worker: installable PWA + offline shell. Registered from root ("/sw.js") so its
   scope covers navigations. It's network-first for HTML and SWR for versioned assets, so it
   won't re-create the old stale-cache trap. */
if ("serviceWorker" in navigator)
  addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));
// a long-lived PWA never re-runs boot(), so it'd stay on old code until relaunched —
// re-check the build whenever the app returns to the foreground (or from bfcache)
document.addEventListener("visibilitychange", () => { if (!document.hidden && ME) checkBuild(); });
addEventListener("pageshow", e => { if (e.persisted) checkBuild(); });
boot();
