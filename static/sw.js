/* Marquee service worker — installable PWA + offline shell, WITHOUT the stale-cache trap.
   Strategy:
     - navigations (HTML)   -> network-first, fall back to the cached app shell when offline
     - /static/ assets      -> stale-while-revalidate; URLs are ?v=... versioned so a new
                               deploy points index.html at fresh URLs = guaranteed cache miss
     - /api/ + cross-origin -> pass straight through (never cached here)
   Bump SHELL/ASSETS when the caching logic itself changes to evict old caches. */
const SHELL = "marquee-shell-v2";
const ASSETS = "marquee-assets-v2";

self.addEventListener("install", e => {
  self.skipWaiting();
  e.waitUntil(caches.open(SHELL).then(c => c.add("/").catch(() => {})));
});

self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== SHELL && k !== ASSETS).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;      // TMDB images etc. — let the network handle it
  if (url.pathname.startsWith("/api/")) return;    // never cache the API

  if (req.mode === "navigate") {                   // HTML: always try the network first
    e.respondWith((async () => {
      try {
        const net = await fetch(req);
        const c = await caches.open(SHELL); c.put("/", net.clone());
        return net;
      } catch {
        return (await caches.match("/")) || (await caches.match(req)) || Response.error();
      }
    })());
    return;
  }

  if (url.pathname.startsWith("/static/")) {        // versioned assets: stale-while-revalidate
    e.respondWith((async () => {
      const c = await caches.open(ASSETS);
      const hit = await c.match(req);
      const net = fetch(req).then(r => { if (r && r.ok) c.put(req, r.clone()); return r; }).catch(() => hit);
      return hit || net;
    })());
  }
});

/* ── web push ── */
self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { title: "Marquee", body: e.data && e.data.text() }; }
  const opts = { body: d.body || "", icon: "/static/icon-192.png", badge: "/static/icon-192.png",
                 data: { link: d.link || "" } };
  if (d.link) opts.tag = d.link;
  e.waitUntil(self.registration.showNotification(d.title || "Marquee", opts));
});

self.addEventListener("notificationclick", e => {
  e.notification.close();
  const link = (e.notification.data && e.notification.data.link) || "";
  const target = "/#/" + link;
  e.waitUntil((async () => {
    const wins = await clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const c of wins) {
      if ("focus" in c) { await c.focus(); if (link && "navigate" in c) c.navigate(target).catch(() => {}); return; }
    }
    if (clients.openWindow) return clients.openWindow(target);
  })());
});
