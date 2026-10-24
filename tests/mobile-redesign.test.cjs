const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadGame } = require('./helpers/game-harness.cjs');

test('large shop NPCs open from all four edges with a touch button and no keyboard', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`initializeTouchControls(); npcs.length=0; portals.length=0;
        npcs.push({x:500,y:300,w:64,h:64,name:'상인',isShop:true,shopType:'village'});`);
    for (const [x, y] of [
        [444, 320],
        [596, 320],
        [520, 240],
        [520, 396],
    ]) {
        run(`player.x=${x}; player.y=${y}; updateTouchControls();`);
        assert.equal(elements.get('worldInteract').classList.contains('hidden'), false);
        assert.equal(elements.get('worldInteract').textContent, '상점');
        elements.get('worldInteract').dispatchEvent({ type: 'click' });
        assert.equal(run('session.shopOpen && session.gamePaused'), true);
        assert.equal(run('isKeyDown("KeyE")'), false);
        elements.get('closeShop').dispatchEvent({ type: 'click' });
    }
});

test('tapping a nearby merchant opens the shop, while a drag or paused tap does not', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run(`initializeTouchControls(); npcs.length=0; portals.length=0; camera.x=0; camera.y=0;
        player.x=450; player.y=320;
        npcs.push({x:500,y:300,w:64,h:64,name:'암시장 상인',isShop:true,shopType:'blackmarket'});
        canvas.getBoundingClientRect=()=>({left:0,top:0,width:canvas.width,height:canvas.height});`);
    const canvas = elements.get('gameCanvas');
    const pointer = (type, x) => ({ type, pointerId: 1, clientX: x, clientY: 332 });
    canvas.dispatchEvent(pointer('pointerdown', 532));
    canvas.dispatchEvent(pointer('pointerup', 532));
    assert.equal(run('session.currentShopType'), 'blackmarket');
    assert.equal(run('session.shopOpen'), true);
    elements.get('closeShop').dispatchEvent({ type: 'click' });
    canvas.dispatchEvent(pointer('pointerdown', 490));
    canvas.dispatchEvent(pointer('pointerup', 532));
    assert.equal(run('session.shopOpen'), false);
    canvas.dispatchEvent(pointer('pointerdown', 532));
    canvas.dispatchEvent({ type: 'pointercancel', pointerId: 1 });
    canvas.dispatchEvent(pointer('pointerup', 532));
    assert.equal(run('session.shopOpen'), false);
    run('session.gamePaused=true;');
    canvas.dispatchEvent(pointer('pointerdown', 532));
    canvas.dispatchEvent(pointer('pointerup', 532));
    assert.equal(run('session.shopOpen'), false);
});

test('duplicate permanent drops become gold even with a full bag; limited and discarded gear stay usable', async () => {
    const { run } = await loadGame();
    run(`const dagger=WEAPONS.find(w=>w.id==='dagger'); const before=JSON.stringify(WEAPONS);
        receiveWeapon(dagger); receiveWeapon(dagger);`);
    assert.equal(run('inventory.length'), 1);
    assert.equal(run('player.gold'), 10);
    run(
        'while(inventory.length<INVENTORY_CAPACITY) inventory.push({...dagger}); receiveWeapon(dagger);',
    );
    assert.equal(run('inventory.length'), 12);
    assert.equal(run('player.gold'), 20);
    assert.equal(run("receiveWeapon(WEAPONS.find(w=>w.id==='legend'))"), 'full');
    run(`inventory.length=0; const legend=WEAPONS.find(w=>w.id==='legend');
        receiveWeapon({...legend,uses:1}); receiveWeapon({...legend,uses:9});`);
    assert.equal(run('inventory.length'), 2);
    assert.equal(run('inventory[0].uses'), 1);
    assert.equal(run('inventory[1].uses'), 9);
    run('receiveWeapon(dagger,{autoSalvage:false}); receiveWeapon(dagger,{autoSalvage:false});');
    assert.equal(run('inventory.length'), 4);
    assert.equal(run('JSON.stringify(WEAPONS) === before'), true);
});

test('shop purchase buttons work without key input and SRD references stay separate from game balance', async () => {
    const { run, elements } = await loadGame({ coarsePointer: true });
    run('player.gold=500; openShop("village");');
    const buy = elements
        .get('shopSlots')
        .children[0].children.find((c) => c.className === 'shop-buy');
    assert.match(buy.textContent, /구매/);
    buy.dispatchEvent({ type: 'click' });
    assert.equal(run('player.gold'), 450);
    assert.equal(run('inventory[0].id'), 'dagger');
    assert.equal(run("WEAPONS.find(w=>w.id==='dagger').damageDice"), '1d4');
    assert.equal(run("ENEMY_TYPES.find(e=>e.name==='고블린').reference.hp"), 7);
    assert.equal(run("ENEMY_TYPES.find(e=>e.name==='고블린').hp"), 14);
    assert.equal(
        run(
            '[...ENEMY_TYPES,...DESERT_ENEMY_TYPES,...BOSS_TYPES].every(e=>e.reference.hp>0 && e.reference.ac>0)',
        ),
        true,
    );
});
