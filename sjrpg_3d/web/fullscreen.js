// Keep gesture-bound calls synchronous across the Godot -> JavaScript bridge.
(() => {
  const standalone = window.matchMedia('(display-mode: standalone)');
  const fullscreen = window.matchMedia('(display-mode: fullscreen)');
  const element = () => document.fullscreenElement || document.webkitFullscreenElement;
  // Capture before this page requests DOM fullscreen. That request also changes
  // display-mode:fullscreen, but it does not install a normal browser tab.
  const installedLaunch = navigator.standalone === true || standalone.matches ||
    (fullscreen.matches && !element());
  let changing = false;
  let failure = '';
  const request = () => document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen;
  const exit = () => document.exitFullscreen || document.webkitExitFullscreen;
  const enabled = () => document.documentElement.requestFullscreen ? document.fullscreenEnabled !== false :
    Boolean(document.documentElement.webkitRequestFullscreen) && document.webkitFullscreenEnabled !== false;

  function state() {
    const nativeAppFullscreen = installedLaunch && fullscreen.matches && !element();
    const active = Boolean(element()) || nativeAppFullscreen;
    const supported = element() ? Boolean(exit()) : enabled() && !nativeAppFullscreen;
    let detail = installedLaunch ? '설치한 앱은 지원되는 화면 모드로 실행됩니다.' : '전체화면에서 브라우저 표시줄을 숨기고 모험할 수 있습니다.';
    if (nativeAppFullscreen) detail = '설치한 앱의 기본 전체화면을 사용 중입니다.';
    else if (!supported) detail = installedLaunch ? '이 기기는 설치된 앱 화면을 사용합니다. 별도 전체화면 전환은 지원하지 않습니다.' : '이 브라우저는 전체화면 전환을 지원하지 않습니다. 홈 화면에 추가하면 앱 화면으로 사용할 수 있습니다.';
    return {
      installed: installedLaunch, active, supported, pending: changing,
      title: changing ? '화면 전환 중' : nativeAppFullscreen ? '전체화면 사용 중' : !supported ? '전체화면 지원 안내' : active ? '전체화면 끄기' : '전체화면 켜기',
      detail: failure || detail
    };
  }

  function toggle() {
    if (changing || !state().supported) return state();
    failure = '';
    changing = true;
    try {
      const result = element() ? exit().call(document) : request().call(document.documentElement);
      Promise.resolve(result).catch(() => {
        failure = '전체화면을 전환하지 못했습니다. 버튼을 다시 직접 눌러 주세요.';
      }).finally(() => { changing = false; });
    } catch (_) {
      changing = false;
      failure = '전체화면을 전환하지 못했습니다. 버튼을 다시 직접 눌러 주세요.';
    }
    return state();
  }

  window.SjrpgFullscreen = { state, toggle };
  // Manifest fullscreen needs no API call. A platform falling back to standalone
  // may require a trusted gesture; try once, then respect later manual exits.
  if (installedLaunch && !state().active && enabled()) {
    const firstGesture = event => {
      if (!event.isTrusted || (event.type === 'keydown' && (event.repeat || event.key === 'Escape'))) return;
      if (navigator.userActivation && !navigator.userActivation.isActive) return;
      document.removeEventListener('click', firstGesture, true);
      document.removeEventListener('keydown', firstGesture, true);
      if (!state().active) toggle();
    };
    document.addEventListener('click', firstGesture, true);
    document.addEventListener('keydown', firstGesture, true);
  }
})();
