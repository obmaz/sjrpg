(() => {
  const root = document.documentElement;
  let deferred = null;
  let pending = false;
  const update = (result = '') => {
    root.setAttribute('data-install-ready', String(Boolean(deferred) && !pending));
    root.setAttribute('data-install-result', result);
    document.dispatchEvent(new Event('guardian-install-change'));
  };
  if (matchMedia('(display-mode: standalone)').matches || navigator.standalone === true) {
    root.setAttribute('data-app-installed', 'true');
  }
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    deferred = event;
    update();
  });
  window.addEventListener('appinstalled', () => {
    deferred = null;
    root.setAttribute('data-app-installed', 'true');
    update('installed');
  });
  document.addEventListener('guardian-install-request', async () => {
    if (!deferred || pending) { update('unavailable'); return; }
    const event = deferred;
    deferred = null;
    pending = true;
    let result = 'unavailable';
    try {
      await event.prompt();
      result = (await event.userChoice).outcome;
    } catch { /* The settings panel keeps the manual install instructions available. */ }
    pending = false;
    update(result);
  });
  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register('/sjrpg/new/sw.js', {
      scope: '/sjrpg/new/', updateViaCache: 'none',
    }).catch(() => {});
  }
})();
