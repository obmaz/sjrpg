// Installation support and an honest offline launch message. Game assets remain network-only.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => {
  if (event.request.mode !== 'navigate') return;
  event.respondWith(fetch(event.request).catch(() => new Response(`<!DOCTYPE html>
<html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#102c29"><title>자연의 수호자</title>
<style>body{margin:0;min-height:100dvh;display:grid;place-items:center;background:#102c29;color:#eee4c9;font:16px/1.8 system-ui,sans-serif}main{max-width:420px;padding:32px}h1{font-size:27px}button{width:100%;min-height:56px;margin-top:20px;background:#393a2b;border:1px solid #a89b70;border-radius:4px;color:inherit;font:inherit}</style>
<main><h1>숲으로 돌아가는 길</h1><p>모험을 시작하려면 인터넷 연결이 필요합니다. 연결한 뒤 다시 불러와 주세요.</p><p>이 브라우저에 저장된 진행은 유지됩니다.</p><button onclick="location.reload()">다시 불러오기</button></main></html>`, { headers: { 'Content-Type': 'text/html; charset=utf-8' }, status: 503 })));
});
