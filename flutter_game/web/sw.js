// Network-only navigation keeps releases fresh; no game or asset cache is maintained.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => {
  if (event.request.mode !== 'navigate') return;
  event.respondWith(fetch(event.request, { cache: 'no-store' }).catch(() => new Response(
    '<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>자연의 수호자</title><body style="background:#102c29;color:#ecdfb5;font:18px system-ui;padding:32px"><h1>연결을 기다리고 있어요</h1><p>모험을 시작하려면 인터넷에 연결한 뒤 다시 열어 주세요.</p><button onclick="location.reload()">다시 시도</button></body></html>',
    { headers: { 'Content-Type': 'text/html; charset=utf-8' }, status: 503 },
  )));
});
