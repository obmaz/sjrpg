import { preferences, stopVibration } from '../core/preferences.js';
import { session } from '../core/state.js';

let lastImpact = -Infinity;
function hapticImpact(kind = 'hit') {
    if (
        !preferences.vibration ||
        typeof navigator === 'undefined' ||
        typeof navigator.vibrate !== 'function'
    )
        return;
    if (
        !session.gameStarted ||
        session.gamePaused ||
        session.inventoryOpen ||
        session.gameOver ||
        session.gameVictory
    )
        return;
    const now = performance.now();
    if (kind !== 'hurt' && now - lastImpact < 70) return;
    lastImpact = now;
    try {
        navigator.vibrate(kind === 'hurt' ? [22, 30, 22] : 8);
    } catch {
        /* Feedback must never interrupt combat. */
    }
}

window.addEventListener('blur', stopVibration);
document.addEventListener('visibilitychange', () => {
    if (document.hidden) stopVibration();
});
export { hapticImpact };
