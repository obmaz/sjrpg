const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('the real title initialization wires the start button on mobile and desktop', async () => {
    for (const coarsePointer of [true, false]) {
        const { run, elements, documentListeners } = await loadGame({
            coarsePointer,
            startAtTitle: true,
        });
        assert.equal(run('session.gameStarted'), false);
        documentListeners.DOMContentLoaded();
        elements.get('startGameBtn').dispatchEvent({ type: 'click' });
        assert.equal(run('session.gameStarted'), true);
        assert.equal(elements.get('startScreen').classList.contains('hidden'), true);
        assert.ok(run('enemies.length') > 0);
        assert.doesNotThrow(() => run('gameLoop(16);'));
        const enemyCount = run('enemies.length');
        elements.get('startGameBtn').dispatchEvent({ type: 'click' });
        assert.equal(run('enemies.length'), enemyCount);
    }
});

test('popup buttons retain native keyboard activation without equipping or attacking', async () => {
    const { run, listeners } = await loadGame();
    run('inventory.push({...WEAPONS.find(w => w.id === "iron")}); toggleInventory();');
    const weapon = run('player.weapon.id');
    for (const code of ['Enter', 'Space']) {
        let prevented = false;
        listeners.keydown({
            code,
            target: { closest: () => ({}) },
            preventDefault() {
                prevented = true;
            },
        });
        assert.equal(prevented, false, code);
        assert.equal(run('player.weapon.id'), weapon);
        assert.equal(run(`isKeyDown('${code}')`), false);
    }
    listeners.keydown({ code: 'Enter', preventDefault() {} });
    assert.equal(run('player.weapon.id'), 'iron');
});

test('popup bounds follow the visible viewport without replacing the fixed game height', async () => {
    const { run, listeners } = await loadGame({ coarsePointer: true, innerHeight: 844 });
    run('initializePopupLayout(); window.innerHeight = 620;');
    listeners.resize();
    const style = (name) => run(`document.documentElement.style.getPropertyValue('${name}')`);
    assert.equal(style('--popup-height'), '620px');
    assert.equal(style('--app-height'), '844px');
    run(
        `window.visualViewport = { width: 390, height: 500, offsetTop: 24, offsetLeft: 0 }; syncPopupViewport();`,
    );
    assert.equal(style('--popup-height'), '500px');
    assert.equal(style('--popup-top'), '24px');
    assert.equal(style('--popup-width'), '390px');
    run('window.visualViewport.height = 0; syncPopupViewport();');
    assert.equal(style('--popup-height'), '620px');
});

test('visible viewport movement and fullscreen changes refresh popup bounds', async () => {
    const { run, documentListeners } = await loadGame({ coarsePointer: true, innerHeight: 720 });
    run(`const popupEvents = {};
        window.visualViewport = {
            width: 390, height: 600, offsetTop: 0, offsetLeft: 0,
            addEventListener: (name, callback) => { popupEvents[name] = callback; }
        };
        initializePopupLayout(); initializePopupLayout();
        window.visualViewport.height = 500; popupEvents.resize();`);
    const style = (name) => run(`document.documentElement.style.getPropertyValue('${name}')`);
    assert.equal(style('--popup-height'), '500px');
    run('window.visualViewport.offsetTop = 30; popupEvents.scroll();');
    assert.equal(style('--popup-top'), '30px');
    run('window.visualViewport.height = 840; window.visualViewport.offsetTop = 0;');
    documentListeners.fullscreenchange();
    assert.equal(style('--popup-height'), '840px');
    run('window.visualViewport.height = 600;');
    documentListeners.webkitfullscreenchange();
    assert.equal(style('--popup-height'), '600px');
    assert.equal(style('--app-height'), '720px');
});

test('touch movement and held attack work together without releasing keyboard input', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run('initializeTouchControls(); keys.KeyW=true;');
    const pointer = (type, pointerId, clientX = 64, clientY = 64) => ({
        type,
        pointerId,
        clientX,
        clientY,
        button: 0,
        preventDefault() {},
    });
    const stick = elements.get('touchJoystick');
    const attack = elements.get('touchAttack');
    stick.dispatchEvent(pointer('pointerdown', 1, 114, 64));
    attack.dispatchEvent(pointer('pointerdown', 2));
    assert.equal(run("isKeyDown('ArrowRight')"), true);
    assert.equal(run("isKeyDown('Space')"), true);
    stick.dispatchEvent(pointer('pointerup', 1));
    assert.equal(elements.get('touchThumb').style.transform, 'translate(-50%, -50%)');
    assert.equal(run("isKeyDown('ArrowRight')"), false);
    assert.equal(run("isKeyDown('Space')"), true);
    attack.dispatchEvent(pointer('pointercancel', 2));
    assert.equal(run("isKeyDown('Space')"), false);
    assert.equal(run("isKeyDown('KeyW')"), true);
});

test('touch controls release held input when a panel opens and close without another keyboard action', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(
        'initializeTouchControls(); touchKeys.Space=true; touchKeys.ArrowLeft=true; toggleInventory(); updateTouchControls();',
    );
    assert.equal(run("isKeyDown('Space') || isKeyDown('ArrowLeft')"), false);
    assert.equal(elements.get('touchControls').classList.contains('hidden'), true);
    elements.get('closeInventory').dispatchEvent({ type: 'click' });
    assert.equal(run('session.inventoryOpen'), false);
    run('updateTouchControls();');
    assert.equal(elements.get('touchControls').classList.contains('hidden'), false);
});

test('the touch quest journal pauses and closes even with no active quests', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run('initializeTouchControls();');
    elements.get('touchQuests').dispatchEvent({ type: 'click' });
    assert.equal(run('session.questJournalOpen && session.gamePaused'), true);
    elements.get('closeQuestJournal').dispatchEvent({ type: 'click' });
    assert.equal(run('session.questJournalOpen || session.gamePaused'), false);
    assert.equal(elements.get('questJournal').classList.contains('hidden'), true);
});

test('touch gestures release on focus loss, hidden documents and terminal states', async () => {
    const { run, elements, listeners, documentListeners } = await loadGame({ coarsePointer: true });
    run('initializeTouchControls();');
    const press = () =>
        elements
            .get('touchAttack')
            .dispatchEvent({ type: 'pointerdown', pointerId: 9, button: 0, preventDefault() {} });
    press();
    listeners.blur();
    assert.equal(run("isKeyDown('Space')"), false);
    press();
    run('document.hidden=true;');
    documentListeners.visibilitychange();
    assert.equal(run("isKeyDown('Space')"), false);
    run('document.hidden=false;');
    press();
    run('session.gameOver=true; updateTouchControls();');
    assert.equal(run("isKeyDown('Space')"), false);
    assert.equal(elements.get('touchControls').classList.contains('hidden'), true);
});

test('touch action buttons cannot spend items while paused or interrupt a slot machine', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`initializeTouchControls(); player.items=[{...ITEMS[0]}]; player.auxWeapons=[{...AUX_WEAPONS[0]}];
        player.auxWeapon=player.auxWeapons[0]; session.gamePaused=true;`);
    elements.get('touchItem1').dispatchEvent({ type: 'click' });
    elements.get('touchAux').dispatchEvent({ type: 'click' });
    assert.equal(run('player.items.length'), 1);
    assert.equal(run('player.auxWeapon.uses'), 3);
    run('session.slotMachineOpen=true;');
    elements.get('touchInventory').dispatchEvent({ type: 'click' });
    elements.get('touchQuests').dispatchEvent({ type: 'click' });
    assert.equal(run('session.inventoryOpen || session.questJournalOpen'), false);
    assert.equal(run('session.gamePaused'), true);
});

test('desert travel leaves a walkable arrival connected to dry land and clears forest dummies', async () => {
    const { run } = await loadGame();
    run('scarecrows.push({x: 1}); travelToDesert();');
    assert.equal(run('scarecrows.length'), 0);
    assert.equal(run('collidesWithMap(player.x, player.y, player.w, player.h)'), false);
    assert.equal(run('isSolidTile(45, 30)'), false);
    assert.ok(run('tileMap.flat().filter(t => !TILE_TYPES[TILE_KEYS[t]].solid).length') > 100);
});

test('combat actions cannot spend items or auxiliary uses while paused or in inventory', async () => {
    for (const state of [
        'gamePaused = true',
        'inventoryOpen = true',
        'gameStarted = false',
        'gameOver = true',
        'gameVictory = true',
    ]) {
        const { run } = await loadGame();
        run(`player.hp = 20; player.items.push({...ITEMS[0]});
            player.auxWeapon = {...AUX_WEAPONS.find(a => a.id === 'healpot')};
            player.auxWeapons.push(player.auxWeapon); ${state}; useConsumable(0); useAuxWeapon();`);
        assert.equal(run('player.hp'), 20, state);
        assert.equal(run('player.items.length'), 1, state);
        assert.equal(run('player.auxWeapon.uses'), 4, state);
    }
});

test('Escape closes inventory without opening another panel and repeated toggles are ignored', async () => {
    const { run, listeners } = await loadGame();
    const event = { code: 'KeyI', key: 'i', preventDefault() {} };
    listeners.keydown(event);
    listeners.keydown({ ...event, repeat: true });
    assert.equal(run('inventoryOpen'), true);
    listeners.keydown({ code: 'Escape', key: 'Escape', preventDefault() {} });
    assert.equal(run('inventoryOpen'), false);
});

test('slot machine stays paused when Escape, E, I or C is pressed', async () => {
    const { run, listeners } = await loadGame();
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

test('opening compendium over a dialog does not release the dialog pause', async () => {
    const { run } = await loadGame();
    run('gamePaused = true; toggleCompendium();');
    assert.equal(run('compendiumOpen'), false);
    assert.equal(run('gamePaused'), true);
});

test('weapon final use still launches its attack before switching to fists', async () => {
    const { run } = await loadGame();
    run("player.weapon = {...WEAPONS.find(w => w.id === 'legend'), uses: 1}; attackWithWeapon();");
    assert.equal(run('projectiles.length'), 1);
    assert.equal(run('fireZones.length'), 1);
    assert.equal(run('player.weapon.id'), 'fist');
});

test('fountain cannot bank healing ticks at full HP', async () => {
    const { run } = await loadGame();
    run(
        'player.x = FOUNTAIN_CENTER_X; player.y = FOUNTAIN_CENTER_Y; player.gold = 100; for (let i = 0; i < 50; i++) update(0.1); player.hp = 50; update(0.1);',
    );
    assert.equal(run('player.hp'), 50);
    run('for (let i = 0; i < 10; i++) update(0.1);');
    assert.equal(run('player.hp'), 53);
});

test('portal opens when gold reaches the threshold after the boss was killed', async () => {
    const { run } = await loadGame();
    run('player.bossKilled = true; player.gold = 1000; update(0.01);');
    assert.equal(run('portals.length'), 1);
    run('update(0.01);');
    assert.equal(run('portals.length'), 1);
});

test('stopped slot reels retain their result while other reels spin', async () => {
    const { run, timers, elements } = await loadGame();
    run('player.gold = 100; useSlotMachine();');
    const cycle = timers.find((t) => t.interval);
    timers.find((t) => t.delay === 800).cb();
    const symbol = elements.get('reel1').textContent;
    for (let i = 0; i < 12; i++) {
        cycle.cb();
        assert.equal(elements.get('reel1').textContent, symbol);
    }
});

test('focus loss releases held movement keys', async () => {
    const { run, listeners } = await loadGame();
    listeners.keydown({ code: 'KeyW', key: 'w', preventDefault() {} });
    assert.equal(run('keys.KeyW'), true);
    listeners.blur?.();
    assert.equal(run('Boolean(keys.KeyW || keys.w)'), false);
});

test('lethal damage near fountain ends the game before healing can resurrect the player', async () => {
    const { run } = await loadGame();
    run(
        "tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));",
    );
    run(
        'player.x = FOUNTAIN_CENTER_X; player.y = FOUNTAIN_CENTER_Y; player.hp = 1; player.gold = 100; player.fountainTimer = 1; spawnEnemyProjectile(player.x + player.w / 2, player.y + player.h / 2, 0, 0, 2, "red"); update(0.01);',
    );
    assert.equal(run('gameOver'), true);
    assert.equal(run('player.hp'), -1);
});

test('one attack damages a chest once, regardless of frame count', async () => {
    const { run } = await loadGame();
    run(
        'const origin = getPlayerAttackOrigin(); chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 10}); attackWithWeapon(); for (let i = 0; i < 8; i++) { updateChests(0.01); player.attackTimer -= 0.01; }',
    );
    assert.equal(run('chests[0].hp'), 9);
    run('player.attackTimer = 0; attackWithWeapon(); updateChests(0.01);');
    assert.equal(run('chests[0].hp'), 8);
});

test('ground weapons remain available when inventory is full', async () => {
    const { run } = await loadGame();
    run(
        'for (let i = 0; i < 12; i++) inventory.push({...WEAPONS[1]}); weaponPickups.push({x: player.x + player.w / 2, y: player.y + player.h / 2, weapon: WEAPONS[2], life: 10}); updateWeaponPickups(0.01);',
    );
    assert.equal(run('weaponPickups.length'), 1);
    run('inventory.pop(); updateWeaponPickups(0.01);');
    assert.equal(run('weaponPickups.length'), 0);
    assert.equal(run('inventory[11].id'), 'iron');
});

test('boat dismount lands on the nearby shore and leaves the boat on water', async () => {
    const { run } = await loadGame();
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

test('desert generation retains dry terrain across multiple seeds', async () => {
    const { run } = await loadGame();
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

test('both regions run movement, combat and rendering without runtime errors', async () => {
    const { run } = await loadGame();
    run(
        'gameStarted = false; startGame(); keys.KeyD = true; keys.Space = true; for (let i = 0; i < 120; i++) { update(1 / 60); draw(); }',
    );
    assert.equal(run('Number.isFinite(player.x) && Number.isFinite(player.hp)'), true);
    run('travelToDesert(); for (let i = 0; i < 120; i++) { update(1 / 60); draw(); }');
    assert.equal(run('Number.isFinite(player.x) && Number.isFinite(player.hp)'), true);
});

test('spawn search never returns an invalid last random candidate', async () => {
    const { run } = await loadGame();
    assert.equal(run('findSpawnTile(3, () => false, 1)'), null);
    const position = run('findSpawnTile(3, (x, y) => x === 7 && y === 8, 0)');
    assert.equal(Math.floor(position.x), 7);
    assert.equal(Math.floor(position.y), 8);
});

test('hurt enemies cannot attack before their recovery timer expires', async () => {
    const { run } = await loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 15, player.y); enemies[0].x = player.x + 15; enemies[0].y = player.y; damageEnemy(enemies[0], 1, false); updateEnemies(0.01);',
    );
    assert.equal(run('player.hp'), 100);
    assert.equal(run('enemies[0].state'), 'hurt');
});

test('wander timers advance once per frame and boss projectiles use their configured damage', async () => {
    const { run } = await loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 500, player.y); enemies[0].stateTimer = 1; updateEnemies(0.1);',
    );
    assert.equal(run('enemies[0].stateTimer'), 0.9);
    run(
        'enemies.length = 0; spawnBoss(BOSS_TYPES[0], player.x + player.w + 60, player.y - 86); enemies[0].rangeAttackCd = 0; updateEnemies(0.01);',
    );
    assert.equal(run('enemyProjectiles[0].dmg'), run('BOSS_TYPES[0].rangeDmg'));
});

test('damaging an already dead enemy cannot award a second kill', async () => {
    const { run } = await loadGame();
    run(
        'spawnEnemy(ENEMY_TYPES[0], player.x + 300, player.y); const enemy = enemies[0]; damageEnemy(enemy, 999); damageEnemy(enemy, 999);',
    );
    assert.equal(run('player.kills'), 1);
});

test('snake attacks apply their configured poison damage', async () => {
    const { run } = await loadGame();
    run(
        'spawnEnemy(DESERT_ENEMY_TYPES.find(e => e.poison), player.x + 15, player.y); enemies[0].x = player.x + 15; enemies[0].y = player.y; updateEnemies(0.01);',
    );
    assert.ok(run('player.poisonTimer') > 0);
    assert.equal(run('player.poisonDamage'), 3);
});

test('quests recognize a boss killed before quest acceptance and reject duplicate acceptance', async () => {
    const { run } = await loadGame();
    run(
        "player.stage = 3; spawnBoss(BOSS_TYPES[0], player.x + 500, player.y); damageEnemy(enemies[0], 99999); acceptQuest(getQuest('slay_boss')); acceptQuest(getQuest('slay_boss')); updateQuestProgress();",
    );
    assert.equal(run("player.completedQuests.includes('slay_boss')"), true);
    assert.equal(run('player.activeQuests.length'), 0);
});

test('completing forest quests allows the desert adventure to continue', async () => {
    const { run } = await loadGame();
    run('player.completedQuests.push(...MAIN_QUESTS); updateQuestProgress();');
    assert.equal(run('gameVictory'), false);
    run(
        'player.currentRegion = "desert"; player.completedQuests.push(...DESERT_QUESTS); updateQuestProgress();',
    );
    assert.equal(run('gameVictory'), true);
});

test('boomerang returns on game time and does not cross region changes', async () => {
    const { run, timers } = await loadGame();
    run(
        "tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));",
    );
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

test('random teleport checks the complete player footprint and dismounts on fallback', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        tileMap[3][3] = TILE_KEYS.indexOf('SAND');
        for (let y = MAP_HEIGHT/2-1; y <= MAP_HEIGHT/2+1; y++) for (let x = MAP_WIDTH/2-1; x <= MAP_WIDTH/2+1; x++) tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        Math.random = () => 0; player.mount = {...MOUNT_TYPES[0]}; randomTeleport();`);
    assert.equal(run('collidesWithMap(player.x, player.y, player.w, player.h)'), false);
    assert.equal(run('player.mount'), null);
});

test('enemy spawns validate their entire body and never overlap existing entities', async () => {
    const { run } = await loadGame();
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

test('shop purchases share capacity checks and copy definitions rather than mutating them', async () => {
    const { run } = await loadGame();
    run(
        "player.gold = 1000; openShop('village'); buyShopItem(WEAPONS[1], 50, 'weapon'); buyShopItem(ITEMS[0], 30, 'consumable');",
    );
    assert.equal(run('player.gold'), 920);
    assert.equal(run('inventory.length'), 1);
    assert.equal(run('player.items.length'), 1);
    assert.equal(run('inventory[0] === WEAPONS[1] || player.items[0] === ITEMS[0]'), false);
    run(
        "for (let i = 1; i < CONSUMABLE_CAPACITY; i++) player.items.push({...ITEMS[0]}); buyShopItem(ITEMS[0], 30, 'consumable');",
    );
    assert.equal(run('player.gold'), 920);
});

test('consumed auxiliary weapons stay discovered and the journal shows desert quest progress', async () => {
    const { run, elements } = await loadGame();
    run(
        "player.collection.auxiliaryWeapons.push('firebomb'); renderCompendium(); player.currentRegion = 'desert'; player.completedQuests.push('collect_1000gold'); renderQuestJournal();",
    );
    assert.ok(
        elements.get('compendiumGrid').children.some((card) => card.title?.includes('화염병')),
    );
    assert.equal(elements.get('questSummary').textContent, '황금 사막 · 주요 퀘스트 1 / 2 완료');
});

test('content IDs, drop pools, spawn indices and quest rewards refer to existing definitions', async () => {
    const { run } = await loadGame();
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

test('one-way travel releases unfinished forest quests while preserving global quests and rewards', async () => {
    const { run } = await loadGame();
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

test('repeated desert travel cannot regenerate the world or discard desert progress', async () => {
    const { run } = await loadGame();
    run('travelToDesert(); player.x += 10;');
    const firstEnemy = run('enemies[0]');
    const arrivalX = run('player.x');
    run('travelToDesert();');
    assert.equal(run('enemies[0]'), firstEnemy);
    assert.equal(run('player.x'), arrivalX);
});

test('large melee enemies attack when their body reaches the player', async () => {
    for (const definition of [
        "ENEMY_TYPES.find(e => e.name === '트롤')",
        "ENEMY_TYPES.find(e => e.name === '황토 젤리')",
        "DESERT_ENEMY_TYPES.find(e => e.name === '오우거')",
        'BOSS_TYPES[3]',
    ]) {
        const { run } = await loadGame();
        run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
            const enemy = spawnEnemy({...${definition}, isBoss: ${definition.startsWith('BOSS')}, megaBoss: ${definition.startsWith('BOSS')}}, player.x + player.w + 1, player.y);
            enemy.y = player.y + (player.h - enemy.h) / 2;
            updateEnemies(0.01);`);
        assert.ok(run('player.hp') < 100, definition);
        assert.equal(run('enemies[0].state'), 'attack', definition);
    }
});

test('boarding from shore places the player on the boat and permits sailing', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        for (let y = 0; y < MAP_HEIGHT; y++) for (let x = 21; x < MAP_WIDTH; x++) tileMap[y][x] = TILE_KEYS.indexOf('SAND');
        player.x = 21 * TILE_SIZE; player.y = 20 * TILE_SIZE;
        spawnMount(MOUNT_TYPES.find(m => m.waterOnly), 19.5 * TILE_SIZE, player.y);
        updatePlayer(0.01);`);
    assert.equal(run('player.mount'), null);
    run('performInputAction("KeyE");');
    assert.equal(run('player.mount.id'), 'boat');
    assert.equal(run('player.x'), 19.5 * 32);
    run('keys.KeyA = true; updatePlayer(0.05);');
    assert.ok(run('player.x') < 19.5 * 32);
    run('keys.KeyA = false; keys.KeyD = true; updatePlayer(0.1);');
    assert.ok(run('player.x + player.mount.w') <= 21 * 32);
});

test('land mounts spawn with their entire body clear of terrain and entities', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        tileMap[10][11] = TILE_KEYS.indexOf('ROCK');
        spawnMount(MOUNT_TYPES[0], 10 * TILE_SIZE, 10 * TILE_SIZE);`);
    assert.equal(run('mounts.length'), 1);
    assert.equal(run('collidesWithMap(mounts[0].x, mounts[0].y, mounts[0].w, mounts[0].h)'), false);
});

test('a lethal trap chest cannot be followed by healing loot in the same frame', async () => {
    const { run } = await loadGame();
    run(`const origin = getPlayerAttackOrigin(); player.hp = 10; Math.random = () => 0.99;
        chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1, type: 'normal', chestData: CHEST_TYPES[0]});
        chests.push({x: origin.x - 10, y: origin.y - 10, w: 20, h: 20, hp: 1, type: 'trap', chestData: CHEST_TYPES[0]});
        attackWithWeapon(); update(0.01);`);
    assert.equal(run('gameOver'), true);
    assert.ok(run('player.hp') <= 0);
    assert.equal(run('chests.length'), 1);
});

test('fast projectiles hit small enemies crossed between frames', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 300, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), run('enemies[0].maxHp - 3'));
    assert.equal(run('projectiles.length'), 0);
});

test('projectiles stop at a crossed wall before damaging an enemy behind it', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        tileMap[9][10] = TILE_KEYS.indexOf('WALL'); spawnEnemy(ENEMY_TYPES[0], 358, 300);
        spawnProjectile(305, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);
        player.x = 358; player.y = 300;
        spawnEnemyProjectile(305, 310, 500, 0, 3, 'red'); updateEnemyProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), run('enemies[0].maxHp'));
    assert.equal(run('player.hp'), 100);
    assert.equal(run('projectiles.length + enemyProjectiles.length'), 0);
});

test('projectiles hit the first enemy along the path regardless of array order', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 328, 300); spawnEnemy(ENEMY_TYPES[0], 300, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), run('enemies[0].maxHp'));
    assert.equal(run('enemies[1].hp'), run('enemies[1].maxHp - 3'));
});

test('expiring projectiles cannot damage targets beyond their remaining flight time', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length: MAP_HEIGHT}, () => Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        spawnEnemy(ENEMY_TYPES[0], 325, 300);
        spawnProjectile(285, 310, 3, 500, 3, 'red', ''); projectiles[0].life = 0.01;
        updateProjectiles(0.1);`);
    assert.equal(run('enemies[0].hp'), run('enemies[0].maxHp'));
    assert.equal(run('projectiles.length'), 0);
});

test('guaranteed boss weapon drops remain collectible when inventory is full', async () => {
    const { run } = await loadGame();
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

test('resizing a paused game redraws the scene without advancing simulation time', async () => {
    const { run, listeners, elements } = await loadGame();
    run('gamePaused = true; drawCount = 0;');
    const gameTime = run('player.gameTime');
    elements.get('gameArea').clientWidth = 640;
    elements.get('gameArea').clientHeight = 480;
    listeners.resize();
    assert.equal(run('drawCount'), 1);
    assert.equal(run('player.gameTime'), gameTime);
    assert.equal(run('camera.x'), run('player.x + player.w / 2 - 320'));
});

test('travel awards already achieved quest rewards before abandoning remaining forest quests', async () => {
    const { run } = await loadGame();
    run(`player.stage = 5; player.killsByName['늑대'] = 5;
        player.activeQuests.push({id:'hunt_wolves', progress:0}); travelToDesert();`);
    assert.equal(run('player.completedQuests.includes("hunt_wolves")'), true);
    assert.equal(run('player.auxWeapons[0].id'), 'boomerang');
    assert.equal(run('player.gold'), 40);
});

test('chests and all village NPCs fit on walkable terrain across map seeds', async () => {
    const { run } = await loadGame();
    for (const seed of [0, 1, 42, 123, 999, 50000, 99999]) {
        run(
            `clearWorldEntities(); generateForestMap(${seed}); spawnEnemies(); spawnInitialPickups();`,
        );
        assert.equal(run('npcs.length'), 8, `NPC count for seed ${seed}`);
        assert.equal(
            run(`npcs.filter(n => n.isShop && n.shopType === 'village' || n.name === '현자')
            .every(n => n.x >= FOUNTAIN_CENTER_X - 150 && n.x + n.w <= FOUNTAIN_CENTER_X + 150
                && n.y >= FOUNTAIN_CENTER_Y - 50 && n.y + n.h < FOUNTAIN_CENTER_Y + 180)`),
            true,
            `opening village services remain in a narrow mobile view for seed ${seed}`,
        );

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

test('desert stage progression cannot introduce forest quest NPCs', async () => {
    const { run } = await loadGame();
    run(
        'travelToDesert(); player.kills = 4; const enemy = enemies.find(e => !e.isBoss); damageEnemy(enemy, 99999);',
    );
    assert.equal(run("npcs.some(n => n.name === '경비대장')"), false);
    assert.equal(run('player.stage'), 2);
});

test('compendium totals include every displayed boss definition', async () => {
    const { run, elements } = await loadGame();
    run(
        'player.collection.enemies = [...new Set([...ENEMY_TYPES, ...DESERT_ENEMY_TYPES, ...BOSS_TYPES].map(e => e.name))]; renderCompendium();',
    );
    const total = run('player.collection.enemies.length');
    assert.ok(elements.get('compendiumStats').textContent.endsWith(`적 ${total}/${total}`));
});

test('poison cannot tick after its remaining duration, but ticks at the expiry boundary', async () => {
    const { run } = await loadGame();
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

test('dead players cannot consume healing items or recover from an attack stage-up', async () => {
    const { run } = await loadGame();
    run(
        'player.hp = 0; player.kills = 4; player.items.push({...ITEMS[0]}); useConsumable(0); keys.Space = true; update(0.01);',
    );
    assert.equal(run('player.hp'), 0);
    assert.equal(run('player.items.length'), 1);
    assert.equal(run('gameOver'), true);
});

test('full-inventory slot jackpot reports gold conversion in the modal and log', async () => {
    const { run, timers, elements } = await loadGame();
    run(
        'player.gold = 100; for (let i = 0; i < INVENTORY_CAPACITY; i++) inventory.push({...WEAPONS[1]}); Math.random = () => 0.99; useSlotMachine();',
    );
    timers.find((t) => t.delay === 1600).cb();
    assert.equal(run('player.gold'), 150);
    assert.equal(run('inventory.length'), 12);
    assert.ok(elements.get('slotResult').textContent.includes('대신 100골드'));
    assert.ok(elements.get('eventBubbles').children.at(-1).textContent.includes('대신 100골드'));
});

test('simulation can advance independently and frame loop draws paused and terminal states', async () => {
    const { run } = await loadGame();
    run('drawCount = 0; update(0.01);');
    assert.equal(run('drawCount'), 0);
    run('gamePaused = true; gameLoop(10); gameOver = true; gameLoop(20);');
    assert.equal(run('drawCount'), 2);
});

test('padded UI artwork centres its painted joystick and thumb at the same point', async () => {
    const { run } = await loadGame();
    // The previous sheet's base and thumb occupy different positions inside their cells.
    for (const bounds of [
        [944, 39, 280, 275],
        [42, 942, 260, 258],
    ]) {
        const result = run(`getUiSpriteStyle(${JSON.stringify(bounds)},1254,1254)`);
        const scale = parseFloat(result.size) / 100;
        const [x, y, w, h] = bounds;
        const paintedX = ((1 - scale) * parseFloat(result.x)) / 100 + ((x + w / 2) * scale) / 1254;
        const paintedY = ((1 - scale) * parseFloat(result.y)) / 100 + ((y + h / 2) * scale) / 1254;
        assert.ok(Math.abs(paintedX - 0.5) < 1e-8);
        assert.ok(Math.abs(paintedY - 0.5) < 1e-8);
    }
});

test('sealed woodland gaps become undergrowth while natural water and desert connectivity remain unchanged', async () => {
    for (const region of ['forest', 'desert']) {
        const { run } = await loadGame();
        run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
            for(let y=4;y<=6;y++)for(let x=4;x<=6;x++)if(x!==5||y!==5)tileMap[y][x]=TILE_KEYS.indexOf('TREE');
            tileMap[15][15]=TILE_KEYS.indexOf('WATER');
            ensureConnectivity('${region}');`);
        assert.equal(run('TILE_KEYS[tileMap[5][5]]'), region === 'forest' ? 'BUSH' : 'WATER_DEEP');
        assert.equal(run('isSolidTile(5,5)'), true);
        assert.equal(run('TILE_KEYS[tileMap[15][15]]'), 'WATER');
        assert.equal(run('isSolidTile(10,10)'), false);
    }
});

test('boats only spawn in a large connected navigable lake with a shore', async () => {
    const { run } = await loadGame();
    for (const shape of ['none', 'puddle', 'channel', 'separate', 'lake']) {
        run(`clearWorldEntities(); tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
            player.x=1200;player.y=900;
            function water(x,y,w,h) {for(let dy=0;dy<h;dy++)for(let dx=0;dx<w;dx++)tileMap[y+dy][x+dx]=TILE_KEYS.indexOf('WATER');}`);
        if (shape === 'puddle') run('water(12,12,4,4);');
        if (shape === 'channel') run('water(12,12,2,40);');
        if (shape === 'separate')
            run('water(12,12,4,4);water(20,12,4,4);water(28,12,4,4);water(36,12,4,4);');
        if (shape === 'lake') run('water(12,12,8,6);');
        run('spawnInitialPickups();');
        assert.equal(
            run('mounts.filter(m=>m.id==="boat").length'),
            shape === 'lake' ? 1 : 0,
            shape,
        );
        if (shape === 'lake')
            assert.equal(
                run('mounts.filter(m=>m.id==="boat").every(m=>canOccupyMountPosition(m,m.x,m.y))'),
                true,
            );
    }
});

test('duplicate weapon loot reports only the awarded gold', async () => {
    const { run, elements } = await loadGame();
    run('receiveWeapon(WEAPONS[1]);receiveWeapon(WEAPONS[1]);');
    assert.equal(elements.get('eventBubbles').children.at(-1).textContent, '💰 +10 골드');
    assert.equal(run('player.gold'), 10);
});

test('control double taps are canceled without blocking auxiliary clicks', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(
        'initializeTouchControls();player.auxWeapon={...AUX_WEAPONS.find(w=>w.id==="shuriken")};player.auxWeapons=[player.auxWeapon];',
    );
    let prevented = false;
    elements.get('touchControls').dispatchEvent({
        type: 'dblclick',
        preventDefault() {
            prevented = true;
        },
    });
    assert.equal(prevented, true);
    elements.get('touchAux').dispatchEvent({ type: 'click' });
    assert.ok(run('player.auxCooldown') > 0);
});

test('painted village keeps the same walkable trail and blocked fountain across seeds', async () => {
    const { run } = await loadGame();
    let snapshot;
    for (const seed of [0, 42, 123, 99999]) {
        run(`generateForestMap(${seed});`);
        const current = run(
            'JSON.stringify(tileMap.slice(VILLAGE.y/32,(VILLAGE.y+VILLAGE.height)/32).map(row=>row.slice(VILLAGE.x/32,(VILLAGE.x+VILLAGE.width)/32)))',
        );
        if (snapshot) assert.equal(current, snapshot);
        else snapshot = current;
        assert.equal(run('isSolidTile(MAP_WIDTH/2,MAP_HEIGHT/2)'), true);
        assert.equal(run('collidesWithMap(FOUNTAIN_CENTER_X,FOUNTAIN_CENTER_Y+175,24,28)'), false);
    }
});

test('trail encounters use game time, stop at the cap and stay out of the village sanctuary', async () => {
    const { run } = await loadGame();
    run(
        'clearWorldEntities();session.trailEncountersEnabled=true;player.x=FOUNTAIN_CENTER_X;player.y=FOUNTAIN_CENTER_Y+175;updateTrailEncounters(0);',
    );
    assert.equal(run('enemies.length'), 3);
    run('session.gamePaused=true;updateTrailEncounters(20);');
    assert.equal(run('enemies.length'), 3);
    run('session.gamePaused=false;updateTrailEncounters(9);');
    assert.equal(run('enemies.length'), 3);
    run('updateTrailEncounters(1);');
    assert.equal(run('enemies.length'), 5);
    run('for(let i=0;i<10;i++)updateTrailEncounters(10);');
    assert.equal(run('enemies.length'), 9);
    assert.equal(run('enemies.some(e=>collidesWithMap(e.x,e.y,e.w,e.h))'), false);
    run(
        'clearWorldEntities();session.trailEncounterTimer=0;player.y=FOUNTAIN_CENTER_Y+50;updateTrailEncounters(10);',
    );
    assert.equal(run('enemies.length'), 0);
});

test('boss terrain destruction preserves the painted village collision', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();player.x=FOUNTAIN_CENTER_X;player.y=FOUNTAIN_CENTER_Y+175;player.invincible=100;
        const villageBefore=JSON.stringify(tileMap.slice(VILLAGE.y/32,(VILLAGE.y+VILLAGE.height)/32).map(r=>r.slice(VILLAGE.x/32,(VILLAGE.x+VILLAGE.width)/32)));
        spawnBoss(BOSS_TYPES.find(b=>b.id==='ancient_dragon'),FOUNTAIN_CENTER_X,FOUNTAIN_CENTER_Y);updateEnemies(.1);`);
    assert.equal(
        run(
            'JSON.stringify(tileMap.slice(VILLAGE.y/32,(VILLAGE.y+VILLAGE.height)/32).map(r=>r.slice(VILLAGE.x/32,(VILLAGE.x+VILLAGE.width)/32)))===villageBefore',
        ),
        true,
    );
});

test('ground bosses never gain wall passage solely from megaBoss size classification', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
  player.x=850;player.y=500;player.invincible=999;
  const groundBoss=spawnBoss({...BOSS_TYPES[1],size:48,speed:500,ranged:false,spawnMinions:false,destroyTerrain:false},500,500);
        for(let y=0;y<MAP_HEIGHT;y++)tileMap[y][20]=TILE_KEYS.indexOf('WALL');session.terrainRevision++;`);
    for (let i = 0; i < 20; i++) {
        run('updateEnemies(.1);');
        assert.equal(
            run('collidesWithMap(groundBoss.x,groundBoss.y,groundBoss.w,groundBoss.h)'),
            false,
        );
    }
    assert.ok(run('groundBoss.x+groundBoss.w') <= 644);
});

test('fast ordinary monsters sweep their bodies instead of jumping through thin obstacles', async () => {
    const { run } = await loadGame();
    run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
  player.x=400;player.y=620;player.invincible=999;
  const fast=spawnEnemy({...ENEMY_TYPES[1],speed:2000,ranged:true,rangeCooldown:999},400,500,null,{randomizeSpeed:false});
  for(let y=0;y<MAP_HEIGHT;y++)tileMap[y][16]=TILE_KEYS.indexOf('WALL');session.terrainRevision++;Math.random=()=>0;
  updateEnemies(.1);`);
    assert.ok(run('fast.x+fast.w') <= 516);
    assert.equal(run('collidesWithMap(fast.x,fast.y,fast.w,fast.h)'), false);
});

test('only explicit flying or phasing abilities permit obstacle passage', async () => {
    const { run } = await loadGame();
    for (const ability of ['flying', 'phasing']) {
        run(`clearWorldEntities();tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('GRASS')));
   player.x=800;player.y=500;player.invincible=999;
   var special=spawnEnemy({...ENEMY_TYPES[1],${ability}:true,speed:200},500,500,null,{randomizeSpeed:false});special.trailGuard=true;
   for(let y=0;y<MAP_HEIGHT;y++)tileMap[y][20]=TILE_KEYS.indexOf('WALL');session.terrainRevision++;
   for(let i=0;i<20;i++)updateEnemies(.1);`);
        assert.ok(run('special.x') > 672, ability);
    }
});

test('large painted chunks repeat for a seed, vary by seed and keep their four body-wide ports open', async () => {
    const { run } = await loadGame();
    run(
        'generateForestMap(123);const firstChunkMap=JSON.stringify(tileMap);generateForestMap(123);',
    );
    assert.equal(run('JSON.stringify(tileMap)===firstChunkMap'), true);
    run('generateForestMap(456);');
    assert.equal(run('JSON.stringify(tileMap)===firstChunkMap'), false);
    for (const region of ['forest', 'desert'])
        for (let variant = 0; variant < 8; variant++) {
            for (const [u, v] of [
                [0.5, 0.025],
                [0.5, 0.975],
                [0.025, 0.5],
                [0.975, 0.5],
            ])
                assert.ok(
                    ['DIRT', 'SAND'].includes(run(`chunkTile(${variant},${u},${v},'${region}')`)),
                );
        }
    for (const region of ['forest', 'desert']) {
        run(
            `clearWorldEntities();player.currentRegion='${region}';${region === 'forest' ? 'generateForestMap' : 'generateDesertMap'}(12345);`,
        );
        for (const x of [640, 1920])
            for (const y of [384, 1024, 1664]) {
                run(
                    `var targetPosition=findNearbySpawnPosition(FOUNTAIN_CENTER_X+${x}-1280-12,FOUNTAIN_CENTER_Y+${y}-960-14,24,28);`,
                );
                assert.equal(
                    run(
                        '!!targetPosition && isReachableFromArrival(targetPosition.x,targetPosition.y,24,28)',
                    ),
                    true,
                    `${region} ${x},${y}`,
                );
            }
    }
});

test('outer forest and desert chunks sustain capped encounters on valid ground', async () => {
    const { run } = await loadGame();
    for (const region of ['forest', 'desert']) {
        run(`clearWorldEntities();player.currentRegion='${region}';${region === 'forest' ? 'generateForestMap' : 'generateDesertMap'}(12345);
    player.x=FOUNTAIN_CENTER_X+640;player.y=FOUNTAIN_CENTER_Y+64;session.trailEncountersEnabled=true;session.trailEncounterTimer=0;updateTrailEncounters(0);`);
        assert.ok(run('enemies.length') > 0, region);
        assert.equal(run('enemies.some(e=>collidesWithMap(e.x,e.y,e.w,e.h))'), false, region);
        run(
            'session.gamePaused=true;var encounterSnapshot=JSON.stringify(enemies);updateTrailEncounters(60);',
        );
        assert.equal(run('JSON.stringify(enemies)===encounterSnapshot'), true);
        run('session.gamePaused=false;');
    }
});

test('world dimensions expand threefold on both axes while the village remains centered and connected', async () => {
    const { run } = await loadGame();
    assert.equal(run('MAP_WIDTH*TILE_SIZE'), 7680);
    assert.equal(run('MAP_HEIGHT*TILE_SIZE'), 5760);
    assert.equal(run('VILLAGE.x+VILLAGE.width/2'), run('FOUNTAIN_CENTER_X'));
    assert.equal(run('VILLAGE.y+256'), run('FOUNTAIN_CENTER_Y'));
    for (const region of ['forest', 'desert']) {
        run(
            `clearWorldEntities();player.currentRegion='${region}';${region === 'forest' ? 'generateForestMap' : 'generateDesertMap'}(98765);`,
        );
        assert.equal(run('tileMap.length'), 180);
        assert.equal(run('tileMap.every(r=>r.length===240 && r.every(Number.isInteger))'), true);
        for (const [x, y] of [
            [640, 1024],
            [7040, 1024],
            [640, 4864],
            [7040, 4864],
        ]) {
            run(`var farPosition=findNearbySpawnPosition(${x}-12,${y}-14,24,28);`);
            assert.equal(
                run('!!farPosition && isReachableFromArrival(farPosition.x,farPosition.y,24,28)'),
                true,
                `${region} ${x} ${y}`,
            );
        }
    }
});

test('large scene variants offer distinct connected path layouts and repeatable mirrored appearances', async () => {
    const { run } = await loadGame();
    for (const region of ['forest', 'desert'])
        for (let variant = 0; variant < 8; variant++) {
            run(
                `var mask=chunkMask(${variant},'${region}');var paths=mask.flat().filter(t=>!TILE_TYPES[TILE_KEYS[t]].solid).length;`,
            );
            assert.ok(run('paths') > 60, `${region} ${variant}`);
        }
    run(
        'var sceneLooks=new Set();var kinds=new Set();for(let y=-3;y<6;y++)for(let x=-3;x<8;x++){const look=chunkAppearance(77,x,y);sceneLooks.add(JSON.stringify(look));kinds.add(look.variant);}',
    );
    assert.equal(run('kinds.size'), 8);
    assert.ok(run('sceneLooks.size') > 20);
    assert.equal(
        run('JSON.stringify(chunkAppearance(77,3,2))===JSON.stringify(chunkAppearance(77,3,2))'),
        true,
    );
});
