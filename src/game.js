import { resizeCanvas, updateCamera } from './core/canvas.js';
import { FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y, MAX_FRAME_DELTA } from './core/constants.js';
import { clamp, movePlayerTo, recordDiscovery } from './core/helpers.js';
import { WEAPONS } from './data/weapons.js';
import { AUX_WEAPONS } from './data/aux-weapons.js';
import { updateTrailEncounters } from './systems/trail-encounters.js';
import { player, session } from './core/state.js';
import { draw } from './render/scene.js';
import { initStartParticles } from './render/start-screen.js';
import { startBgMusic } from './systems/audio.js';
import { update } from './systems/simulation.js';
import { spawnEnemies, spawnInitialPickups } from './systems/spawning.js';
import { generateForestMap } from './systems/world.js';
import { updateHud } from './ui/hud.js';
import { addMessage, updateEventBubbles } from './ui/messages.js';
import { initializeTouchControls, updateTouchControls } from './ui/touch-controls.js';
import { initializeSettings } from './ui/settings.js';
import { initializePopupLayout } from './ui/popup-layout.js';

// ============================================================
//  GAME LOGIC
// ============================================================

function gameLoop(time) {
    const deltaTime = clamp((time - session.lastTime) / 1000, 0, MAX_FRAME_DELTA);
    session.lastTime = time;
    update(deltaTime);
    updateTouchControls();
    if (session.gameStarted) draw();
    updateEventBubbles();
    requestAnimationFrame(gameLoop);
}

// ============================================================
//  INIT
// ============================================================

window.addEventListener('resize', () => {
    resizeCanvas();
    if (session.gameStarted) {
        updateCamera(player.x + player.w / 2, player.y + player.h / 2);
        draw();
        updateEventBubbles();
    }
});

// Controls toggle
function initializeUI() {
    initializePopupLayout();
    initializeSettings();
    initializeTouchControls();
    const toggle = document.getElementById('controlsToggle');
    const panel = document.getElementById('controls');
    if (toggle && panel) {
        toggle.addEventListener('click', () => {
            panel.classList.toggle('hidden');
            toggle.textContent = panel.classList.contains('hidden') ? '🎮 키 설명' : '🎮 접기';
        });
    }

    // Start particle animation
    initStartParticles();
    // Set up start button
    const startBtn = document.getElementById('startGameBtn');
    if (startBtn) {
        startBtn.addEventListener('click', () => startGame());
    }
}
if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', initializeUI, { once: true });
else initializeUI();

function startGame() {
    if (session.gameStarted) return;
    document.getElementById('startScreen').classList.add('hidden');
    session.gameStarted = true;
    updateTouchControls();

    // No initial aux weapon - obtain them through quests

    const seed = Math.floor(Math.random() * 100000);
    generateForestMap(seed);

    // Map generation guarantees a walkable arrival at the fountain.
    movePlayerTo(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y + 175);
    player.weapon = { ...WEAPONS.find((w) => w.id === 'iron') };
    player.auxWeapon = { ...AUX_WEAPONS.find((w) => w.id === 'shuriken') };
    player.auxWeapons = [player.auxWeapon];
    recordDiscovery('weapons', player.weapon.id);
    recordDiscovery('auxiliaryWeapons', player.auxWeapon.id);

    spawnEnemies();
    spawnInitialPickups();
    session.trailEncounterTimer = 0;
    session.trailEncountersEnabled = true;
    updateTrailEncounters(0);
    updateHud();
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);

    addMessage('⚔️ 숲길을 따라 전진하세요. 공격을 누르면 연속으로 벱니다.', 'info');

    // Auto-collect starter weapon
    recordDiscovery('weapons', 'fist');

    startBgMusic();
    session.lastTime = performance.now();
    requestAnimationFrame(gameLoop);
}

export { gameLoop, startGame };
