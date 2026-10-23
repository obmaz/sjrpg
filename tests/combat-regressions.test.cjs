const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

const openMap = `clearWorldEntities();
    tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));`;

test('fan knockback cannot cross a wall at the maximum simulation interval', async () => {
    const { run } = await loadGame();
    run(`${openMap}
        player.x = 520; player.y = 500; player.dir = 3;
        player.weapon = {...WEAPONS.find(w => w.id === 'fan')};
        tileMap[15][20] = TILE_KEYS.indexOf('WALL');
        tileMap[16][20] = TILE_KEYS.indexOf('WALL');
        const target = spawnEnemy(ENEMY_TYPES[0], 576, 500, 1, {randomizeSpeed: false});
        target.hp = 1000; target.speed = 0;
        attackWithWeapon();
        for (let i = 0; i < 10; i++) updateEnemies(0.1);`);
    assert.ok(run('target.x > 576 && target.x + target.w - 4 < 640'));
    assert.equal(run('collidesWithMap(target.x, target.y, target.w, target.h)'), false);
});

test('ranged strafing travels the same distance at different frame rates', async () => {
    const distances = [];
    for (const fps of [10, 30, 60, 120]) {
        const { run } = await loadGame();
        run(`${openMap}
            Math.random = () => 0.25;
            player.x = 1000; player.y = 1000;
            const target = spawnEnemy({...ENEMY_TYPES[0], ranged: true, speed: 20}, 1100, 1000, 1, {randomizeSpeed: false});
            for (let i = 0; i < ${fps}; i++) updateEnemies(1 / ${fps});`);
        assert.equal(run('target.state'), 'ranged');
        distances.push(run('Math.hypot(target.x - 1100, target.y - 1000)'));
    }
    for (const distance of distances) assert.ok(Math.abs(distance - 20) < 1e-8);
});

test('damage without stagger preserves attack state and existing recoil duration', async () => {
    const { run } = await loadGame();
    run(`${openMap}
        const target = spawnEnemy(ENEMY_TYPES[0], player.x + 100, player.y);
        target.hp = 100; target.state = 'ranged'; target.stateTimer = 2;
        damageEnemy(target, 4, false, {stagger: false});`);
    assert.equal(run('target.hp'), 96);
    assert.equal(run('target.state'), 'ranged');
    assert.equal(run('target.stateTimer'), 2);
    run(
        "target.state = 'hurt'; target.stateTimer = 0.1; damageEnemy(target, 4, false, {stagger: false});",
    );
    assert.equal(run('target.state'), 'hurt');
    assert.equal(run('target.stateTimer'), 0.1);
});

test('ranged direction changes use the same half-second intervals at different frame rates', async () => {
    for (const fps of [10, 30, 60, 120]) {
        const { run } = await loadGame();
        run(`${openMap}
            player.x = 1000; player.y = 1000;
            const target = spawnEnemy({...ENEMY_TYPES[0], ranged: true, speed: 20}, 1100, 1000, 1, {randomizeSpeed: false});
            let choices = 0;
            Math.random = () => choices++ % 2 === 0 ? 0.25 : 0.75;
            for (let i = 0; i < ${fps}; i++) updateEnemies(1 / ${fps});`);
        assert.equal(run('choices'), 2);
        assert.ok(run('Math.hypot(target.x - 1100, target.y - 1000)') < 1e-8);
    }
});

test('legend attacks into empty space cannot bank a combo finisher', async () => {
    const { run } = await loadGame();
    run(`${openMap}
        player.weapon = {...WEAPONS.find(w => w.id === 'legend')};
        for (let i = 0; i < 4; i++) attackWithWeapon();`);
    assert.equal(run('player.comboHits'), 0);
});

test('ranged weapon projectiles stop at the range declared by their weapon definition', async () => {
    for (const id of ['staff', 'crossbow', 'sandstorm', 'legend']) {
        const { run } = await loadGame();
        run(`${openMap}
            player.dir = 3;
            player.weapon = {...WEAPONS.find(w => w.id === '${id}')};
            const origin = getPlayerAttackOrigin();
            attackWithWeapon();
            const shot = projectiles[0];
            updateProjectiles(2);`);
        const travelled = run('Math.hypot(shot.x - origin.x, shot.y - origin.y)');
        const expected = run('player.weapon.projectileRange ?? player.weapon.range');
        assert.ok(Math.abs(travelled - expected) < 1e-8, id);
        assert.equal(run('projectiles.length'), 0);
    }
});

test('poison deaths do not skip another poisoned enemy or award duplicate kills', async () => {
    const { run } = await loadGame();
    run(`${openMap}
        for (let i = 0; i < 2; i++) {
            const target = spawnEnemy(ENEMY_TYPES[0], player.x + 200 + i * 100, player.y);
            target.hp = 1;
            target.enemyPoison = {damage: 4, remaining: 1, interval: 1, tick: 1};
        }
        updateEnemyPoisons(1);
        updateEnemyPoisons(1);`);
    assert.equal(run('player.kills'), 2);
    assert.equal(run('enemies.length'), 0);
});

test('poison cannot trigger a stage heal after player death', async () => {
    const { run } = await loadGame();
    run(`${openMap}
        player.kills = 4; player.hp = 0;
        const target = spawnEnemy(ENEMY_TYPES[0], player.x + 200, player.y);
        target.hp = 1;
        target.enemyPoison = {damage: 4, remaining: 1, interval: 1, tick: 1};
        updateEnemyPoisons(1);`);
    assert.equal(run('player.hp'), 0);
    assert.equal(run('player.kills'), 4);
    assert.equal(run('target.hp'), 1);
});
