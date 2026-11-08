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
  let fullscreenTransition = Promise.resolve();
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
      fullscreenTransition = Promise.resolve(result).catch(() => {
        failure = '전체화면을 전환하지 못했습니다. 버튼을 다시 직접 눌러 주세요.';
      }).finally(() => { changing = false; });
    } catch (_) {
      changing = false;
      failure = '전체화면을 전환하지 못했습니다. 버튼을 다시 직접 눌러 주세요.';
    }
    return state();
  }

  // Orientation requests share the document fullscreen target with the existing
  // button, preserving both the DOM entry overlay and Godot's input coordinates.
  let orientationChoice = 'auto';
  let orientationPending = false;
  let orientationDetail = '';
  let orientationLocked = false;
  let orientationOperation = 0;
  const orientationAPI = () => window.screen && window.screen.orientation;
  const orientationSupported = () => Boolean(orientationAPI() &&
    typeof orientationAPI().lock === 'function' && typeof orientationAPI().unlock === 'function');
  function orientationState() {
    return {
      choice: orientationChoice, supported: orientationSupported(),
      pending: orientationPending, locked: orientationLocked,
      detail: orientationDetail || (orientationSupported() ?
        '자동은 기기 방향에 맞춥니다. 방향 고정에는 전체화면 허용이 필요할 수 있습니다.' :
        '이 브라우저에서는 방향 고정을 지원하지 않습니다. 기기를 직접 돌려 주세요.')
    };
  }
  function setOrientation(choice, gesture) {
    if (!['auto', 'landscape', 'portrait'].includes(choice)) choice = 'auto';
    const operation = ++orientationOperation;
    orientationChoice = choice;
    orientationDetail = '';
    orientationPending = false;
    if (!orientationSupported()) return orientationState();
    if (choice === 'auto') {
      try {
        orientationAPI().unlock();
        orientationLocked = false;
        orientationDetail = '자동 회전으로 전환했습니다. 기기를 원하는 방향으로 돌려 주세요.';
      } catch (_) { orientationDetail = '자동 회전을 적용하지 못했습니다. 기기의 회전 설정을 확인해 주세요.'; }
      return orientationState();
    }
    // Startup restores the saved choice without asking for fullscreen permission.
    // A direct settings click retries it through the trusted gesture below.
    if (!gesture && !element() && !installedLaunch) {
      orientationDetail = '저장한 방향을 고정하려면 해당 버튼을 다시 눌러 주세요.';
      return orientationState();
    }
    orientationPending = true;
    orientationDetail = '화면 방향을 전환하고 있습니다.';
    try {
      // Invoke requestFullscreen synchronously inside Button.pressed. Waiting
      // until a rejected lock() loses the activation required by mobile browsers.
      const appFullscreen = installedLaunch && fullscreen.matches && !element();
      const entering = changing ? fullscreenTransition :
        gesture && !element() && !appFullscreen && enabled() ? request().call(document.documentElement) : undefined;
      Promise.resolve(entering).then(() => {
        if (operation !== orientationOperation) return;
        return orientationAPI().lock(choice);
      }).then(() => {
        if (operation !== orientationOperation) {
          if (orientationChoice === 'auto') orientationAPI().unlock();
          return;
        }
        orientationLocked = true;
        orientationDetail = choice === 'landscape' ? '가로 방향으로 고정했습니다.' : '세로 방향으로 고정했습니다.';
      }).catch(() => {
        if (operation !== orientationOperation) return;
        orientationLocked = false;
        orientationDetail = '방향을 고정하지 못했습니다. 전체화면을 허용하고 다시 선택해 주세요.';
      }).finally(() => {
        if (operation === orientationOperation) orientationPending = false;
      });
    } catch (_) {
      orientationPending = false;
      orientationLocked = false;
      orientationDetail = '방향을 고정하지 못했습니다. 기기의 회전 설정을 확인해 주세요.';
    }
    return orientationState();
  }
  window.SjrpgOrientation = {
    state: orientationState,
    choose: choice => setOrientation(choice, true),
    restore: choice => setOrientation(choice, false)
  };
  document.addEventListener('fullscreenchange', () => {
    if (!element() && !installedLaunch && orientationLocked) {
      orientationLocked = false;
      orientationDetail = '전체화면이 종료되어 방향 고정이 해제됐습니다. 다시 선택해 주세요.';
    }
  });

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
