// FieldLog service worker: keeps the app available offline.
const CACHE = 'fieldlog-v0.11.0';
const TILES = 'fieldlog-map-tiles'; // NRCan base map tiles already viewed, kept for use offline (trimmed)
const SAVED = 'fieldlog-map-saved'; // base maps downloaded on purpose for a site (never trimmed)
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './fieldlog-config.json', './fieldlog-3d.js'];
// Add files one by one so a missing optional file (fieldlog-config.json) doesn't block installation.
// Each file is fetched with a one-off ?v= query and cache: 'reload', so neither the browser's cache nor GitHub's CDN
// (which keeps files for up to 10 minutes after an upload) can hand the new version an old copy of the page.
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(FILES.map(f => fetch(new Request(`${f}${f.includes('?') ? '&' : '?'}v=${encodeURIComponent(CACHE)}-${Date.now()}`, { cache: 'reload' })).then(r => r.ok ? c.put(f, r) : null).catch(() => {}))))); self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE && k !== TILES && k !== SAVED).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method === 'GET' && u.hostname === 'geoappext.nrcan.gc.ca' && u.pathname.includes('/tile/')) {
    e.respondWith(caches.open(TILES).then(async c => {
      const sv = await (await caches.open(SAVED)).match(e.request.url); if (sv && !(e.request.mode === 'cors' && sv.type === 'opaque')) return sv;
      const hit = await c.match(e.request); if (hit && !(e.request.mode === 'cors' && hit.type === 'opaque')) return hit;
      try { const r = await fetch(e.request); if (r.ok || r.type === 'opaque') { c.put(e.request, r.clone()); trimTiles(c); } return r; } catch (er) { return Response.error(); }
    }));
    return;
  }
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  const page = e.request.mode === 'navigate' || /\/(index\.html)?$/.test(new URL(e.request.url).pathname) || /sw\.js$/.test(e.request.url);
  e.respondWith(caches.open(CACHE).then(async c => {
    const hit = await c.match(e.request, { ignoreSearch: true });
    // Pages are re-fetched as a plain GET (a navigation request can't be given its own cache option, which made the old
    // version silently fall back to the saved copy every time), with a fresh ?v= so the CDN can't return a stale copy either.
    const net = (page ? fetch(new Request(`${u.origin}${u.pathname}?v=${Date.now()}`, { cache: 'no-store', credentials: 'same-origin' })) : fetch(e.request))
      .then(r => { if (r.ok) c.put(page ? new Request(u.origin + u.pathname) : e.request, r.clone()); return r; }).catch(() => null);
    if (page) {
      // The app page: use the network when it answers within 4 s (so updates show on the next open), otherwise the saved copy.
      const timeout = new Promise(res => setTimeout(() => res(null), 4000));
      return (await Promise.race([net, timeout])) || hit || (await net) || c.match('./index.html');
    }
    // Everything else: saved copy straight away, refreshed in the background.
    return hit || (await net) || c.match('./index.html');
  }));
});
let trimT = 0;
function trimTiles(c) { // keep the tile cache to about 3000 tiles
  if (Date.now() - trimT < 60000) return; trimT = Date.now();
  c.keys().then(ks => { if (ks.length > 3000) ks.slice(0, ks.length - 3000).forEach(k => c.delete(k)); });
}
