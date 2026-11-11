// FieldLog service worker: keeps the app available offline.
const CACHE = 'fieldlog-v0.10.5';
const TILES = 'fieldlog-map-tiles'; // NRCan base map tiles already viewed, kept for use offline
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './fieldlog-config.json', './fieldlog-3d.js'];
// Add files one by one so a missing optional file (fieldlog-config.json) doesn't block installation.
// cache: 'reload' skips the browser's HTTP cache, so a new version never re-caches the old files.
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(FILES.map(f => c.add(new Request(f, { cache: 'reload' })).catch(() => {}))))); self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE && k !== TILES).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method === 'GET' && u.hostname === 'geoappext.nrcan.gc.ca' && u.pathname.includes('/tile/')) {
    e.respondWith(caches.open(TILES).then(async c => {
      const hit = await c.match(e.request); if (hit) return hit;
      try { const r = await fetch(e.request); if (r.ok || r.type === 'opaque') { c.put(e.request, r.clone()); trimTiles(c); } return r; } catch (er) { return Response.error(); }
    }));
    return;
  }
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  const page = e.request.mode === 'navigate' || /\/(index\.html)?$/.test(new URL(e.request.url).pathname) || /sw\.js$/.test(e.request.url);
  e.respondWith(caches.open(CACHE).then(async c => {
    const hit = await c.match(e.request, { ignoreSearch: true });
    const net = fetch(e.request, page ? { cache: 'no-cache' } : undefined).then(r => { if (r.ok) c.put(e.request, r.clone()); return r; }).catch(() => null);
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
