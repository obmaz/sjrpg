'use strict';

// ============================================================
//  GAME LOGIC
// ============================================================

function gameLoop(time) {
    const deltaTime = clamp((time - lastTime) / 1000, 0, MAX_FRAME_DELTA);
    lastTime = time;
    update(deltaTime);
    if (gameStarted) draw();
    requestAnimationFrame(gameLoop);
}

// ============================================================
//  INIT
// ============================================================

// Controls toggle
document.addEventListener('DOMContentLoaded', () => {
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
});

function startGame() {
    if (gameStarted) return;
    document.getElementById('startScreen').classList.add('hidden');
    gameStarted = true;

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
    addMessage('🎒 보조무기는 퀘스트 보상으로 획득! (N/K 사용, Q 순환)', 'loot');
    addMessage('이동: WASD | 공격: Space/J | 보조: N/K | 순환: Q | 인벤: I/Esc', 'info');
    addMessage('📖 C: 도감 열기', 'info');

    // Auto-collect starter weapon
    recordDiscovery('weapons', 'fist');

    startBgMusic();
    lastTime = performance.now();
    requestAnimationFrame(gameLoop);
}
