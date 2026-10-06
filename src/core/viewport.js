'use strict';

// Capture once, before the game loads. Address-bar changes and rotation must
// not replace this height; reloading the page captures a new one.
if (window.matchMedia('(pointer: coarse)').matches && window.innerHeight > 0) {
    document.documentElement.style.setProperty('--app-height', `${window.innerHeight}px`);
}
