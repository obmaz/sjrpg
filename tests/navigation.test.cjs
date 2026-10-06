const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('A* takes the shortest open detour and reports an unreachable destination', async () => {
    const { run } = await loadGame();
    run(`const blocked = new Set(['3,1','3,2','3,3']);
        const options = {width:7, height:5, isWalkable:(x,y)=>!blocked.has(x+','+y), canStep:()=>true,
            isGoal:(x,y)=>x===5&&y===2, heuristic:(x,y)=>Math.abs(x-5)+Math.abs(y-2)};
        const route = findGridPath({x:1,y:2}, options);`);
    assert.equal(run('route.length'), 8);
    assert.equal(run("route.some(p=>blocked.has(p.x+','+p.y))"), false);
    run("blocked.add('3,0'); blocked.add('3,4');");
    assert.equal(run('findGridPath({x:1,y:2}, options)'), null);
});

test('body-aware reachability rejects a giant at the far side of a narrow corridor', async () => {
    const { run } = await loadGame();
    run(`tileMap = Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('WATER')));
        for(let y=26;y<=34;y++) for(let x=36;x<=43;x++) tileMap[y][x]=TILE_KEYS.indexOf('SAND');
        for(let y=26;y<=34;y++) for(let x=50;x<=60;x++) tileMap[y][x]=TILE_KEYS.indexOf('SAND');
        for(let x=44;x<=49;x++) tileMap[30][x]=TILE_KEYS.indexOf('SAND');`);
    assert.equal(run('isReachableFromArrival(56*TILE_SIZE,30*TILE_SIZE,24,24)'), true);
    assert.equal(run('isReachableFromArrival(56*TILE_SIZE,30*TILE_SIZE,80,80)'), false);
    assert.equal(
        run("spawnEnemy(ENEMY_TYPES.find(e=>e.name==='거대 슬라임'),56*TILE_SIZE,30*TILE_SIZE)"),
        null,
    );
    run("tileMap[30][47]=TILE_KEYS.indexOf('WALL'); session.terrainRevision++;");
    assert.equal(run('isReachableFromArrival(56*TILE_SIZE,30*TILE_SIZE,24,24)'), false);
});

test('ground AI walks around a wall instead of repeatedly running into it', async () => {
    const { run } = await loadGame();
    run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        player.x=24*TILE_SIZE; player.y=20*TILE_SIZE;
        for(let y=18;y<=22;y++) tileMap[y][22]=TILE_KEYS.indexOf('WALL');
        const enemy=spawnEnemy(ENEMY_TYPES[0],20*TILE_SIZE,20*TILE_SIZE); enemy.speed=100;
        let crossedWall=false, hitTerrain=false;
        for(let i=0;i<300;i++){updateEnemies(0.05); crossedWall ||= enemy.x>23*TILE_SIZE; hitTerrain ||= collidesWithMap(enemy.x,enemy.y,enemy.w,enemy.h);}`);
    assert.equal(run('crossedWall'), true);
    assert.equal(run('hitTerrain'), false);
    assert.ok(run('distanceBetweenRectangles(enemy,player)') <= 16);
});

test('every auxiliary definition has a reward or shop path and purchases retain independent uses', async () => {
    const { run } = await loadGame();
    assert.equal(
        run(
            `AUX_WEAPONS.every(aux=>QUESTS.some(q=>q.rewardAux===aux.id)||Object.values(SHOP_ITEMS).some(entries=>entries.some(entry=>entry.auxId===aux.id)))`,
        ),
        true,
    );
    run(`player.gold=5000; const missing=['healpot','icebomb','taunt','thunder','poison'];
        for(const id of missing){const shop=Object.keys(SHOP_ITEMS).find(key=>SHOP_ITEMS[key].some(entry=>entry.auxId===id));openShop(shop);
        const entry=SHOP_ITEMS[shop].find(entry=>entry.auxId===id);buyShopItem(AUX_WEAPONS.find(aux=>aux.id===id),entry.price,'auxiliary');}
        closeShop(); player.hp=30; useAuxWeapon();`);
    assert.equal(run('player.auxWeapons.length'), 5);
    assert.equal(run('player.auxWeapon.id'), 'healpot');
    assert.equal(run('player.hp'), 70);
    assert.equal(run('player.auxWeapon.uses'), 3);
    assert.equal(run("AUX_WEAPONS.find(aux=>aux.id==='healpot').uses"), 4);
    assert.equal(run('player.collection.auxiliaryWeapons.length'), 5);
    assert.equal(run('player.items.length + inventory.length'), 0);
    assert.equal(run('player.gold'), 4230);
});

test('slow ground enemies continue forward across timed replans', async () => {
    const { run } = await loadGame();
    run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        player.x=24*TILE_SIZE; player.y=20*TILE_SIZE;
        for(let y=18;y<=22;y++) tileMap[y][22]=TILE_KEYS.indexOf('WALL');
        const enemy=spawnEnemy(ENEMY_TYPES[0],20*TILE_SIZE,20*TILE_SIZE); enemy.speed=12;
        for(let i=0;i<300;i++) updateEnemies(0.1);`);
    assert.ok(run('distanceBetweenRectangles(enemy,player)') <= 16);
});

test('module evaluation keeps game state and functions out of the browser global scope', async () => {
    const { productionGlobalLeaks } = await loadGame();
    assert.deepEqual(productionGlobalLeaks, []);
});
