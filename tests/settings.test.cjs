const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('fullscreen requests cannot overlap and controls recover after completion or rejection', async () => {
    const { run, elements } = await loadGame();
    run(`initializeSettings(); toggleSettings(); let requestCount=0; let finishFullscreen;
        document.documentElement.requestFullscreen=()=>{
            requestCount++;
            return new Promise(resolve => { finishFullscreen=resolve; });
        };`);
    const first = run('toggleFullscreen();');
    const second = run('toggleFullscreen();');
    assert.equal(run('requestCount'), 1);
    assert.equal(elements.get('settingsFullscreen').disabled, true);
    assert.equal(elements.get('fullscreenButton').disabled, true);
    run('document.fullscreenElement=document.documentElement; finishFullscreen();');
    await Promise.all([first, second]);
    assert.equal(elements.get('settingsFullscreen').disabled, false);
    assert.equal(elements.get('fullscreenButton').disabled, false);
    assert.match(elements.get('settingsFullscreen').textContent, /나가기/);
    run('document.exitFullscreen=()=>Promise.reject(new Error("denied"));');
    await run('toggleFullscreen();');
    assert.equal(elements.get('settingsFullscreen').disabled, false);
    assert.equal(run('session.settingsOpen && session.gamePaused'), true);
});

test('settings pause the game, release touch input, and close without opening another panel', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(
        'initializeTouchControls(); initializeSettings(); touchKeys.Space=true; performInputAction("KeyP"); updateTouchControls();',
    );
    assert.equal(run('session.settingsOpen && session.gamePaused'), true);
    assert.equal(run('isKeyDown("Space")'), false);
    elements.get('closeSettings').dispatchEvent({ type: 'click' });
    assert.equal(run('session.settingsOpen || session.gamePaused || session.inventoryOpen'), false);
});

test('settings cannot interrupt another panel or a slot machine', async () => {
    const { run } = await loadGame();
    run('session.gamePaused=true; session.slotMachineOpen=true; toggleSettings();');
    assert.equal(run('session.settingsOpen'), false);
    run('session.slotMachineOpen=false; session.inventoryOpen=true; toggleSettings();');
    assert.equal(run('session.settingsOpen'), false);
});

test('vibration preference stops feedback and saved preferences survive the next page', async () => {
    const storage = new Map();
    const vibration = [];
    const first = await loadGame({ storage, vibrate: (pattern) => vibration.push(pattern) });
    first.run('hapticImpact("hit"); setPreference("vibration",false); hapticImpact("hurt");');
    assert.deepEqual(vibration, [8, 0]);
    const second = await loadGame({ storage, vibrate: (pattern) => vibration.push(pattern) });
    assert.equal(second.run('preferences.vibration'), false);
    second.run('hapticImpact("hit");');
    assert.deepEqual(vibration, [8, 0]);
});

test('unavailable vibration and fullscreen are reported without crashing', async () => {
    const { run, elements } = await loadGame();
    run('initializeSettings(); toggleSettings();');
    assert.equal(elements.get('vibrationToggle').disabled, true);
    await run('toggleFullscreen();');
    assert.match(elements.get('settingsStatus').textContent, /지원/);
});

test('direct combat hits request haptics, while damage over time does not', async () => {
    const vibration = [];
    const { run } = await loadGame({ vibrate: (pattern) => vibration.push(pattern) });
    run(`const target={x:500,y:500,w:24,h:24,hp:100,maxHp:100}; enemies.push(target);
        damageEnemy(target,2,false); damageEnemy(target,2,false,{stagger:false});`);
    assert.deepEqual(vibration, [8]);
});

test('muted effects never create an audio context and fullscreen rejection leaves usable settings', async () => {
    const { run, elements } = await loadGame();
    run(`let audioAttempts=0; window.AudioContext=function(){audioAttempts++;throw new Error('unexpected audio');};
        setPreference('soundEffects',false); playSlashSound(); playHitSound();
        initializeSettings(); document.documentElement.requestFullscreen=()=>Promise.reject(new Error('denied'));`);
    assert.equal(run('audioAttempts'), 0);
    await run('toggleFullscreen();');
    assert.equal(run('session.settingsOpen && session.gamePaused'), true);
    assert.match(elements.get('settingsStatus').textContent, /전환하지 못/);
});
