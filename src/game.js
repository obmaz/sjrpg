import { updateCamera } from './core/canvas.js';
import { FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y, MAX_FRAME_DELTA } from './core/constants.js';
import { clamp, movePlayerTo, recordDiscovery } from './core/helpers.js';
import { player, session } from './core/state.js';
import { draw } from './render/scene.js';
import { initStartParticles } from './render/start-screen.js';
import { startBgMusic } from './systems/audio.js';
import { update } from './systems/simulation.js';
import { spawnEnemies, spawnInitialPickups } from './systems/spawning.js';
import { generateForestMap } from './systems/world.js';
import { updateHud } from './ui/hud.js';
import { addMessage } from './ui/messages.js';

// ============================================================
//  GAME LOGIC
// ============================================================

function gameLoop(time) {
    const deltaTime = clamp((time - session.lastTime) / 1000, 0, MAX_FRAME_DELTA);
    session.lastTime = time;
    update(deltaTime);
    if (session.gameStarted) draw();
    requestAnimationFrame(gameLoop);
}

// ============================================================
//  INIT
// ============================================================

// Controls toggle
function initializeUI() {
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

    // No initial aux weapon - obtain them through quests

    const seed = Math.floor(Math.random() * 100000);
    generateForestMap(seed);

    // Map generation guarantees a walkable arrival at the fountain.
    movePlayerTo(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);

    spawnEnemies();
    spawnInitialPickups();
    updateHud();
    updateCamera(player.x + player.w / 2, player.y + player.h / 2);

    addMessage('🗡️ 모험을 떠나세요!', 'info');
    addMessage('⛲ 맵 중앙 분수에서 체력 회복', 'info');
    addMessage('❗ NPC를 찾아 대화하세요 [E]', 'loot');
    addMessage('🎒 보조무기는 퀘스트 보상·상점에서 획득! (N/K 사용, Q 순환)', 'loot');
    addMessage('이동: WASD | 공격: Space/J | 보조: N/K | 순환: Q | 인벤: I/Esc', 'info');
    addMessage('📖 C: 도감 열기', 'info');

    // Auto-collect starter weapon
    recordDiscovery('weapons', 'fist');

    startBgMusic();
    session.lastTime = performance.now();
    requestAnimationFrame(gameLoop);
}

export { gameLoop, startGame };
