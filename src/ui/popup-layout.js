let initialized = false;

function syncPopupViewport() {
    const viewport = window.visualViewport;
    const height = viewport?.height > 0 ? viewport.height : window.innerHeight;
    const width = viewport?.width > 0 ? viewport.width : window.innerWidth;
    const style = document.documentElement.style;
    if (height > 0) style.setProperty('--popup-height', `${height}px`);
    if (width > 0) style.setProperty('--popup-width', `${width}px`);
    style.setProperty('--popup-top', `${viewport?.offsetTop || 0}px`);
    style.setProperty('--popup-left', `${viewport?.offsetLeft || 0}px`);
}

function initializePopupLayout() {
    if (initialized) return;
    initialized = true;
    syncPopupViewport();
    window.addEventListener('resize', syncPopupViewport);
    window.visualViewport?.addEventListener('resize', syncPopupViewport);
    window.visualViewport?.addEventListener('scroll', syncPopupViewport);
    for (const event of ['fullscreenchange', 'webkitfullscreenchange']) {
        document.addEventListener(event, () => {
            syncPopupViewport();
            requestAnimationFrame(syncPopupViewport);
        });
    }
}

export { initializePopupLayout, syncPopupViewport };
