const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('desert travel leaves a walkable arrival connected to dry land and clears forest dummies', () => {
    const { run } = loadGame();
    run('scarecrows.push({x: 1}); travelToDesert();');
    assert.equal(run('scarecrows.length'), 0);
    assert.equal(run('collidesWithMap(player.x, player.y, player.w, player.h)'), false);
    assert.equal(run('isSolidTile(45, 30)'), false);
    assert.ok(run('tileMap.flat().filter(t => !TILE_TYPES[TILE_KEYS[t]].solid).length') > 100);
});

test('combat actions cannot spend items or auxiliary uses while paused or in inventory', () => {
    for (const state of [
        'gamePaused = true',
        'inventoryOpen = true',
        'gameStarted = false',
        'gameOver = true',
        'gameVictory = true',
    ]) {
        const { run } = loadGame();
        run(`player.hp = 20; player.items.push({...ITEMS[0]});
            player.auxWeapon = {...AUX_WEAPONS.find(a => a.id === 'healpot')};
            player.auxWeapons.push(player.auxWeapon); ${state}; useConsumable(0); useAuxWeapon();`);
        assert.equal(run('player.hp'), 20, state);
        assert.equal(run('player.items.length'), 1, state);
        assert.equal(run('player.auxWeapon.uses'), 4, state);
    }
});

test('Escape closes inventory without opening another panel and repeated toggles are ignored', () => {
    const { run, listeners } = loadGame();
    const event = { code: 'KeyI', key: 'i', preventDefault() {} };
    listeners.keydown(event);
    listeners.keydown({ ...event, repeat: true });
    assert.equal(run('inventoryOpen'), true);
    listeners.keydown({ code: 'Escape', key: 'Escape', preventDefault() {} });
    assert.equal(run('inventoryOpen'), false);
});

test('slot machine stays paused when Escape, E, I or C is pressed', () => {
    const { run, listeners } = loadGame();
    run('player.gold = 100; useSlotMachine();');
    for (const [code, key] of [
        ['Escape', 'Escape'],
        ['KeyE', 'e'],
        ['KeyI', 'i'],
        ['KeyC', 'c'],
    ]) {
        listeners.keydown({ code, key, preventDefault() {} });
        assert.equal(run('gamePaused'), true, code);
        assert.equal(run('compendiumOpen || inventoryOpen'), false, code);
    }
});

test('opening compendium over a dialog does not release the dialog pause', () => {
    const { run } = loadGame();
    run('gamePaused = true; toggleCompendium();');
    assert.equal(run('compendiumOpen'), false);
    assert.equal(run('gamePaused'), true);
});

test('weapon final use still launches its attack before switching to fists', () => {
    const { run } = loadGame();
    run("player.weapon = {...WEAPONS.find(w => w.id === 'legend'), uses: 1}; attackWithWeapon();");
    assert.equal(run('projectiles.length'), 1);
    assert.equal(run('fireZones.length'), 1);
    assert.equal(run('player.weapon.id'), 'fist');
});

test('fountain cannot bank healing ticks at full HP', () => {
    const { run } = loadGame();
    run(
        'player.x = FOUNTAIN_CENTER_X; player.y = FOUNTAIN_CENTER_Y; player.gold = 100; for (let i = 0; i < 50; i++) update(0.1); player.hp = 50; update(0.1);',
    );
    assert.equal(run('player.hp'), 50);
    run('for (let i = 0; i < 10; i++) update(0.1);');
    assert.equal(run('player.hp'), 53);
});

test('portal opens when gold reaches the threshold after the boss was killed', () => {
    const { run } = loadGame();
    run('player.bossKilled = true; player.gold = 1000; update(0.01);');
    assert.equal(run('portals.length'), 1);
    run('update(0.01);');
    assert.equal(run('portals.length'), 1);
});

test('stopped slot reels retain their result while other reels spin', () => {
    const { run, timers, elements } = loadGame();
    run('player.gold = 100; useSlotMachine();');
    const cycle = timers.find((t) => t.interval);
    timers.find((t) => t.delay === 800).cb();
    const symbol = elements.get('reel1').textContent;
    for (let i = 0; i < 12; i++) {
        cycle.cb();
        assert.equal(elements.get('reel1').textContent, symbol);
    }
});

test('focus loss releases held movement keys', () => {
    const { run, listeners } = loadGame();
    listeners.keydown({ code: 'KeyW', key: 'w', preventDefault() {} });
    assert.equal(run('keys.KeyW'), true);
    listeners.blur?.();
    assert.equal(run('Boolean(keys.KeyW || keys.w)'), false);
});

test('lethal damage near fountain ends the game before healing can resurrect the player', () => {
    const { run } = loadGame();
    run(
        'player.x = FOUNTAIN_CENTER_X; player.y = FOUNTAIN_CENTER_Y; player.hp = 1; player.gold = 100; player.fountainTimer = 1; spawnEnemyProjectile(player.x + player.w / 2, player.y + player.h / 2, 0, 0, 2, "red"); update(0.01);',
    );
    assert.equal(run('gameOver'), true);
    assert.equal(run('player.hp'), -1);
});

test('one attack damages a chest once, regardless of frame count', () => {
    const { run } = loadGame();
    run(
        'const origin = getPlayerAttackOrigin(); chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 10}); attackWithWeapon(); for (let i = 0; i < 8; i++) { updateChests(0.01); player.attackTimer -= 0.01; }',
    );
    assert.equal(run('chests[0].hp'), 9);
    run('player.attackTimer = 0; attackWithWeapon(); updateChests(0.01);');
    assert.equal(run('chests[0].hp'), 8);
});

test('ground weapons remain available when inventory is full', () => {
    const { run } = loadGame();
    run(
        'for (let i = 0; i < 12; i++) inventory.push({...WEAPONS[1]}); weaponPickups.push({x: player.x + player.w / 2, y: player.y + player.h / 2, weapon: WEAPONS[2], life: 10}); updateWeaponPickups(0.01);',
    );
    assert.equal(run('weaponPickups.length'), 1);
    run('inventory.pop(); updateWeaponPickups(0.01);');
    assert.equal(run('weaponPickups.length'), 0);
    assert.equal(run('inventory[11].id'), 'iron');
});

test('boat dismount lands on the nearby shore and leaves the boat on water', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        for (let y = 20; y < 25; y++) for (let x = 21; x < 25; x++) tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        player.x = 19.5 * TILE_SIZE; player.y = 20 * TILE_SIZE;
        spawnMount(MOUNT_TYPES.find(m => m.waterOnly), player.x, player.y); player.mount = mounts.pop(); dismountPlayer();`);
    assert.equal(run('player.mount'), null);
    assert.equal(run('collidesWithMap(player.x, player.y, player.w, player.h)'), false);
    assert.ok(run('distance(player.x, player.y, 19.5 * TILE_SIZE, 20 * TILE_SIZE)') <= 64);
    assert.equal(run('mounts[0].x'), 19.5 * 32);
    assert.equal(run('mounts[0].y'), 20 * 32);
    run('updatePlayer(0.01);');
    assert.equal(run('player.mount'), null);
});

test('desert generation retains dry terrain across multiple seeds', () => {
    const { run } = loadGame();
    for (const seed of [1, 42, 999, 50000, 150000]) {
        run(`generateDesertMap(${seed});`);
        assert.equal(
            run('collidesWithMap(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y, player.w, player.h)'),
            false,
        );
        assert.ok(
            run('tileMap.flat().filter(t => !TILE_TYPES[TILE_KEYS[t]].solid).length') > 100,
            `seed ${seed}`,
        );
    }
});

test('both regions run movement, combat and rendering without runtime errors', () => {
    const { run } = loadGame();
    run(
        'gameStarted = false; startGame(); keys.KeyD = true; keys.Space = true; for (let i = 0; i < 120; i++) { update(1 / 60); draw(); }',
    );
    assert.equal(run('Number.isFinite(player.x) && Number.isFinite(player.hp)'), true);
    run('travelToDesert(); for (let i = 0; i < 120; i++) { update(1 / 60); draw(); }');
    assert.equal(run('Number.isFinite(player.x) && Number.isFinite(player.hp)'), true);
});

test('spawn search never returns an invalid last random candidate', () => {
    const { run } = loadGame();
    assert.equal(run('findSpawnTile(3, () => false, 1)'), null);
    const position = run('findSpawnTile(3, (x, y) => x === 7 && y === 8, 0)');
    assert.equal(Math.floor(position.x), 7);
    assert.equal(Math.floor(position.y), 8);
});

test('hurt enemies cannot attack before their recovery timer expires', () => {
    const { run } = loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 15, player.y); enemies[0].x = player.x + 15; enemies[0].y = player.y; damageEnemy(enemies[0], 1, false); updateEnemies(0.01);',
    );
    assert.equal(run('player.hp'), 100);
    assert.equal(run('enemies[0].state'), 'hurt');
});

test('wander timers advance once per frame and boss projectiles use their configured damage', () => {
    const { run } = loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 500, player.y); enemies[0].stateTimer = 1; updateEnemies(0.1);',
    );
    assert.equal(run('enemies[0].stateTimer'), 0.9);
    run(
        'enemies.length = 0; spawnBoss(BOSS_TYPES[0], player.x + player.w + 60, player.y - 86); enemies[0].rangeAttackCd = 0; updateEnemies(0.01);',
    );
    assert.equal(run('enemyProjectiles[0].dmg'), run('BOSS_TYPES[0].rangeDmg'));
});

test('damaging an already dead enemy cannot award a second kill', () => {
    const { run } = loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 300, player.y); const enemy = enemies[0]; damageEnemy(enemy, 999); damageEnemy(enemy, 999);',
    );
    assert.equal(run('player.kills'), 1);
});

test('snake attacks apply their configured poison damage', () => {
    const { run } = loadGame();
    run(
        'spawnEnemy(DESERT_ENEMY_TYPES.find(e => e.poison), player.x + 15, player.y); enemies[0].x = player.x + 15; enemies[0].y = player.y; updateEnemies(0.01);',
    );
    assert.ok(run('player.poisonTimer') > 0);
    assert.equal(run('player.poisonDamage'), 3);
});

test('quests recognize a boss killed before quest acceptance and reject duplicate acceptance', () => {
    const { run } = loadGame();
    run(
        "player.stage = 3; spawnBoss(BOSS_TYPES[0], player.x + 500, player.y); damageEnemy(enemies[0], 99999); acceptQuest(getQuest('slay_boss')); acceptQuest(getQuest('slay_boss')); updateQuestProgress();",
    );
    assert.equal(run("player.completedQuests.includes('slay_boss')"), true);
    assert.equal(run('player.activeQuests.length'), 0);
});

test('completing forest quests allows the desert adventure to continue', () => {
    const { run } = loadGame();
    run('player.completedQuests.push(...MAIN_QUESTS); updateQuestProgress();');
    assert.equal(run('gameVictory'), false);
    run(
        'player.currentRegion = "desert"; player.completedQuests.push(...DESERT_QUESTS); updateQuestProgress();',
    );
    assert.equal(run('gameVictory'), true);
});

test('boomerang returns on game time and does not cross region changes', () => {
    const { run, timers } = loadGame();
    run(
        "throwBoomerang(AUX_WEAPONS.find(a => a.id === 'boomerang'), getPlayerAttackOrigin()); gamePaused = true;",
    );
    timers.filter((timer) => timer.delay === 350).forEach((timer) => timer.cb());
    assert.equal(run('projectiles.length'), 1);
    run('gamePaused = false; update(0.1); update(0.1); update(0.1); update(0.1);');
    assert.equal(run('projectiles.length'), 2);
    run(
        "throwBoomerang(AUX_WEAPONS.find(a => a.id === 'boomerang'), getPlayerAttackOrigin()); travelToDesert(); update(0.1); update(0.1); update(0.1); update(0.1);",
    );
    assert.equal(run('projectiles.length'), 0);
});

test('random teleport checks the complete player footprint and dismounts on fallback', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        tileMap[3][3] = TILE_KEYS.indexOf('SAND');
        for (let y = 29; y <= 31; y++) for (let x = 39; x <= 41; x++) tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        Math.random = () => 0; player.mount = {...MOUNT_TYPES[0]}; randomTeleport();`);
    assert.equal(run('collidesWithMap(player.x, player.y, player.w, player.h)'), false);
    assert.equal(run('player.mount'), null);
});

test('enemy spawns validate their entire body and never overlap existing entities', () => {
    const { run } = loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x, player.y); spawnEnemy(ENEMY_TYPES[0], enemies[0].x, enemies[0].y);',
    );
    assert.equal(
        run(
            'enemies.some(enemy => collidesWithMap(enemy.x, enemy.y, enemy.w, enemy.h) || collidesWithEntities(enemy.x, enemy.y, enemy.w, enemy.h, enemy))',
        ),
        false,
    );
    run(
        "tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));",
    );
    assert.equal(run('spawnEnemy(ENEMY_TYPES[0], 300, 300)'), null);
});

test('shop purchases share capacity checks and copy definitions rather than mutating them', () => {
    const { run } = loadGame();
    run(
        "player.gold = 1000; openShop('village'); buyShopItem(WEAPONS[1], 50, false); buyShopItem(ITEMS[0], 30, true);",
    );
    assert.equal(run('player.gold'), 920);
    assert.equal(run('inventory.length'), 1);
    assert.equal(run('player.items.length'), 1);
    assert.equal(run('inventory[0] === WEAPONS[1] || player.items[0] === ITEMS[0]'), false);
    run(
        'for (let i = 1; i < CONSUMABLE_CAPACITY; i++) player.items.push({...ITEMS[0]}); buyShopItem(ITEMS[0], 30, true);',
    );
    assert.equal(run('player.gold'), 920);
});

test('consumed auxiliary weapons stay discovered and desert HUD shows desert quest progress', () => {
    const { run, elements } = loadGame();
    run(
        "player.collection.auxiliaryWeapons.push('firebomb'); renderCompendium(); player.currentRegion = 'desert'; player.completedQuests.push('collect_1000gold'); updateHud();",
    );
    assert.ok(
        elements.get('compendiumGrid').children.some((card) => card.title?.includes('화염병')),
    );
    assert.equal(elements.get('clearProgress').textContent, '📜 주요 퀘스트: 1 / 2');
});

test('content IDs, drop pools, spawn indices and quest rewards refer to existing definitions', () => {
    const { run } = loadGame();
    assert.equal(
        run(
            '[WEAPONS, AUX_WEAPONS, ITEMS, BOSS_TYPES, QUESTS].every(definitions => new Set(definitions.map(definition => definition.id)).size === definitions.length)',
        ),
        true,
    );
    assert.equal(
        run(
            '[...ENEMY_TYPES, ...DESERT_ENEMY_TYPES].every(enemy => enemy.dropPool.every(id => WEAPONS.some(weapon => weapon.id === id)))',
        ),
        true,
    );
    assert.equal(
        run(
            'CHEST_TYPES.every(chest => chest.dropWeapons.every(id => WEAPONS.some(weapon => weapon.id === id)))',
        ),
        true,
    );
    assert.equal(
        run(
            'QUESTS.every(quest => !quest.rewardAux || AUX_WEAPONS.some(weapon => weapon.id === quest.rewardAux))',
        ),
        true,
    );
    assert.equal(
        run(
            'Object.entries(SPAWN_RULES).every(([region, rules]) => [...rules.bands.flatMap(band => band.types), ...rules.wildcard.types].every(index => (region === "desert" ? DESERT_ENEMY_TYPES : ENEMY_TYPES)[index] != null))',
        ),
        true,
    );
});

test('one-way travel releases unfinished forest quests while preserving global quests and rewards', () => {
    const { run } = loadGame();
    run(`player.stage = 5;
        player.completedQuests.push('collect_coins');
        player.activeQuests = ['hunt_wolves', 'hunt_eagles', 'collect_1000gold'].map(id => ({id, progress: 0}));
        travelToDesert(); acceptQuest(getQuest('slay_pharaoh'));`);
    assert.equal(
        run('player.activeQuests.map(q => q.id).join(",")'),
        'collect_1000gold,slay_pharaoh',
    );
    assert.equal(run('player.completedQuests.includes("collect_coins")'), true);
    assert.equal(run('player.completedQuests.includes("hunt_wolves")'), false);
});

test('repeated desert travel cannot regenerate the world or discard desert progress', () => {
    const { run } = loadGame();
    run('travelToDesert(); player.x += 10;');
    const firstEnemy = run('enemies[0]');
    const arrivalX = run('player.x');
    run('travelToDesert();');
    assert.equal(run('enemies[0]'), firstEnemy);
    assert.equal(run('player.x'), arrivalX);
});

test('large melee enemies attack when their body reaches the player', () => {
    for (const definition of [
        "ENEMY_TYPES.find(e => e.name === '트롤')",
        "ENEMY_TYPES.find(e => e.name === '거대 슬라임')",
        "DESERT_ENEMY_TYPES.find(e => e.name === '사막 트롤')",
        'BOSS_TYPES[3]',
    ]) {
        const { run } = loadGame();
        run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
            const enemy = spawnEnemy({...${definition}, isBoss: ${definition.startsWith('BOSS')}, megaBoss: ${definition.startsWith('BOSS')}}, player.x + player.w + 1, player.y);
            enemy.y = player.y + (player.h - enemy.h) / 2;
            updateEnemies(0.01);`);
        assert.ok(run('player.hp') < 100, definition);
        assert.equal(run('enemies[0].state'), 'attack', definition);
    }
});

test('boarding from shore places the player on the boat and permits sailing', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        for (let y = 0; y < MAP_HEIGHT; y++) for (let x = 21; x < MAP_WIDTH; x++) tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        player.x = 21 * TILE_SIZE; player.y = 20 * TILE_SIZE;
        spawnMount(MOUNT_TYPES.find(m => m.waterOnly), 19.5 * TILE_SIZE, player.y);
        updatePlayer(0.01);`);
    assert.equal(run('player.mount.id'), 'boat');
    assert.equal(run('player.x'), 19.5 * 32);
    run('keys.KeyA = true; updatePlayer(0.05);');
    assert.ok(run('player.x') < 19.5 * 32);
    run('keys.KeyA = false; keys.KeyD = true; updatePlayer(0.1);');
    assert.ok(run('player.x + player.mount.w') <= 21 * 32);
});

test('land mounts spawn with their entire body clear of terrain and entities', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        tileMap[10][11] = TILE_KEYS.indexOf('ROCK');
        spawnMount(MOUNT_TYPES[0], 10 * TILE_SIZE, 10 * TILE_SIZE);`);
    assert.equal(run('mounts.length'), 1);
    assert.equal(run('collidesWithMap(mounts[0].x, mounts[0].y, mounts[0].w, mounts[0].h)'), false);
});

test('a lethal trap chest cannot be followed by healing loot in the same frame', () => {
    const { run } = loadGame();
    run(`const origin = getPlayerAttackOrigin(); player.hp = 10; Math.random = () => 0.99;
        chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1, type: 'normal', chestData: CHEST_TYPES[0]});
        chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1, type: 'trap', chestData: CHEST_TYPES[0]});
        attackWithWeapon(); update(0.01);`);
    assert.equal(run('gameOver'), true);
    assert.ok(run('player.hp') <= 0);
    assert.equal(run('chests.length'), 1);
});

test('fast projectiles hit small enemies crossed between frames', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 300, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), 12);
    assert.equal(run('projectiles.length'), 0);
});

test('projectiles stop at a crossed wall before damaging an enemy behind it', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        tileMap[9][10] = TILE_KEYS.indexOf('WALL'); spawnEnemy(ENEMY_TYPES[0], 358, 300);
        spawnProjectile(305, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);
        player.x = 358; player.y = 300;
        spawnEnemyProjectile(305, 310, 500, 0, 3, 'red'); updateEnemyProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), 15);
    assert.equal(run('player.hp'), 100);
    assert.equal(run('projectiles.length + enemyProjectiles.length'), 0);
});

test('projectiles hit the first enemy along the path regardless of array order', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 328, 300); spawnEnemy(ENEMY_TYPES[0], 300, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), 15);
    assert.equal(run('enemies[1].hp'), 12);
});

test('expiring projectiles cannot damage targets beyond their remaining flight time', () => {
    const { run } = loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 325, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); projectiles[0].life = 0.01;
        updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), 15);
    assert.equal(run('projectiles.length'), 0);
});

test('guaranteed boss weapon drops remain collectible when inventory is full', () => {
    const { run } = loadGame();
    run(`for (let i = 0; i < INVENTORY_CAPACITY; i++) inventory.push({...WEAPONS[1]});
        const boss = spawnBoss(BOSS_TYPES[0], player.x + 500, player.y);
        damageEnemy(boss, 99999);`);
    assert.equal(run('weaponPickups.length'), 1);
    assert.equal(run('weaponPickups[0].weapon.id'), 'legend');
    assert.equal(run('inventory.length'), 12);
    run(`inventory.pop(); player.x = weaponPickups[0].x - player.w / 2;
        player.y = weaponPickups[0].y - player.h / 2; updateWeaponPickups(0.01);`);
    assert.equal(run('weaponPickups.length'), 0);
    assert.equal(run('inventory[11].id'), 'legend');
});

test('resizing a paused game redraws the scene without advancing simulation time', () => {
    const { run, listeners, elements } = loadGame();
    run('gamePaused = true; let drawCount = 0; draw = () => { drawCount++; };');
    const gameTime = run('player.gameTime');
    elements.get('gameArea').clientWidth = 640;
    elements.get('gameArea').clientHeight = 480;
    listeners.resize();
    assert.equal(run('drawCount'), 1);
    assert.equal(run('player.gameTime'), gameTime);
    assert.equal(run('camera.x'), run('player.x + player.w / 2 - 320'));
});

test('travel awards already achieved quest rewards before abandoning remaining forest quests', () => {
    const { run } = loadGame();
    run(`player.stage = 5; player.killsByName['늑대'] = 5;
        player.activeQuests.push({id:'hunt_wolves', progress:0}); travelToDesert();`);
    assert.equal(run('player.completedQuests.includes("hunt_wolves")'), true);
    assert.equal(run('player.auxWeapons[0].id'), 'boomerang');
    assert.equal(run('player.gold'), 40);
});

test('chests and all village NPCs fit on walkable terrain across map seeds', () => {
    const { run } = loadGame();
    for (const seed of [0, 1, 42, 123, 999, 50000, 99999]) {
        run(
            `clearWorldEntities(); generateForestMap(${seed}); spawnEnemies(); spawnInitialPickups();`,
        );
        assert.equal(run('npcs.length'), 8, `NPC count for seed ${seed}`);
        assert.equal(run('chests.length'), 5, `chest count for seed ${seed}`);
        assert.equal(
            run(
                '[...chests, ...npcs].some(entity => collidesWithMap(entity.x, entity.y, entity.w, entity.h))',
            ),
            false,
            `seed ${seed}`,
        );
    }
    run(
        "clearWorldEntities(); tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));",
    );
    assert.equal(run("spawnChest(300, 300, 'wooden')"), null);
    assert.equal(run('spawnNpc({x:300, y:300, w:64, h:64})'), null);
});

test('desert stage progression cannot introduce forest quest NPCs', () => {
    const { run } = loadGame();
    run(
        'travelToDesert(); player.kills = 4; const enemy = enemies.find(e => !e.isBoss); damageEnemy(enemy, 99999);',
    );
    assert.equal(run("npcs.some(n => n.name === '경비대장')"), false);
    assert.equal(run('player.stage'), 2);
});

test('compendium totals include every displayed boss definition', () => {
    const { run, elements } = loadGame();
    run(
        'player.collection.enemies = [...new Set([...ENEMY_TYPES, ...DESERT_ENEMY_TYPES, ...BOSS_TYPES].map(e => e.name))]; renderCompendium();',
    );
    const total = run('player.collection.enemies.length');
    assert.ok(elements.get('compendiumStats').textContent.endsWith(`적 ${total}/${total}`));
});

test('poison cannot tick after its remaining duration, but ticks at the expiry boundary', () => {
    const { run } = loadGame();
    run(
        'player.poisonTimer = 0.01; player.poisonTick = 0.05; player.poisonDamage = 3; update(0.1);',
    );
    assert.equal(run('player.hp'), 100);
    assert.equal(run('player.poisonTimer'), 0);
    run(
        'player.poisonTimer = 0.05; player.poisonTick = 0.05; player.poisonDamage = 3; update(0.1);',
    );
    assert.equal(run('player.hp'), 97);
});

test('dead players cannot consume healing items or recover from an attack stage-up', () => {
    const { run } = loadGame();
    run(
        'player.hp = 0; player.kills = 4; player.items.push({...ITEMS[0]}); useConsumable(0); keys.Space = true; update(0.01);',
    );
    assert.equal(run('player.hp'), 0);
    assert.equal(run('player.items.length'), 1);
    assert.equal(run('gameOver'), true);
});

test('full-inventory slot jackpot reports gold conversion in the modal and log', () => {
    const { run, timers, elements } = loadGame();
    run(
        'player.gold = 100; for (let i = 0; i < INVENTORY_CAPACITY; i++) inventory.push({...WEAPONS[1]}); Math.random = () => 0.99; useSlotMachine();',
    );
    timers.find((t) => t.delay === 1600).cb();
    assert.equal(run('player.gold'), 150);
    assert.equal(run('inventory.length'), 12);
    assert.ok(elements.get('slotResult').textContent.includes('대신 100골드'));
    assert.ok(elements.get('messageLog').children.at(-1).textContent.includes('대신 100골드'));
});

test('simulation can advance independently and frame loop draws paused and terminal states', () => {
    const { run } = loadGame();
    run('let drawCount = 0; draw = () => { drawCount++; }; update(0.01);');
    assert.equal(run('drawCount'), 0);
    run('gamePaused = true; gameLoop(10); gameOver = true; gameLoop(20);');
    assert.equal(run('drawCount'), 2);
});
