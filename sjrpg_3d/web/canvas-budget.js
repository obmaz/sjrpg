// Bound the final compositor target as well as the separate native-world viewport.
// Godot's documented canvasResizePolicy=0 keeps its GL resize/input bookkeeping.
(() => {
  const MAX_PIXELS = 2097152;
  const MAX_RATIO = 2;
  let current = null;
  function mobile() {
    return navigator.userAgentData?.mobile === true ||
      /Android|iPhone|iPad|iPod/i.test(navigator.userAgent || '') ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }
  function dimensions(width, height, ratio) {
    const w = Number.isFinite(width) && width > 0 ? width : 1;
    const h = Number.isFinite(height) && height > 0 ? height : 1;
    const dpr = Number.isFinite(ratio) && ratio > 0 ? ratio : 1;
    const scale = Math.min(dpr, MAX_RATIO, Math.sqrt(MAX_PIXELS / (w * h)));
    return { width: Math.max(1, Math.floor(w * scale)), height: Math.max(1, Math.floor(h * scale)), scale };
  }
  function configure(config) {
    if (current) return current;
    const canvas = config.canvas || document.getElementById('canvas');
    if (!canvas || !mobile()) return { active: false };
    let queued = false;
    let resizeCount = 0;
    let requestedRatio = 1;
    function resize() {
      queued = false;
      requestedRatio = window.devicePixelRatio || 1;
      const target = dimensions(window.innerWidth, window.innerHeight, requestedRatio);
      // Keep CSS geometry and the browser's actual devicePixelRatio intact.
      if (canvas.width !== target.width) canvas.width = target.width;
      if (canvas.height !== target.height) canvas.height = target.height;
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      resizeCount++;
    }
    function schedule() {
      if (queued) return;
      queued = true;
      requestAnimationFrame(resize);
    }
    config.canvas = canvas;
    config.canvasResizePolicy = 0;
    resize();
    window.addEventListener('resize', schedule);
    window.addEventListener('orientationchange', schedule);
    document.addEventListener('fullscreenchange', schedule);
    window.visualViewport?.addEventListener('resize', schedule);
    current = { active: true, snapshot: () => ({
      width: canvas.width, height: canvas.height, pixels: canvas.width * canvas.height,
      css_width: window.innerWidth, css_height: window.innerHeight,
      requested_ratio: requestedRatio, max_ratio: MAX_RATIO, max_pixels: MAX_PIXELS,
      resize_count: resizeCount, pending: queued
    }) };
    return current;
  }
  window.SjrpgCanvasBudget = { configure, dimensions, snapshot: () => current?.snapshot() || { active: false } };
})();
