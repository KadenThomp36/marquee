/* Marquee SPA v3 */
"use strict";
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const view = $("#view"), topbar = $("#topbar"), tabbar = $("#tabbar");
let ME = null;
const CACHE = {};
const BUILD = "20260706i";   // must match main.py BUILD; a mismatch means this code is stale

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
  chevR: `<svg viewBox="0 0 24 24" fill="none"><path d="m9 5.5 7 6.5-7 6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  eye: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="3.2" stroke="currentColor" stroke-width="1.8"/></svg>`,
  flag: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M5 21V4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M5 4.5h13l-2.4 4 2.4 4H5z" fill="currentColor" opacity=".55"/></svg>`,
  reply: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M10 8V4.5L3.5 11 10 17.5V14c5 0 8 1.6 10 5 0-6-3.5-11-10-11z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  bell: `<svg class="ico" viewBox="0 0 24 24" fill="none"><path d="M6 9a6 6 0 0 1 12 0c0 5 1.8 6.5 2.5 7.3.4.5.1 1.2-.6 1.2H4.1c-.7 0-1-.7-.6-1.2C4.2 15.5 6 14 6 9Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M9.5 20a2.5 2.5 0 0 0 5 0" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`,
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
const fmtDate = d => d ? new Date(d + (d.length <= 10 ? "T00:00" : "Z"))
  .toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "";
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
  const url = location.origin + "/" + path;
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
      <span class="lo-ic">${l.has ? I.bookmarkfill : I.bookmark}</span>
      <span class="lo-name">${esc(l.name)}${l.is_default ? "" : ""}</span>
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
        a.textContent = "Requested ✓"; setTimeout(() => { sh.close(); done(); }, 900);
      } catch { a.disabled = false; a.textContent = "Request selected"; }
    }
  });
}

const RSTARS = (n, cls = "") => `<span class="rstars ${cls}">${[1,2,3,4,5,6,7,8,9,10].map(i =>
  `<i class="${n >= i ? "on" : ""}" data-v="${i}">${I.star}</i>`).join("")}</span>`;

async function reviewsBlock(itemType, itemId) {
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
        <p class="rev-body">${esc(r.body)}</p>
        <button class="read-more" type="button">Read more</button>
        <span class="src-tag">${esc(r.source)}</span></div>`).join("")}`;
    // only clamp reviews that actually overflow; make them expandable
    $$(".review.ext", host).forEach(el => {
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
      ${r.body ? `<p class="rev-body">${esc(r.body)}</p>` : ""}
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
  window.scrollTo(0, 0);
  if (p[0] === "show" && p[2] === "e") routes.episode(p[1], p[3], p[4]);
  else if (p[0] === "show") routes.show(p[1]);
  else if (p[0] === "movie") routes.movie(p[1]);
  else if (p[0] === "person") routes.person(p[1]);
  else if (p[0] === "list") routes.list(p[1]);
  else (routes[p[0]] || routes.home)(p[1]);
  const active = { list: "lists", movie: "movies", show: "home" }[p[0]] || p[0] || "home";
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
      location.hash = "#/"; boot();
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
function watchedCard(it, { by = false } = {}) {
  return `<a class="wcard" href="#/show/${it.show_id}">
    <div class="wc-shot"><img loading="lazy" src="${POSTER(it.poster)}" alt="">
      ${by && it.by ? `<span class="wc-by">${avatarHTML(it.by, "tiny")}</span>` : ""}
      ${it.count > 1 ? `<span class="wc-count">${it.count}</span>` : ""}</div>
    <div class="wc-t">${esc(it.title)}</div>
    <div class="wc-s">${it.season ? sxe(it.season, it.number) : ""}${it.count > 1 ? ` +${it.count - 1}` : ""}</div>
    ${by && it.by ? `<div class="wc-who">${esc(it.by.display_name)} · ${fmtDate(it.watched_at.slice(0,10))}</div>` : ""}
  </a>`;
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
    ${d.up_next.length ? `${railHead("Up Next")}
      <div class="hrail up ${rv}">${d.up_next.map(x => bigCard(x)).join("")}</div>`
      : `<div class="empty">Nothing in the queue — everything is crossed off.</div>`}
    ${railOf("Haven’t watched in a while", d.stale, x => bigCard(x))}
    ${railOf("On the calendar", d.calendar, calCard, "#/upcoming")}
    <div id="home-recs"></div>
    ${railOf("Recently watched", d.recent, x => watchedCard(x), "#/history")}
    ${railOf("Around the house", d.social, x => watchedCard(x, { by: true }))}
    ${d.reviews && d.reviews.length ? `${railHead("Fresh reviews")}
      <div class="home-revs ${rv}">${d.reviews.slice(0, 4).map(r => `
        <a class="hrev" href="#/${r.type}/${r.id}">
          <img loading="lazy" src="${POSTER(r.poster)}" alt="">
          <div class="hrev-b"><div class="hrev-top">${avatarHTML(r.by, "tiny")}
            <b>${esc(r.by.display_name)}</b>${r.rating ? `<span class="hrev-rate">${I.star}${r.rating}</span>` : ""}</div>
            <div class="hrev-t">${esc(r.title)}</div>
            ${r.body ? `<div class="hrev-x">${esc(r.body)}</div>` : ""}</div></a>`).join("")}</div>` : ""}`;

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
  const today = new Date().toISOString().slice(0, 10);
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
  const today = new Date().toISOString().slice(0, 10);
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
            <div class="pbar-track big"><div class="pbar-fill" style="--p:${watchable.length ? Math.round(100 * watched / watchable.length) : 0}%"></div></div>
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
    ${castStrip(info.cast)}
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
      if (e && e.watched !== on) { e.watched = on; if (on && !e.watched_at) e.watched_at = new Date().toISOString(); patchTotals(on ? 1 : -1); }
      const box = view.querySelector(`.season[data-season="${season}"]`); if (box) patchSeasonHeader(box);
    }
    delete CACHE["/dashboard"];
    api(`/show/${id}/watch`, { body: { season, number, unwatch: !on } }).catch(() => routes.show(id));
  }
  ratingsPanel(id);
  watchNow("show", +id, "watch-now");
  reviewsBlock("show", +id).then(el => { const c = $("#show-reviews"); if (c) c.appendChild(el); });
  mountRequest($("#reqslot"), "show", +id);
  if ($("#shareshow")) $("#shareshow").onclick = () => share(s.title, `show/${id}`);
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
    if (e) { e.watched = on; if (on && !e.watched_at) e.watched_at = new Date().toISOString(); }
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
        <input type="date" id="wd" value="${(e?.watched_at || "").slice(0, 10)}" max="${new Date().toISOString().slice(0,10)}">
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
      ${e.overview ? (e.watched
        ? `<p class="overview">${esc(e.overview)}</p>`
        : `<div class="spoiler" id="spoiler"><p class="overview">${esc(e.overview)}</p>
            <div class="spoiler-veil"><button class="btn" id="revealsp">${I.eye} Reveal spoilers</button></div></div>`)
        : ""}
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
  if ($("#revealsp")) $("#revealsp").onclick = () => $("#spoiler").classList.add("revealed");
  const epKey = (+id) * 1000000 + (+season) * 1000 + (+number);
  reviewsBlock("episode", epKey).then(el => { const c = $("#ep-reviews"); if (c) c.appendChild(el); });
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
    if (b.dataset.a === "watched") { m.state = "watched"; m.watched_at = new Date().toISOString(); d.watched.unshift(m); sparks(b); }
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

/* ---------- lists ---------- */
function renderLists(d) {
  view.innerHTML = `<div class="page-head"><h1>Lists</h1>
    <button class="btn pri" id="newlist">${I.plus} New list</button></div>
    <div class="list-grid reveal">${d.lists.map(l => `
      <a class="listcard" href="#/list/${l.id}">
        <div class="lc-covers">${(l.posters.length
          ? l.posters.slice(0, 4).map(p => `<img loading="lazy" src="${p}" alt="">`).join("")
          : `<div class="lc-empty">${I.bookmark}</div>`)}</div>
        <div class="lc-body"><div class="lc-name">${l.is_default ? I.bookmarkfill : ""} ${esc(l.name)}</div>
          <div class="lc-count">${l.count} ${l.count === 1 ? "title" : "titles"}</div></div>
      </a>`).join("")}</div>`;
  $("#newlist").onclick = async () => {
    const s = sheet(`<div class="sh-t">New list</div>
      <input id="ln" placeholder="e.g. Weekend binges" maxlength="60" autofocus>
      <button class="btn pri" data-v="save">Create</button>
      <button class="btn ghost" data-v="cancel">Cancel</button>`, { cls: "editor" });
    setTimeout(() => $("#ln", s.el)?.focus(), 60);
    s.el.addEventListener("click", async e => {
      if (e.target.closest('[data-v="cancel"]')) return s.close();
      if (e.target.closest('[data-v="save"]')) {
        const name = $("#ln", s.el).value.trim();
        if (!name) return;
        await api("/lists", { body: { name } });
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

routes.list = async id => {
  view.innerHTML = `<div class="sk line-sk" style="width:200px;height:26px;margin-bottom:16px"></div>${skRows(4)}`;
  const l = await api(`/list/${id}`);
  view.innerHTML = `<div class="page-head">
      <a class="crumb" href="#/lists">${I.chevS} Lists</a>
      <div class="ph-actions">
        <button class="iconbtn" id="sharelist" title="Share">${I.share}</button>
        ${l.is_default ? "" : `<button class="iconbtn" id="dellist" title="Delete list">${I.trash}</button>`}
      </div>
    </div>
    <h1>${l.is_default ? I.bookmarkfill : ""} ${esc(l.name)} <span class="cnt">· ${l.items.length}</span></h1>
    ${l.items.length ? `<div class="pgrid reveal">${l.items.map(it => `
      <div class="pcard" data-type="${it.type}" data-id="${it.id}">
        <div class="pshot"><a href="#/${it.type}/${it.id}"><img class="poster" loading="lazy" src="${POSTER(it.poster)}" alt=""></a>
          <span class="badge">${it.type === "show" ? "TV" : "FILM"}</span>
          <div class="act"><button class="rmlist" title="Remove from list" data-a="rm">${I.x}</button></div>
        </div>
        <div class="t">${esc(it.title)}</div><div class="y">${it.year || ""}</div>
      </div>`).join("")}</div>`
      : `<div class="empty">This list is empty. Add titles from any show or movie page.</div>`}`;
  $("#sharelist").onclick = () => share(l.name, `list/${id}`);
  if ($("#dellist")) $("#dellist").onclick = async () => {
    if (confirm(`Delete the list “${l.name}”?`)) {
      await api(`/list/${id}`, { method: "DELETE" }); delete CACHE["/lists"]; location.hash = "#/lists";
    }
  };
  $$(".rmlist", view).forEach(b => b.onclick = async () => {
    const c = b.closest(".pcard");
    await api(`/list/${id}/item`, { body: { item_type: c.dataset.type, item_id: +c.dataset.id, remove: true } });
    c.style.opacity = ".3"; c.querySelector(".rmlist").disabled = true;
    delete CACHE["/lists"];
    setTimeout(() => routes.list(id), 250);
  });
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
    ${castStrip(i.cast)}
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
  mountRequest($("#reqslot"), "movie", +id);
  watchNow("movie", +id, "watch-now");
  $("#movie-reviews").appendChild(await reviewsBlock("movie", +id));
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
routes.profile = async () => {
  const p = await api("/profile");
  view.innerHTML = `
    <div class="profhero reveal">
      <div class="prof-av" id="avwrap">${avatarHTML(p, "xl")}
        <button class="av-edit" id="avedit" title="Change photo">${I.camera}</button>
        <input type="file" id="avfile" accept="image/png,image/jpeg,image/webp" hidden></div>
      <div class="prof-name">${esc(p.display_name)}</div>
      <div class="prof-sub">@${esc(p.username)}${p.is_admin ? " · admin" : ""}</div>
      <button class="btn" id="editprof">${I.edit} Edit profile</button>
    </div>
    <div class="hublinks reveal">
      <a class="hublink" href="#/lists">${I.bookmark}<span>My Lists</span>${I.chevR}</a>
      <a class="hublink" href="#/history">${I.ticket}<span>History</span>${I.chevR}</a>
      <a class="hublink" href="#/stats">${statsIcon()}<span>Stats</span>${I.chevR}</a>
      <a class="hublink" href="#/settings">${gearIcon()}<span>Settings & Plex</span>${I.chevR}</a>
    </div>
    <button class="btn signout" id="signout">Sign out</button>`;
  $("#avedit").onclick = () => $("#avfile").click();
  $("#avfile").onchange = async () => {
    const f = $("#avfile").files[0]; if (!f) return;
    $("#avfile").value = "";
    const blob = await cropImage(f);
    if (!blob) return;
    const fd = new FormData(); fd.append("file", new File([blob], "avatar.jpg", { type: "image/jpeg" }));
    const r = await api("/profile/avatar", { method: "POST", body: fd });
    ME.avatar = r.avatar; p.avatar = r.avatar;
    $("#avwrap").querySelector(".avatar").outerHTML = avatarHTML({ ...p, avatar: r.avatar }, "xl");
    paintAvatars(); toast("Photo updated");
  };
  $("#editprof").onclick = () => editProfile(p);
  $("#signout").onclick = async () => { await api("/logout", { body: {} }); ME = null; routes.login(); };
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
        s.close(); toast("Profile saved"); routes.profile();
      } catch {}
    }
  });
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
function barSVG(labels, vals, { yearMarks = false } = {}) {
  const max = Math.max(...vals, 1);
  const W = 720, H = 190, pad = 24, bw = (W - pad * 2) / vals.length;
  const bars = labels.map((m, i) => {
    const h = Math.round((H - 48) * vals[i] / max);
    const x = pad + i * bw, y = H - 26 - h;
    const showLbl = yearMarks ? m.endsWith("-01") : true;
    const lbl = showLbl ? `<text x="${x + bw / 2}" y="${H - 9}" text-anchor="middle">${yearMarks ? m.slice(0, 4) : m}</text>` : "";
    return `<g><rect class="bar" x="${x + 1.5}" y="${y}" width="${Math.max(bw - 3, 2)}" height="${Math.max(h, vals[i] ? 3 : 0)}" rx="3">
      <title>${m}: ${vals[i]} watched</title></rect>${lbl}
      ${vals[i] === max && max > 0 ? `<text class="val" x="${x + bw / 2}" y="${y - 6}" text-anchor="middle">${vals[i]}</text>` : ""}</g>`;
  }).join("");
  return `<svg viewBox="0 0 ${W} ${H}">
    <line class="grid-l" x1="${pad}" x2="${W - pad}" y1="${H - 26}" y2="${H - 26}"/>${bars}</svg>`;
}

function renderStats(d, animate = true) {
  const months = [];
  for (let i = 23; i >= 0; i--) {
    const dt = new Date(); dt.setDate(1); dt.setMonth(dt.getMonth() - i);
    months.push(dt.toISOString().slice(0, 7));
  }
  const byM = Object.fromEntries(d.monthly.map(m => [m.ym, m.count]));
  const hbars = (rows, unit) => {
    const hmax = Math.max(...rows.map(r => r.v), 1);
    return rows.map(r => `
    <div class="hbar-row"><span class="name" title="${esc(r.name)}">${esc(r.name)}</span>
      <span class="track"><i style="width:${Math.round(100 * r.v / hmax)}%"></i></span>
      <span class="num">${r.label ?? r.v + unit}</span></div>`).join("");
  };

  /* watch clock heatmap: 7 rows × 24 cols */
  const wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const hm = Array.from({ length: 7 }, () => Array(24).fill(0));
  (d.heatmap || []).forEach(([dow, h, c]) => { hm[dow][h] = c; });
  const hmMax = Math.max(...hm.flat(), 1);
  const heat = `<div class="heat">
    <div class="heat-grid">
      ${wd.map((n, r) => `<div class="heat-lbl">${n}</div>` + hm[r].map((v, c) =>
        `<div class="heat-c" style="--a:${v ? (0.12 + 0.88 * v / hmMax).toFixed(2) : 0}"
          title="${n} ${c === 0 ? "12am" : c < 12 ? c + "am" : c === 12 ? "12pm" : (c - 12) + "pm"} — ${v} watched"></div>`).join("")).join("")}
      <div></div>${[0, 6, 12, 18].map(h => `<div class="heat-h" style="grid-column:${h + 2} / span 6">${h === 0 ? "12am" : h === 12 ? "12pm" : h < 12 ? h + "am" : (h - 12) + "pm"}</div>`).join("")}
    </div></div>`;

  const totalMin = d.tv_minutes + d.movie_minutes;
  const comp = d.completion || {};
  const compTotal = Object.values(comp).reduce((a, b) => a + b, 0) || 1;
  const compRow = (label, key) => comp[key] ? `
    <div class="hbar-row"><span class="name">${label}</span>
      <span class="track"><i style="width:${Math.round(100 * comp[key] / compTotal)}%"></i></span>
      <span class="num">${comp[key]}</span></div>` : "";

  const records = `
    <div class="tiles reveal">
      <div class="tile"><div class="v">${d.streak.current || 0}<small class="unit">days</small></div>
        <div class="l">current streak</div>
        <div class="sub">best: ${d.streak.longest} days${d.streak.longest_end ? " · ended " + fmtDate(d.streak.longest_end) : ""}</div></div>
      ${d.big_day ? `<div class="tile"><div class="v">${d.big_day.count}<small class="unit">eps</small></div>
        <div class="l">biggest binge day</div>
        <div class="sub">${fmtDate(d.big_day.date)}${d.big_day.top ? " · mostly " + esc(d.big_day.top) : ""}</div></div>` : ""}
      <div class="tile"><div class="v">${d.per_day}</div><div class="l">watches / day</div>
        <div class="sub">since ${d.first_watch ? fmtDate(d.first_watch.watched_at) : "the beginning"}</div></div>
      ${d.first_watch ? `<div class="tile"><div class="v" style="font-size:17px;line-height:1.3;padding-top:4px">${esc(d.first_watch.title)}</div>
        <div class="l">first ever watch</div><div class="sub">${fmtDate(d.first_watch.watched_at)}</div></div>` : ""}
    </div>`;

  view.innerHTML = `<h1>Stats <span class="cnt">· ${esc(ME.username)}</span></h1>
    <div class="tiles reveal">
      <div class="tile big"><div class="v">${fmtHours(totalMin)}</div><div class="l">in front of the screen</div>
        <div class="sub">${Math.round(totalMin / 60).toLocaleString()} hours total</div></div>
      <div class="tile"><div class="v">${d.episodes.toLocaleString()}</div><div class="l">episodes</div>
        <div class="sub">${fmtHours(d.tv_minutes)} of TV</div></div>
      <div class="tile"><div class="v">${d.movies.toLocaleString()}</div><div class="l">movies</div>
        <div class="sub">${fmtHours(d.movie_minutes)} of film</div></div>
      <div class="tile"><div class="v">${d.shows}</div><div class="l">shows followed</div>
        <div class="sub">${comp.finished || 0} finished</div></div>
    </div>

    <div class="section"><h2>Records</h2><div class="rule"></div></div>
    ${records}

    <div class="section"><h2>${new Date().getFullYear()} so far</h2><div class="rule"></div></div>
    <div class="tiles reveal">
      <div class="tile"><div class="v">${d.this_year.episodes.toLocaleString()}</div><div class="l">episodes</div></div>
      <div class="tile"><div class="v">${d.this_year.movies}</div><div class="l">movies</div></div>
      ${d.this_year.top?.[0] ? `<div class="tile wide"><div class="v" style="font-size:17px;line-height:1.3;padding-top:4px">${esc(d.this_year.top[0].title)}</div>
        <div class="l">show of the year</div><div class="sub">${d.this_year.top[0].eps} episodes · ${fmtHours(d.this_year.top[0].mins)}</div></div>` : ""}
    </div>

    <div class="chart"><h3>Month by month</h3>
      <div class="sub">episodes + movies · last 24 months</div>
      ${barSVG(months, months.map(m => byM[m] || 0), { yearMarks: true })}</div>

    <div class="chart"><h3>Your watching life</h3><div class="sub">episodes per year, all time</div>
      ${barSVG(d.yearly.map(y => y.y), d.yearly.map(y => y.c))}</div>

    <div class="chart"><h3>The watch clock</h3><div class="sub">when you actually watch — darker is more</div>
      ${heat}</div>

    <div class="charts2">
      <div class="chart"><h3>Top shows by time</h3><div class="sub">your biggest commitments</div>
        ${hbars(d.top_shows.map(s => ({ name: s.title, v: s.mins, label: fmtHours(s.mins) })), "")}</div>
      <div class="chart"><h3>Genres</h3><div class="sub">by episodes watched</div>
        ${hbars(d.genres.map(g => ({ name: g.name, v: g.count })), "")}</div>
      <div class="chart"><h3>Show shelf</h3><div class="sub">where your ${compTotal} shows stand</div>
        ${compRow("Finished", "finished")}${compRow("Up to date", "up_to_date")}
        ${compRow("In progress", "in_progress")}${compRow("Dropped", "dropped")}
        ${compRow("Not started", "not_started")}</div>
      <div class="chart"><h3>Movies by decade</h3><div class="sub">release decade of what you've watched</div>
        ${hbars((d.movie_decades || []).map(x => ({ name: x.dec + "s", v: x.c })), "")}</div>
      ${Object.keys(d.rating_hist || {}).length ? `
      <div class="chart"><h3>Your ratings</h3><div class="sub">how you score things</div>
        ${hbars(Object.entries(d.rating_hist).sort((a, b) => b[0] - a[0]).map(([r, c]) => ({ name: r + "/10", v: c })), "")}</div>
      <div class="chart"><h3>All-timers</h3><div class="sub">your highest-rated</div>
        ${(d.top_rated || []).map(t => `<div class="hbar-row" style="grid-template-columns:1fr 44px">
          <span class="name">${esc(t.title)}</span><span class="num">${t.rating}/10</span></div>`).join("")}</div>` : ""}
    </div>`;
}
routes.stats = () => {
  const c = cached("/stats");
  if (c.stale) renderStats(c.stale);
  else view.innerHTML = `<h1>Stats</h1><div class="tiles">${Array.from({ length: 5 }, () => `<div class="sk tile-sk"></div>`).join("")}</div>${skRows(3)}`;
  c.refresh(() => seg()[0] === "stats", d => renderStats(d, !c.stale));
};

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
    <div class="panel"><h3>Import</h3>
      <label>TV Time export (.zip)<span class="hint">Shows, movies, watch dates and ratings.</span></label>
      <input type="file" id="tvt" accept=".zip">
      <div class="hint" id="imps"></div>
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
  if (await checkBuild()) return;   // stale build → reloading with fresh code
  try { ME = await api("/me"); } catch { return; }
  topbar.hidden = false; tabbar.hidden = false;
  paintAvatars();
  parseHash();
  refreshBell();
  setInterval(refreshBell, 60000);
  setTimeout(() => ["/dashboard", "/upcoming", "/movies", "/lists", "/stats"].forEach(p =>
    api(p).then(d => { CACHE[p] = d; }).catch(() => {})), 600);
}
/* Service worker: installable PWA + offline shell. Registered from root ("/sw.js") so its
   scope covers navigations. It's network-first for HTML and SWR for versioned assets, so it
   won't re-create the old stale-cache trap. */
if ("serviceWorker" in navigator)
  addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));
boot();
