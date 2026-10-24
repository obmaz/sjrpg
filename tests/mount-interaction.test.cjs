const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('walking over land mounts never boards; the short ride button boards and dismount stays manual', async () => {
    for (const id of ['bicycle', 'horse', 'motor']) {
        const { run, elements } = await loadGame({ coarsePointer: true });
        run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
            npcs.length=0; portals.length=0; initializeTouchControls();
            player.x=400; player.y=400;
            spawnMount(MOUNT_TYPES.find(m=>m.id==='${id}'),400,400);
            for(let i=0;i<60;i++) updatePlayer(0.01);
            updateTouchControls();`);
        assert.equal(run('player.mount'), null, id);
        assert.equal(elements.get('worldInteract').textContent, '타기');
        assert.equal(elements.get('touchInteractLabel').textContent, '타기');
        elements.get('worldInteract').dispatchEvent({ type: 'click' });
        assert.equal(run('player.mount.id'), id);
        assert.equal(run('mounts.length'), 0);
        elements.get('touchDismount').dispatchEvent({ type: 'click' });
        run('updatePlayer(0.1);');
        assert.equal(run('player.mount'), null);
        assert.equal(run('mounts.length'), 1);
    }
});

test('directly tapping a mount selects it even when a nearby shop has default priority', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        npcs.length=0; portals.length=0; player.x=500; player.y=300; camera.x=0; camera.y=0;
        npcs.push({x:475,y:260,w:24,h:28,isShop:true,name:'상인'});
        spawnMount(MOUNT_TYPES[1],530,300); initializeTouchControls();
        canvas.getBoundingClientRect=()=>({left:0,top:0,width:canvas.width,height:canvas.height});
        updateTouchControls();`);
    assert.equal(elements.get('worldInteract').textContent, '상점');
    const canvas = elements.get('gameCanvas');
    const pointer = (type) => ({ type, pointerId: 7, clientX: 546, clientY: 316, button: 0 });
    canvas.dispatchEvent(pointer('pointerdown'));
    canvas.dispatchEvent(pointer('pointerup'));
    assert.equal(run('player.mount.id'), 'horse');
    assert.equal(run('session.shopOpen'), false);
});

test('boarding rejects distant, paused, dead and obstructed mounts without moving the player', async () => {
    const { run } = await loadGame();
    run(`tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('SAND')));
        player.x=400;player.y=400; const mount=spawnMount(MOUNT_TYPES[1],600,400);`);
    assert.equal(run('boardMount(mount)'), false);
    run('mount.x=400;');
    for (const state of ['session.gamePaused=true', 'session.inventoryOpen=true', 'player.hp=0']) {
        run(state);
        assert.equal(run('boardMount(mount)'), false, state);
        run('session.gamePaused=false; session.inventoryOpen=false; player.hp=100;');
    }
    run(
        "tileMap[Math.floor(mount.y/TILE_SIZE)][Math.floor(mount.x/TILE_SIZE)]=TILE_KEYS.indexOf('WALL');",
    );
    assert.equal(run('boardMount(mount)'), false);
    assert.equal(run('player.x'), 400);
    assert.equal(run('player.mount'), null);
    assert.equal(run('mounts.includes(mount)'), true);
});

test('mount direction follows movement, survives stopping and is kept when dismounted and boarded again', async () => {
    for (const id of ['horse', 'bicycle', 'motor', 'boat']) {
        const { run } = await loadGame();
        run(`clearWorldEntities(); tileMap=Array.from({length:MAP_HEIGHT},()=>Array(MAP_WIDTH).fill(TILE_KEYS.indexOf('${id === 'boat' ? 'WATER' : 'SAND'}')));
            player.x=400;player.y=400;
            const ride=spawnMount(MOUNT_TYPES.find(m=>m.id==='${id}'),400,400);
            boardMount(ride);`);
        for (const [key, direction] of [
            ['KeyS', 0],
            ['KeyA', 1],
            ['KeyW', 2],
            ['KeyD', 3],
        ]) {
            run(`keys.${key}=true;updatePlayer(0.01);delete keys.${key};updatePlayer(0.01);`);
            assert.equal(run('player.dir'), direction, id);
            assert.equal(run('player.mount.dir'), direction, id);
            assert.equal(run(`getMountArtFrame('${id}',player.dir)[1]%4`), direction, id);
        }
        run('dismountPlayer();');
        assert.equal(run('player.mount'), null, id);
        assert.equal(run('mounts[0].dir'), 3, id);
        run('player.x=mounts[0].x;player.y=mounts[0].y;player.dir=0;boardMount(mounts[0]);');
        assert.equal(run('player.dir'), 3, id);
    }
});
