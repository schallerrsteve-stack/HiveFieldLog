// FieldLog service worker: keeps the app available offline.
const CACHE = 'fieldlog-v0.9.11';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './fieldlog-config.json', './fieldlog-3d.js'];
// Add files one by one so a missing optional file (fieldlog-config.json) doesn't block installation.
// cache: 'reload' skips the browser's HTTP cache, so a new version never re-caches the old files.
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(FILES.map(f => c.add(new Request(f, { cache: 'reload' })).catch(() => {}))))); self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
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
