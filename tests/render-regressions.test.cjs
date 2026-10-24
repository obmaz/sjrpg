const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('rendering fountain and fog never creates particles or consumes gameplay randomness', async () => {
    const { run } = await loadGame();
    run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
        player.hp = 50; player.gold = 100; player.visionReduction = 10;
        particles.push({x: player.x, y: player.y, vx: 1, vy: 1,
            life: 0.4, maxLife: 0.5, color: '#fff', size: 2});
        Math.random = () => { throw new Error('render consumed gameplay randomness'); };`);
    const before = run('JSON.stringify(particles)');
    for (const state of [
        'session.gamePaused = true',
        'session.gamePaused = false; session.inventoryOpen = true',
        'session.inventoryOpen = false; session.gameOver = true',
        'session.gameOver = false; session.gameVictory = true',
    ]) {
        run(`${state}; for (let i = 0; i < 30; i++) draw();`);
        assert.equal(run('JSON.stringify(particles)'), before, state);
    }
});

test('environmental emission density follows game time across 30, 60 and 120 FPS', async () => {
    for (const fps of [10, 30, 60, 120]) {
        const { run } = await loadGame();
        run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
            player.hp = 50; player.gold = 100; player.visionReduction = 10;
            Math.random = () => 0.1;
            for (let i = 0; i < ${fps}; i++) emitEnvironmentalParticles(1 / ${fps});`);
        assert.equal(run('particles.length'), 240, `${fps} FPS`);
        assert.equal(run("particles.filter(p => p.color === '#88ccff').length"), 120);
        assert.equal(run("particles.filter(p => p.color === '#ffaa66').length"), 60);
        assert.equal(run("particles.filter(p => p.color === '#334466').length"), 60);
    }
});

test('environmental emissions stop for paused, inventory and terminal simulations', async () => {
    const { run } = await loadGame();
    run(`updateCamera(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
        Math.random = () => 0.1; update(1 / 60);`);
    assert.ok(run('particles.length') > 0);
    const before = run('JSON.stringify(particles)');
    for (const state of [
        'session.gamePaused = true',
        'session.gamePaused = false; session.inventoryOpen = true',
        'session.inventoryOpen = false; session.gameOver = true',
        'session.gameOver = false; session.gameVictory = true',
    ]) {
        run(`${state}; update(0.1); emitEnvironmentalParticles(0.1);`);
        assert.equal(run('JSON.stringify(particles)'), before, state);
    }
});

test('HUD displays poison together with speed and removes each status independently', async () => {
    const { run, elements } = await loadGame();
    run('player.speedBoost = 10; player.poisonTimer = 240; updateHud();');
    const status = elements.get('poisonDisplay');
    assert.match(status.textContent, /스피드 10\.0s/);
    assert.match(status.textContent, /독 4:00/);
    assert.equal(elements.get('hudCenter').style.display, 'flex');
    run('player.speedBoost = 0; updateHud();');
    assert.equal(status.textContent, '☠️ 독 4:00');
    assert.equal(status.style.display, 'block');
    run('player.poisonTimer = 0; updateHud();');
    assert.equal(status.style.display, 'none');
    assert.equal(elements.get('hudCenter').style.display, 'none');
});

test('unchanged HUD output skips content, style and class mutations', async () => {
    const { run, elements } = await loadGame();
    run('updateHud();');
    let mutations = 0;
    const countAssignments = (target, property) => {
        let value = target[property];
        Object.defineProperty(target, property, {
            configurable: true,
            get: () => value,
            set(next) {
                mutations++;
                value = next;
            },
        });
    };
    for (const element of elements.values()) {
        for (const property of ['innerHTML', 'textContent']) countAssignments(element, property);
        for (const property of Object.keys(element.style))
            countAssignments(element.style, property);
        const toggle = element.classList.toggle.bind(element.classList);
        element.classList.toggle = (...args) => {
            mutations++;
            return toggle(...args);
        };
    }
    run('for (let i = 0; i < 10; i++) updateHud();');
    assert.equal(mutations, 0);
    run('player.gold++; updateHud();');
    assert.equal(mutations, 1);
    assert.equal(elements.get('goldDisplay').textContent, '💰 1');
});

test('HUD can restore the same auxiliary weapon after showing an empty slot', async () => {
    const { run, elements } = await loadGame();
    run('player.auxWeapon = {...AUX_WEAPONS[0]}; updateHud();');
    const auxiliary = elements.get('auxDisplay');
    let htmlWrites = 0;
    Object.defineProperty(auxiliary, 'innerHTML', {
        configurable: true,
        get: () => '',
        set() {
            htmlWrites++;
        },
    });
    run(
        'player.auxWeapon = null; updateHud(); player.auxWeapon = {...AUX_WEAPONS[0]}; updateHud();',
    );
    assert.equal(htmlWrites, 1);
});
