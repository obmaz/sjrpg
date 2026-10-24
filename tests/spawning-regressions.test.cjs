const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('desert travel creates one Pharaoh across map seeds and stages', async () => {
    const { run } = await loadGame();
    for (const stage of [4, 8]) {
        for (const seed of [1, 2, 3, 42, 123, 999, 12345, 54321]) {
            run(`randomSeed = ${seed}; player.stage = ${stage};
                player.currentRegion = 'forest'; travelToDesert();`);
            assert.equal(
                run("enemies.filter(enemy => enemy.name === '파라오').length"),
                1,
                `Stage ${stage}, random seed ${seed}`,
            );
            assert.equal(
                run(`enemies.some(enemy => enemy.name === '파라오' &&
                    (collidesWithMap(enemy.x, enemy.y, enemy.w, enemy.h) ||
                    collidesWithEntities(enemy.x, enemy.y, enemy.w, enemy.h, enemy)))`),
                false,
            );
        }
    }
});

test('desert maps provide a distant boss position reachable by its entire body', async () => {
    const { run } = await loadGame();
    for (const seed of [50001, 50002, 50003, 50004, 50005, 50009, 99999, 149999]) {
        run(`clearWorldEntities(); generateDesertMap(${seed});
            player.currentRegion = 'desert'; player.x = FOUNTAIN_CENTER_X;
            player.y = FOUNTAIN_CENTER_Y; spawnDesertEnemies();`);
        assert.equal(
            run(`enemies.some(enemy => enemy.name === '파라오' &&
                distance(enemy.x, enemy.y, player.x, player.y) >= 500 &&
                isReachableFromArrival(enemy.x, enemy.y, enemy.w, enemy.h))`),
            true,
            `Map seed ${seed}`,
        );
    }
});

test('an impossible boss spawn does not announce a Pharaoh that does not exist', async () => {
    const { run, elements } = await loadGame();
    run(`clearWorldEntities();
        tileMap = Array.from({length: MAP_HEIGHT}, () =>
            Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        for (let y = 29; y <= 31; y++) for (let x = 39; x <= 41; x++)
            tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        tileMap[10][10] = TILE_KEYS.indexOf('SAND');
        spawnDesertEnemies();`);
    assert.equal(run("enemies.filter(enemy => enemy.name === '파라오').length"), 0);
    assert.equal(
        elements
            .get('eventBubbles')
            ?.children.some((message) => message.textContent?.includes('파라오 등장')) || false,
        false,
    );
});
