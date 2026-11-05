// Keep the native install gesture synchronous across the Godot -> JavaScript bridge.
(() => {
  let deferredPrompt = null;
  let prompting = false;
  let installedHere = false;
  let outcome = '';
  const standalone = window.matchMedia('(display-mode: standalone)');
  const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  function isInstalled() { return installedHere || standalone.matches || navigator.standalone === true; }
  function manualHint() {
    if (!window.isSecureContext) return '설치는 HTTPS 주소에서 지원됩니다. 공식 게임 주소를 열어 주세요.';
    if (ios) return 'Safari에서 공유 버튼 → 홈 화면에 추가 → 추가를 누르세요. 다른 브라우저라면 Safari로 열어 주세요.';
    return '브라우저 메뉴에서 앱 설치 또는 홈 화면에 추가를 선택하세요. 해당 항목이 없으면 최신 Chrome·Edge 또는 Safari에서 열어 주세요.';
  }
  function state() {
    if (isInstalled()) return { status: 'installed', title: '설치됨', detail: '설치된 앱으로 모험을 즐길 수 있습니다. 실행할 때 인터넷 연결이 필요합니다.' };
    if (prompting) return { status: 'prompting', title: '설치 창 확인 중', detail: '브라우저의 설치 창에서 계속하거나 취소해 주세요.' };
    if (deferredPrompt) return { status: 'available', title: '이 기기에 설치', detail: outcome === 'gesture' ? '설치 버튼을 다시 직접 눌러 주세요.' : '홈 화면에서 앱처럼 열 수 있습니다. 설치 후에도 인터넷 연결이 필요합니다.' };
    let detail = manualHint();
    if (outcome === 'dismissed') detail = '설치를 취소했습니다. 모험과 저장은 그대로 유지됩니다. ' + detail;
    if (outcome === 'accepted') detail = '설치를 요청했습니다. 브라우저에서 설치를 마무리해 주세요. ' + detail;
    if (outcome === 'failed') detail = '설치 창을 열지 못했습니다. ' + detail;
    if (outcome === 'gesture') detail = '설치 버튼을 다시 직접 눌러 주세요. ' + detail;
    return { status: 'manual', title: '설치 · 홈 화면 추가 안내', detail };
  }
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    deferredPrompt = event;
    outcome = '';
  });
  window.addEventListener('appinstalled', () => {
    installedHere = true;
    deferredPrompt = null;
    prompting = false;
    outcome = '';
  });
  window.SjrpgInstall = {
    state,
    request() {
      if (isInstalled() || prompting || !deferredPrompt) return state();
      if (navigator.userActivation && !navigator.userActivation.isActive) {
        outcome = 'gesture';
        return { ...state(), detail: '설치 버튼을 직접 눌러 주세요.' };
      }
      const promptEvent = deferredPrompt;
      deferredPrompt = null; // A native BeforeInstallPromptEvent can only be used once.
      prompting = true;
      try {
        const promptResult = promptEvent.prompt(); // No await or timer before this gesture-bound call.
        Promise.resolve(promptResult).then(() => promptEvent.userChoice).then(choice => {
          outcome = choice && choice.outcome === 'accepted' ? 'accepted' : 'dismissed';
        }).catch(() => { outcome = 'failed'; }).finally(() => { prompting = false; });
      } catch (_) {
        prompting = false;
        outcome = 'failed';
      }
      return state();
    }
  };
  if (window.isSecureContext && 'serviceWorker' in navigator) {
    // This worker does not cache the engine or game pack; deployments keep one network version.
    navigator.serviceWorker.register('install-sw.js', { scope: './', updateViaCache: 'none' }).catch(() => {
      // Installation can still use the browser's manual flow; never block game startup.
    });
  }
})();
