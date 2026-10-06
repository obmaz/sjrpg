import { player, session } from '../core/state.js';
import { updateHud } from './hud.js';
import { addMessage } from './messages.js';

// ============================================================
//  APPEARANCE PANEL (외관 변경)
// ============================================================
function openAppearancePanel() {
    session.gamePaused = true;
    const panel = document.getElementById('appearancePanel');
    panel.classList.remove('hidden');

    // Highlight current face
    const options = panel.querySelectorAll('.appearance-option');
    options.forEach((opt) => {
        opt.classList.toggle('selected', opt.dataset.face === player.playerFace);
    });

    // Set up click handlers
    options.forEach((opt) => {
        opt.onclick = () => {
            player.playerFace = opt.dataset.face;
            options.forEach((o) =>
                o.classList.toggle('selected', o.dataset.face === player.playerFace),
            );
            updateHud();
            addMessage(`🎭 외관이 변경되었습니다!`, 'loot');
        };
    });

    // Close via overlay click
    panel.onclick = (e) => {
        if (e.target === panel) closeAppearancePanel();
    };
}

function closeAppearancePanel() {
    session.gamePaused = false;
    document.getElementById('appearancePanel').classList.add('hidden');
}

export { openAppearancePanel, closeAppearancePanel };
